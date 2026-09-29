import 'dart:async';

import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/models/source.dart';

import 'dart/service.dart';
import 'javascript/service.dart';
import 'mihon/service.dart';

ExtensionService getExtensionService(
  Source source,
  String androidProxyServer,
) {
  return switch (source.sourceCodeLanguage) {
    SourceCodeLanguage.dart => DartExtensionService(source),
    SourceCodeLanguage.javascript => JsExtensionService(source),
    SourceCodeLanguage.mihon => MihonExtensionService(source, androidProxyServer),
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
  static ExtensionService get(Source source, String proxyServer) {
    final key = _key(source);
    final signature = _signature(source);
    if (_signatures[key] != null && _signatures[key] != signature) {
      final previous = _cache.remove(key);
      if (previous != null) _dispose(previous);
    }
    _signatures[key] = signature;
    return _cache.putIfAbsent(key, () => getExtensionService(source, proxyServer));
  }

  /// Runs calls for one source in order. Extension runtimes are not reentrant:
  /// two async JS/Dart calls can otherwise interleave on the same interpreter.
  static Future<T> run<T>(
    Source source,
    String proxyServer,
    Future<T> Function(ExtensionService service) action,
  ) {
    final key = _key(source);
    final queue = _queues.putIfAbsent(key, _ExtensionSourceQueue.new);
    final generation = queue.generation;
    final result = Completer<T>();

    late final Future<void> current;
    current = queue.tail.then<void>((_) async {
      if (queue.generation != generation ||
          !identical(_queues[key], queue) ||
          queue.disposing) {
        result.completeError(
          StateError('Extension source was disposed before the request ran'),
        );
        return;
      }

      try {
        result.complete(await action(get(source, proxyServer)));
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    queue.tail = current;

    current.then<void>(
      (_) => _removeQueueIfIdle(key, queue, current),
      onError: (Object _, StackTrace __) =>
          _removeQueueIfIdle(key, queue, current),
    );
    return result.future;
  }

  static void _removeQueueIfIdle(
    String key,
    _ExtensionSourceQueue queue,
    Future<void> completed,
  ) {
    if (identical(_queues[key], queue) && identical(queue.tail, completed)) {
      _queues.remove(key);
    }
  }

  /// Disposes and removes the service for a single source (e.g. on uninstall).
  /// The active call is allowed to finish; queued calls are invalidated and
  /// cannot recreate the runtime after it has been removed.
  static void disposeSource(String sourceId) {
    final queue = _queues.remove(sourceId);
    if (queue != null) {
      queue.generation++;
      queue.disposing = true;
    }

    final svc = _cache.remove(sourceId);
    _signatures.remove(sourceId);
    if (svc == null) return;
    if (queue == null) {
      _dispose(svc);
      return;
    }

    queue.tail.then<void>(
      (_) => _dispose(svc),
      onError: (Object _, StackTrace __) => _dispose(svc),
    );
  }

  /// Disposes all cached services (call on app exit or full reload).
  static void disposeAll() {
    final queues = Map<String, _ExtensionSourceQueue>.from(_queues);
    _queues.clear();
    for (final queue in queues.values) {
      queue.generation++;
      queue.disposing = true;
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
        queue.tail.then<void>(
          (_) => _dispose(service),
          onError: (Object _, StackTrace __) => _dispose(service),
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
  Future<void> tail = Future<void>.value();
  int generation = 0;
  bool disposing = false;
}

/// Returns the cached [ExtensionService] for [source] via
/// [ExtensionServiceRegistry].  The service is intentionally NOT disposed
/// after each call — it is reused to avoid concurrent QuickJS runtime crashes.
Future<T> withExtensionService<T>(
  Source source,
  String proxyServer,
  Future<T> Function(ExtensionService service) action,
) {
  return ExtensionServiceRegistry.run(source, proxyServer, action);
}
  