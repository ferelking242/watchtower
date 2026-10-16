import 'dart:async';

import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/log/logger.dart';

import 'dart/service.dart';
import 'javascript/service.dart';

ExtensionService getExtensionService(Source source) {
  return switch (source.sourceCodeLanguage) {
    SourceCodeLanguage.dart => DartExtensionService(source),
    SourceCodeLanguage.javascript => JsExtensionService(source),
    SourceCodeLanguage.unsupported => throw UnsupportedError(
      'This source format is no longer supported',
    ),
  };
}

/// Caches one [ExtensionService] per source, preventing repeated create/
/// destroy cycles that cause QuickJS gc_obj_list assertion crashes when
/// multiple sources initialise concurrently (e.g. home page with many tiles).
class ExtensionServiceRegistry {
  static final _cache = <String, ExtensionService>{};
  static final _signatures = <String, String>{};
  static final _queues = <String, _ExtensionSourceQueue>{};

  static String _key(Source source) =>
      (source.id ?? source.name ?? source.hashCode.toString()).toString();

  static String _signature(Source source) => [
    source.version ?? '',
    source.sourceCodeLanguage.name,
    source.sourceCode?.hashCode ?? 0,
  ].join('|');

  /// Returns the cached service for [source], creating one if needed.
  static ExtensionService get(Source source) {
    final key = _key(source);
    final signature = _signature(source);
    if (_signatures[key] != null && _signatures[key] != signature) {
      final previous = _cache.remove(key);
      if (previous != null) _dispose(previous);
    }
    _signatures[key] = signature;
    return _cache.putIfAbsent(key, () => getExtensionService(source));
  }

  /// Injects a pre-built [service] for [source], bypassing the JS/Dart runtime
  /// factory. Test-only: lets a unit test drive the queue without booting
  /// QuickJS, so the scheduling/dispatch contract can be asserted directly.
  static void debugRegisterService(Source source, ExtensionService service) {
    final key = _key(source);
    _cache[key] = service;
    _signatures[key] = _signature(source);
  }

  /// Runs calls for one source in order. Extension runtimes are not reentrant:
  /// two async JS/Dart calls can otherwise interleave on the same interpreter.
  ///
  /// Calls are served by [priorityFor], so the call that actually starts the
  /// video (`getVideoList`) overtakes the detail metadata fetch and the
  /// decorative tabs (`getRecommendations`/`getComments`).
  static Future<T> run<T>(
    Source source,
    Future<T> Function(ExtensionService service) action, {
    String? serviceType,
  }) {
    final key = _key(source);
    final queue = _queues.putIfAbsent(key, _ExtensionSourceQueue.new);
    final completer = Completer<T>();
    final priority = priorityFor(serviceType);
    // The closure is bound to *this* call's action, completer and source, so
    // whichever invocation drains it runs the right extension method. Sharing
    // a `pump()` that closed over the caller's `action` made a later call
    // execute the previous call's method (e.g. `getVideoList` returning the
    // pending `getDetail` MManga → "type 'MManga' is not a subtype of
    // 'List<Video>'" and an infinite loading state).
    final call = _ExtensionCall(
      completer,
      priority,
      () async {
        try {
          final result = await action(get(source));
          if (!completer.isCompleted) completer.complete(result);
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
    );
    queue.enqueue(call);

    if (queue.running != null || queue.pending > 1) {
      AppLogger.log(
        '… extension call queued  service=$serviceType  priority=$priority '
        'pending=${queue.pending}  [$key]  (another call holds the runtime)',
        logLevel: LogLevel.debug,
        tag: LogTag.extension_,
      );
    }

    void pump() {
      if (queue.running != null) return;
      final next = queue.dequeue();
      if (next == null) {
        _removeQueueIfIdle(key, queue);
        return;
      }
      if (!identical(_queues[key], queue) || queue.disposing) {
        if (!next.completer.isCompleted) {
          next.completer.completeError(
            StateError('Extension source was disposed before the request ran'),
          );
        }
        pump();
        return;
      }

      final waitMs = DateTime.now().difference(next.queuedAt).inMilliseconds;
      if (waitMs >= 250) {
        AppLogger.log(
          '… extension call waited ${waitMs}ms in queue  priority=${next.priority} '
          '← a slower call held the runtime  [$key]',
          logLevel: LogLevel.debug,
          tag: LogTag.extension_,
        );
      }

      final running = Future<void>.sync(next.execute);
      queue.running = running;
      running.whenComplete(() {
        if (identical(queue.running, running)) queue.running = null;
        pump();
      });
    }

    pump();
    return completer.future;
  }

  /// Scheduling priority for [serviceType]. Lower runs first.
  ///
  /// * `0` — playback: the call that resolves the video URL must never wait
  ///   behind metadata scrolling. Nothing else may be added here.
  /// * `2` — decorative tabs (related videos, comments, search suggestions)
  ///   that render after the player is already visible.
  /// * `1` — everything else (detail, listings, search): user-visible but not
  ///   on the tap→play path.
  static int priorityFor(String? serviceType) {
    switch (serviceType) {
      case 'getVideoList':
      case 'getHeaders':
      case 'getPageList':
        return 0;
      case 'getRecommendations':
      case 'getComments':
      case 'getSuggestions':
        return 2;
      default:
        return 1;
    }
  }

  static void _removeQueueIfIdle(String key, _ExtensionSourceQueue queue) {
    if (identical(_queues[key], queue) &&
        queue.running == null &&
        queue.pending == 0) {
      _queues.remove(key);
    }
  }

  /// Disposes and removes the service for a single source (e.g. on uninstall).
  /// The active call is allowed to finish; queued calls are invalidated and
  /// cannot recreate the runtime after it has been removed.
  static void disposeSource(String sourceId) {
    final queue = _queues.remove(sourceId);
    if (queue != null) {
      queue.disposing = true;
      queue.drain();
    }

    final svc = _cache.remove(sourceId);
    _signatures.remove(sourceId);
    if (svc == null) return;
    if (queue == null) {
      _dispose(svc);
      return;
    }

    (queue.running ?? Future<void>.value()).then<void>(
      (_) => _dispose(svc),
      onError: (Object _, StackTrace _) => _dispose(svc),
    );
  }

  /// Disposes all cached services (call on app exit or full reload).
  static void disposeAll() {
    final queues = Map<String, _ExtensionSourceQueue>.from(_queues);
    _queues.clear();
    for (final queue in queues.values) {
      queue.disposing = true;
      queue.drain();
    }

    final services = Map<String, ExtensionService>.from(_cache);
    _cache.clear();
    _signatures.clear();
    for (final entry in services.entries) {
      final service = entry.value;
      final queue = queues[entry.key];
      if (queue == null) {
        _dispose(service);
      } else {
        (queue.running ?? Future<void>.value()).then<void>(
          (_) => _dispose(service),
          onError: (Object _, StackTrace _) => _dispose(service),
        );
      }
    }
  }

  static void _dispose(ExtensionService service) {
    try {
      service.dispose();
    } catch (_) {}
  }
}

class _ExtensionSourceQueue {
  /// The call currently occupying the (non-reentrant) extension runtime.
  Future<void>? running;
  /// Calls waiting for the runtime, bucketed by [ExtensionServiceRegistry.priorityFor].
  /// Split so playback (`getVideoList`, bucket 0) can overtake `getDetail`
  /// (bucket 1) and the decorative tabs (bucket 2) instead of queueing behind
  /// them — the tap→play path must never wait on a metadata or tab fetch.
  final List<List<_ExtensionCall>> _buckets = [[], [], []];
  bool disposing = false;

  int get pending => _buckets.fold(0, (sum, bucket) => sum + bucket.length);

  void enqueue(_ExtensionCall call) {
    call.bucket = _buckets[call.priority];
    call.bucket.add(call);
  }

  /// Next call to run: lowest non-empty bucket, oldest first within it.
  _ExtensionCall? dequeue() {
    for (final bucket in _buckets) {
      if (bucket.isNotEmpty) return bucket.removeAt(0);
    }
    return null;
  }

  /// Drops waiting calls, completing each with [error]. The call that is
  /// already running is left alone: it owns the runtime and cannot be
  /// interrupted safely.
  void drain([Object? error]) {
    final pending = _buckets.expand((bucket) => bucket).toList();
    for (final bucket in _buckets) {
      bucket.clear();
    }
    for (final call in pending) {
      if (!call.completer.isCompleted) {
        call.completer.completeError(
          error ?? StateError('Extension source was disposed'),
        );
      }
    }
  }
}

/// One queued extension call, with the priority that decides when it runs.
class _ExtensionCall {
  final Completer<dynamic> completer;
  /// Scheduling bucket from [ExtensionServiceRegistry.priorityFor];
  /// [_ExtensionSourceQueue] keeps a list per bucket.
  final int priority;
  /// Runs this call's extension method and completes [completer]. Owned by
  /// the call rather than by the pump closure, so whichever invocation drains
  /// the shared queue executes the correct action.
  final Future<void> Function() execute;
  /// Kept in sync with [_ExtensionSourceQueue._buckets] by `enqueue`.
  late List<_ExtensionCall> bucket;
  /// When the call entered the queue, used to report how long it waited.
  final DateTime queuedAt;

  _ExtensionCall(this.completer, this.priority, this.execute)
    : queuedAt = DateTime.now();
}

/// Returns the cached [ExtensionService] for [source] via
/// [ExtensionServiceRegistry].  The service is intentionally NOT disposed
/// after each call — it is reused to avoid concurrent QuickJS runtime crashes.
///
/// Pass [serviceType] so the scheduler can serve the playback-critical calls
/// (`getVideoList`) before metadata and decorative ones
/// (see [ExtensionServiceRegistry.priorityFor]).
Future<T> withExtensionService<T>(
  Source source,
  Future<T> Function(ExtensionService service) action, {
  String? serviceType,
}) {
  return ExtensionServiceRegistry.run(source, action, serviceType: serviceType);
}
