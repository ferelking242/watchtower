import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/download_manager/download_size.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/http/rhttp/src/model/settings.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/m3u8/models/ts_info.dart';
import 'package:watchtower/src/rust/frb_generated.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart' as path;
import 'package:encrypt/encrypt.dart' as encrypt;

/// Cancellation flags visible from the *main* isolate. Used to short-circuit
/// the receivePort listener and to ignore late progress messages from a
/// cancelled task.
final downloadTaskCancellation = <String, bool>{};

/// Monotonically increasing version counter per taskId.
/// When a new submission is made for the same taskId (e.g. after a resume),
/// the old listener's version no longer matches and it drops all messages
/// it receives, preventing stale terminal events from corrupting the new download.
final _listenerVersion = <String, int>{};

/// Shared Isolate pool to optimize performance
/// Instead of creating a new Isolate for each download,
/// we use a limited pool of workers that process tasks in queue.
class DownloadIsolatePool {
  static DownloadIsolatePool? _instance;
  final List<_PoolWorker> _workers = [];
  final Queue<_DownloadTask> _taskQueue = Queue();
  final Set<int> _availableWorkers = {}; // Track available workers by index
  final DownloadPoolInitializationGate _initializationGate =
      DownloadPoolInitializationGate();
  final int poolSize;
  bool _initialized = false;

  DownloadIsolatePool._({this.poolSize = 3});

  /// Get the singleton instance of the pool
  static DownloadIsolatePool get instance {
    _instance ??= DownloadIsolatePool._();
    return _instance!;
  }

  /// Configure the pool size (call before initialize)
  static void configure({int poolSize = 3}) {
    if (_instance != null && _instance!._initialized) {
      if (kDebugMode) {
        if (kDebugMode)
          print('[DownloadPool] Cannot reconfigure after initialization');
      }
      return;
    }
    _instance = DownloadIsolatePool._(poolSize: poolSize);
  }

  /// Initialize the Isolate pool
  Future<void> initialize() async {
    if (_initialized) return;

    await _initializationGate.initialize(_initializeWorkers);
  }

  Future<void> _initializeWorkers() async {
    final poolStopwatch = Stopwatch()..start();
    final startingWorkers = <_PoolWorker>[];
    AppLogger.log(
      'Download pool initialization started workers=$poolSize',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    try {
      for (int i = 0; i < poolSize; i++) {
        final workerStopwatch = Stopwatch()..start();
        AppLogger.log(
          'Download worker $i startup started',
          logLevel: LogLevel.debug,
          tag: LogTag.download,
        );
        final worker = await _PoolWorker.create(i);
        startingWorkers.add(worker);
        AppLogger.log(
          'Download worker $i ready in ${workerStopwatch.elapsedMilliseconds}ms',
          logLevel: LogLevel.info,
          tag: LogTag.download,
        );
      }

      _workers
        ..clear()
        ..addAll(startingWorkers);
      _availableWorkers
        ..clear()
        ..addAll(List<int>.generate(poolSize, (index) => index));
      _initialized = true;
      AppLogger.log(
        'Download pool ready workers=$poolSize '
        'in ${poolStopwatch.elapsedMilliseconds}ms',
        logLevel: LogLevel.info,
        tag: LogTag.download,
      );
    } catch (error, stackTrace) {
      for (final worker in startingWorkers) {
        worker.dispose();
      }
      _workers.clear();
      _availableWorkers.clear();
      _initialized = false;
      AppLogger.log(
        'Download pool startup failed after ${poolStopwatch.elapsedMilliseconds}ms; '
        'partial workers were stopped',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Submit a file download task (manga/anime)
  Future<void> submitFileDownload({
    required String taskId,
    required List<PageUrl> pageUrls,
    required int concurrentDownloads,
    required ItemType itemType,
    int writeMode = 0,
    int speedLimitKBs = 0,
    required void Function(DownloadProgress) onProgress,
    required FutureOr<void> Function() onComplete,
    required void Function(Exception) onError,
    void Function()? onCancelled,
  }) async {
    if (!_initialized) await initialize();

    AppLogger.log(
      '[ch:$taskId] pool submit pages=${pageUrls.length} '
      'pageConcurrency=$concurrentDownloads active=$activeWorkers '
      'queued=$pendingTasks',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    // Mark the task as active (not cancelled) and stamp a new listener version.
    downloadTaskCancellation[taskId] = false;
    final myVersion = (_listenerVersion[taskId] ?? 0) + 1;
    _listenerVersion[taskId] = myVersion;

    final receivePort = ReceivePort();
    final task = _DownloadTask(
      taskId: taskId,
      type: _TaskType.fileDownload,
      params: FileDownloadParams(
        pageUrls: pageUrls,
        concurrentDownloads: concurrentDownloads,
        itemType: itemType,
        writeMode: writeMode,
        speedLimitKBs: speedLimitKBs,
      ),
      sendPort: receivePort.sendPort,
    );

    // Listen for progress messages.
    // Key invariants:
    //  - We NEVER close early on cancellation; doing so would prevent the
    //    terminal DownloadPoolException from being processed, leaking the
    //    completer in _downloadFilesWithProgress forever.
    //  - On terminal messages (DownloadComplete / Exception) we check whether
    //    the task was cancelled at that moment and route to onCancelled instead
    //    of onComplete / onError so the download() function can exit cleanly
    //    without marking the chapter as failed.
    //  - We also check the listener version to discard messages that arrived
    //    after a newer submission (resume) claimed the same taskId.
    receivePort.listen((message) {
      if (message is _DownloadPoolLog) {
        AppLogger.log(
          '[ch:${message.taskId}] ${message.message}',
          logLevel: message.level,
          tag: LogTag.download,
        );
        return;
      }

      final isCurrent = _listenerVersion[taskId] == myVersion;

      if (message is DownloadProgress) {
        // Drop progress updates when cancelled or if superseded by a newer submission.
        if (downloadTaskCancellation[taskId] != true && isCurrent) {
          onProgress(message);
        }
        return;
      }

      // Terminal message — always process so the completer is resolved.
      final wasCancelled = downloadTaskCancellation[taskId] == true;
      downloadTaskCancellation.remove(taskId);
      if (_listenerVersion[taskId] == myVersion) {
        _listenerVersion.remove(taskId);
      }
      receivePort.close();

      if (!isCurrent) return; // Stale listener from before a resume — ignore.

      if (message is DownloadComplete) {
        if (wasCancelled) {
          onCancelled?.call();
        } else {
          Future.sync(onComplete).catchError((error, stack) {
            final exception = error is Exception
                ? error
                : Exception(error.toString());
            onError(exception);
          });
        }
      } else if (message is Exception) {
        if (wasCancelled) {
          onCancelled?.call();
        } else {
          onError(message);
        }
      }
    });

    _enqueueTask(task);
  }

  /// Submit an M3U8 segment download task
  Future<void> submitM3u8Download({
    required String taskId,
    required List<TsInfo> segments,
    required String tempDir,
    required Uint8List? key,
    required Uint8List? iv,
    required int? mediaSequence,
    int totalSegments = 0,
    int initialCompletedSegments = 0,
    int initialDownloadedBytes = 0,
    required int concurrentDownloads,
    required Map<String, String>? headers,
    required ItemType itemType,
    int writeMode = 0,
    int speedLimitKBs = 0,
    required void Function(DownloadProgress) onProgress,
    required FutureOr<void> Function() onComplete,
    required void Function(Exception) onError,
    void Function()? onCancelled,
  }) async {
    if (!_initialized) await initialize();

    AppLogger.log(
      '[ch:$taskId] pool submit segments=${segments.length} '
      'active=$activeWorkers queued=$pendingTasks',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    downloadTaskCancellation[taskId] = false;
    final myVersion = (_listenerVersion[taskId] ?? 0) + 1;
    _listenerVersion[taskId] = myVersion;

    final receivePort = ReceivePort();
    final task = _DownloadTask(
      taskId: taskId,
      type: _TaskType.m3u8Download,
      params: M3u8DownloadParams(
        segments: segments,
        tempDir: tempDir,
        key: key,
        iv: iv,
        mediaSequence: mediaSequence,
        totalSegments: totalSegments > 0 ? totalSegments : segments.length,
        initialCompletedSegments: initialCompletedSegments,
        initialDownloadedBytes: initialDownloadedBytes,
        concurrentDownloads: concurrentDownloads,
        headers: headers,
        itemType: itemType,
        writeMode: writeMode,
        speedLimitKBs: speedLimitKBs,
      ),
      sendPort: receivePort.sendPort,
    );

    receivePort.listen((message) {
      final isCurrent = _listenerVersion[taskId] == myVersion;

      if (message is DownloadProgress) {
        if (downloadTaskCancellation[taskId] != true && isCurrent) {
          onProgress(message);
        }
        return;
      }

      final wasCancelled = downloadTaskCancellation[taskId] == true;
      downloadTaskCancellation.remove(taskId);
      if (_listenerVersion[taskId] == myVersion) {
        _listenerVersion.remove(taskId);
      }
      receivePort.close();

      if (!isCurrent) return;

      if (message is DownloadComplete) {
        if (wasCancelled) {
          onCancelled?.call();
        } else {
          Future.sync(onComplete).catchError((error, stack) {
            final exception = error is Exception
                ? error
                : Exception(error.toString());
            onError(exception);
          });
        }
      } else if (message is Exception) {
        if (wasCancelled) {
          onCancelled?.call();
        } else {
          onError(message);
        }
      }
    });

    _enqueueTask(task);
  }

  /// Cancel a download task. Sets the main-isolate cancel flag *and*
  /// broadcasts a cancellation message to every worker so the in-flight
  /// download loop exits at its next checkpoint instead of running to
  /// completion.
  void cancelTask(String taskId) {
    downloadTaskCancellation[taskId] = true;
    for (final worker in _workers) {
      worker.cancel(taskId);
    }
  }

  /// Add a task to the queue and try to process it
  void _enqueueTask(_DownloadTask task) {
    _taskQueue.add(task);
    AppLogger.log(
      '[ch:${task.taskId}] pool queued pending=$pendingTasks '
      'active=$activeWorkers',
      logLevel: LogLevel.debug,
      tag: LogTag.download,
    );
    _processQueue();
  }

  /// Process the task queue
  void _processQueue() {
    while (_taskQueue.isNotEmpty && _availableWorkers.isNotEmpty) {
      final task = _taskQueue.removeFirst();
      final workerIndex = _availableWorkers.first;
      _availableWorkers.remove(workerIndex);
      final worker = _workers[workerIndex];

      AppLogger.log(
        '[ch:${task.taskId}] pool dispatch worker=$workerIndex '
        'active=$activeWorkers pending=$pendingTasks',
        logLevel: LogLevel.info,
        tag: LogTag.download,
      );

      worker.executeTask(task).then<void>(
        (_) {
          _availableWorkers.add(workerIndex); // Worker is free again
          AppLogger.log(
            '[ch:${task.taskId}] pool worker=$workerIndex finished '
            'available=${_availableWorkers.length}',
            logLevel: LogLevel.info,
            tag: LogTag.download,
          );
          _processQueue(); // Process the next task
        },
        onError: (Object error, StackTrace stackTrace) {
          _availableWorkers.add(workerIndex);
          AppLogger.log(
            '[ch:${task.taskId}] pool worker=$workerIndex failed while '
            'running the task',
            logLevel: LogLevel.warning,
            tag: LogTag.download,
            error: error,
            stackTrace: stackTrace,
          );
          _processQueue();
        },
      );
    }
  }

  /// Number of pending tasks
  int get pendingTasks => _taskQueue.length;

  /// Number of active workers
  int get activeWorkers => poolSize - _availableWorkers.length;

  /// Close the pool
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _taskQueue.clear();
    _availableWorkers.clear();
    downloadTaskCancellation.clear();
    _initialized = false;
    _initializationGate.reset();
  }
}

/// Coalesces concurrent first-use requests into a single worker-pool startup.
///
/// This small gate is isolated from isolate creation so its concurrency and
/// retry behavior can be covered by unit tests without starting native workers.
@visibleForTesting
class DownloadPoolInitializationGate {
  bool _initialized = false;
  Future<void>? _initializing;

  bool get isInitialized => _initialized;

  Future<void> initialize(Future<void> Function() createWorkers) {
    if (_initialized) return Future<void>.value();
    final current = _initializing;
    if (current != null) return current;

    final attempt = _runInitialization(createWorkers);
    _initializing = attempt;
    return attempt;
  }

  Future<void> _runInitialization(
    Future<void> Function() createWorkers,
  ) async {
    try {
      await createWorkers();
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  void reset() {
    _initialized = false;
    _initializing = null;
  }
}

/// Supported task types
enum _TaskType { fileDownload, m3u8Download }

/// Download task
class _DownloadTask {
  final String taskId;
  final _TaskType type;
  final dynamic params;
  final SendPort sendPort;

  _DownloadTask({
    required this.taskId,
    required this.type,
    required this.params,
    required this.sendPort,
  });
}

/// Lightweight diagnostic event forwarded from a download isolate.
class _DownloadPoolLog {
  final String taskId;
  final String message;
  final LogLevel level;

  const _DownloadPoolLog(this.taskId, this.message, this.level);
}

/// Parameters for file download
class FileDownloadParams {
  final List<PageUrl> pageUrls;
  final int concurrentDownloads;
  final ItemType itemType;

  /// Mode d'écriture disque :
  /// 0 = .part + rename atomique (défaut, reprise Range possible)
  /// 1 = pré-allocation de l'espace puis écriture
  /// 2 = direct au chemin final (legacy, risqué sur interruption)
  final int writeMode;

  /// Limite de débit globale en KB/s (0 = illimité) — Speed Master.
  final int speedLimitKBs;

  FileDownloadParams({
    required this.pageUrls,
    required this.concurrentDownloads,
    required this.itemType,
    this.writeMode = 0,
    this.speedLimitKBs = 0,
  });
}

/// Parameters for M3U8 download
class M3u8DownloadParams {
  final List<TsInfo> segments;
  final String tempDir;
  final Uint8List? key;
  final Uint8List? iv;
  final int? mediaSequence;

  /// Total segments in the original playlist, including segments already on
  /// disk when this task is resumed.
  final int totalSegments;
  final int initialCompletedSegments;
  final int initialDownloadedBytes;
  final int concurrentDownloads;
  final Map<String, String>? headers;
  final ItemType itemType;

  /// Voir [FileDownloadParams.writeMode] — appliqué au fichier fusionné final.
  final int writeMode;

  /// Limite de débit globale en KB/s (0 = illimité) — Speed Master.
  final int speedLimitKBs;

  M3u8DownloadParams({
    required this.segments,
    required this.tempDir,
    required this.key,
    required this.iv,
    required this.mediaSequence,
    this.totalSegments = 0,
    this.initialCompletedSegments = 0,
    this.initialDownloadedBytes = 0,
    required this.concurrentDownloads,
    required this.headers,
    required this.itemType,
    this.writeMode = 0,
    this.speedLimitKBs = 0,
  });
}

/// Token-bucket partagé entre tous les slots d'une même tâche — implémente la
/// limite de débit du Speed Master sans bloquer les autres téléchargements.
class _Throttle {
  final double bytesPerSec;
  double _tokens;
  DateTime _lastRefill;

  _Throttle(this.bytesPerSec)
    : _tokens = bytesPerSec, // burst initial = 1 s de budget
      _lastRefill = DateTime.now();

  void _refill() {
    final now = DateTime.now();
    final secs = now.difference(_lastRefill).inMicroseconds / 1e6;
    if (secs <= 0) return;
    // Burst cap à 2 s de budget pour rester réactif sans écraser la limite.
    _tokens = math.min(bytesPerSec * 2, _tokens + bytesPerSec * secs);
    _lastRefill = now;
  }

  Future<void> acquire(int n) async {
    if (bytesPerSec <= 0 || n <= 0) return;
    _refill();
    if (_tokens >= n) {
      _tokens -= n;
      return;
    }
    final deficit = n - _tokens;
    _tokens = 0;
    await Future<void>.delayed(
      Duration(milliseconds: (deficit / bytesPerSec * 1000).ceil()),
    );
  }
}

/// Pool worker that executes tasks in a persistent Isolate
class _PoolWorker {
  final int id;
  Isolate? _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;
  SendPort? _cancelPort;
  final Completer<void> _ready = Completer();

  _PoolWorker._(this.id);

  static Future<_PoolWorker> create(int id) async {
    final worker = _PoolWorker._(id);
    await worker._spawn();
    return worker;
  }

  Future<void> _spawn() async {
    _receivePort = ReceivePort();
    final taskPortCompleter = Completer<SendPort>();
    final cancelPortCompleter = Completer<SendPort>();

    try {
      _isolate = await Isolate.spawn(
        _workerEntryPoint,
        _WorkerInit(id, _receivePort.sendPort),
      );

      // The worker first sends back its task SendPort, then its cancel
      // SendPort. Bound this wait: Rust initialization can fail inside the
      // isolate before it reaches the handshake, otherwise the queue hangs.
      _receivePort.listen((message) {
        if (message is _WorkerHandshake) {
          if (!taskPortCompleter.isCompleted) {
            taskPortCompleter.complete(message.taskPort);
          }
          if (!cancelPortCompleter.isCompleted) {
            cancelPortCompleter.complete(message.cancelPort);
          }
        } else if (message is SendPort && !taskPortCompleter.isCompleted) {
          // Backwards-compatible path for workers that only send a task port.
          taskPortCompleter.complete(message);
          if (!cancelPortCompleter.isCompleted) {
            cancelPortCompleter.completeError(
              StateError('Worker $id did not provide a cancellation port'),
            );
          }
        }
      });

      final ports = await Future.wait<SendPort>([
        taskPortCompleter.future,
        cancelPortCompleter.future,
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Download worker $id did not complete its startup handshake '
          'within 20 seconds',
        ),
      );

      _sendPort = ports[0];
      _cancelPort = ports[1];
      _ready.complete();
    } catch (error, stackTrace) {
      _receivePort.close();
      _isolate?.kill();
      AppLogger.log(
        'Download worker $id failed to start',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute a task in this worker
  Future<void> executeTask(_DownloadTask task) async {
    await _ready.future;

    final completer = Completer<void>();

    // Create a port to receive messages from this worker
    final taskPort = ReceivePort();

    taskPort.listen((message) {
      // Forward the message to the original task port
      task.sendPort.send(message);

      if (message is DownloadComplete || message is Exception) {
        taskPort.close();
        if (!completer.isCompleted) completer.complete();
      }
    });

    // Send the task to the worker
    _sendPort.send(
      _WorkerTask(
        taskId: task.taskId,
        type: task.type,
        params: task.params,
        replyPort: taskPort.sendPort,
      ),
    );

    return completer.future;
  }

  /// Tell the worker isolate to abort the named task at its next checkpoint.
  void cancel(String taskId) {
    final port = _cancelPort;
    if (port != null) {
      port.send(_CancelMessage(taskId));
    }
  }

  void dispose() {
    _isolate?.kill();
    _receivePort.close();
  }
}

/// Worker initialization message
class _WorkerInit {
  final int workerId;
  final SendPort mainPort;
  _WorkerInit(this.workerId, this.mainPort);
}

/// Sent from the worker back to the main isolate once both SendPorts
/// are ready. Replaces the old "send raw SendPort" pattern so cancellation
/// can be wired up before any task is dispatched.
class _WorkerHandshake {
  final SendPort taskPort;
  final SendPort cancelPort;
  _WorkerHandshake(this.taskPort, this.cancelPort);
}

/// Sent from the main isolate to a worker over its dedicated cancel port.
class _CancelMessage {
  final String taskId;
  _CancelMessage(this.taskId);
}

/// Task sent to the worker
class _WorkerTask {
  final String taskId;
  final _TaskType type;
  final dynamic params;
  final SendPort replyPort;

  _WorkerTask({
    required this.taskId,
    required this.type,
    required this.params,
    required this.replyPort,
  });
}

/// Per-isolate set of cancelled task IDs. Updated by the cancellation
/// listener (non-blocking) and consulted by the download loops between
/// segments/files so they can short-circuit cleanly.
final Set<String> _workerCancelledTasks = <String>{};

/// Converts any exception to a plain [Exception] containing only the string
/// representation so it can safely cross isolate boundaries via [SendPort].
///
/// [RhttpClient] (and other flutter_rust_bridge objects) hold a [RustArc]
/// which is NOT sendable between Dart isolates. Forwarding a raw
/// [RhttpWrappedClientException] / [DownloadPoolException] that wraps one
/// causes: "Illegal argument in isolate message: object is unsendable".
Exception _toSendable(Object e) => Exception(e.toString());

/// Isolate worker entry point
void _workerEntryPoint(_WorkerInit init) async {
  // Initialize dependencies in the Isolate
  await RustLib.init();

  final httpClient = MClient.httpClient(
    settings: const ClientSettings(
      throwOnStatusCode: false,
      tlsSettings: TlsSettings(verifyCertificates: true),
    ),
  );

  // Create the receive ports for this worker: one for tasks, one for
  // cancel messages. The cancel port uses listen() so it processes
  // messages even while the task port's await-for is busy.
  final receivePort = ReceivePort();
  final cancelPort = ReceivePort();
  cancelPort.listen((message) {
    if (message is _CancelMessage) {
      _workerCancelledTasks.add(message.taskId);
    }
  });

  // Send both SendPorts back to the main isolate via a single handshake.
  init.mainPort.send(
    _WorkerHandshake(receivePort.sendPort, cancelPort.sendPort),
  );

  if (kDebugMode) {
    if (kDebugMode) print('[Worker ${init.workerId}] Ready');
  }

  // Listen for tasks
  await for (final message in receivePort) {
    if (message is _WorkerTask) {
      // Reset cancellation state for this taskId in case it was reused.
      _workerCancelledTasks.remove(message.taskId);
      try {
        if (message.type == _TaskType.fileDownload) {
          await _processFileDownload(
            message.taskId,
            message.params as FileDownloadParams,
            message.replyPort,
            httpClient,
          );
        } else if (message.type == _TaskType.m3u8Download) {
          await _processM3u8Download(
            message.taskId,
            message.params as M3u8DownloadParams,
            message.replyPort,
            httpClient,
          );
        }
      } catch (e) {
        message.replyPort.send(
          _toSendable(DownloadPoolException('Task failed', e)),
        );
      } finally {
        _workerCancelledTasks.remove(message.taskId);
      }
    }
  }
}

bool _isCancelled(String taskId) => _workerCancelledTasks.contains(taskId);

/// Process a file download
///
/// Uses a sliding-window (circular slot buffer) so a slow file never
/// blocks other slots from starting — every freed slot is immediately
/// filled from the queue.
Future<void> _processFileDownload(
  String taskId,
  FileDownloadParams params,
  SendPort replyPort,
  Client client,
) async {
  int completed = 0;
  final total = params.pageUrls.length;
  final attemptToken =
      '${DateTime.now().microsecondsSinceEpoch}-${Isolate.current.hashCode}';

  if (total == 0) {
    replyPort.send(
      _DownloadPoolLog(
        taskId,
        'transfer skipped because there are no pending pages',
        LogLevel.warning,
      ),
    );
    replyPort.send(DownloadComplete());
    return;
  }

  final int concurrency = params.concurrentDownloads.clamp(1, 32);
  final slots = List<Future<void>>.filled(concurrency, Future<void>.value());

  try {
    final throttle = _Throttle(params.speedLimitKBs.toDouble());
    replyPort.send(
      _DownloadPoolLog(
        taskId,
        'transfer started pages=$total pageConcurrency=$concurrency',
        LogLevel.info,
      ),
    );
    // Circular slot buffer: slot i is awaited before launching item i,
    // guaranteeing at most `concurrency` downloads in flight at once.
    Object? firstError;
    StackTrace? firstStackTrace;

    for (int i = 0; i < params.pageUrls.length; i++) {
      if (firstError != null) break;
      if (_isCancelled(taskId)) {
        await Future.wait(slots, eagerError: false).catchError((_) => <void>[]);
        replyPort.send(
          _toSendable(
            DownloadPoolException('Task $taskId cancelled by user', null),
          ),
        );
        return;
      }

      final slotIdx = i % concurrency;
      await slots[slotIdx];
      if (firstError != null || _isCancelled(taskId)) break;

      final pageUrl = params.pageUrls[i];
      slots[slotIdx] =
          _downloadFile(
                taskId,
                pageUrl,
                client,
                params.itemType,
                replyPort,
                writeMode: params.writeMode,
                throttle: throttle,
                stagingSuffix: '$attemptToken-$i',
              )
              .then((_) {
                if (params.itemType != ItemType.anime) {
                  completed++;
                  replyPort.send(
                    DownloadProgress(
                      pageUrl: pageUrl,
                      completed,
                      total,
                      params.itemType,
                    ),
                  );
                }
              })
              .catchError((Object error, StackTrace stackTrace) {
                firstError ??= DownloadPoolException(
                  'Error downloading ${pageUrl.fileName}',
                  error,
                );
                firstStackTrace ??= stackTrace;
              });
    }

    // Always drain every in-flight page before returning the worker or
    // reporting failure. Otherwise a retry can race with writes from this
    // failed attempt and both can rename the same temporary file.
    await Future.wait(slots, eagerError: false);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }

    if (_isCancelled(taskId)) {
      replyPort.send(
        _toSendable(
          DownloadPoolException('Task $taskId cancelled by user', null),
        ),
      );
      return;
    }

    replyPort.send(
      _DownloadPoolLog(taskId, 'all $total pages transferred', LogLevel.info),
    );
    replyPort.send(DownloadComplete());
  } catch (e) {
    // A slot awaited while scheduling can fail before the final wait. Drain
    // every other slot before sending the terminal event so no page can keep
    // writing after the scheduler releases this chapter.
    await Future.wait(slots, eagerError: false).catchError((_) => <void>[]);
    replyPort.send(_toSendable(DownloadPoolException('Download failed', e)));
  }
}

/// Download an individual file.
///
/// Disk-write safety ([writeMode]):
///  0 = `.part` + atomic rename (default). A partially-written file stays
///      as `<name>.part` and is **resumed** via HTTP Range on retry/restart,
///      and remains playable if the user pauses (partial file readable).
///  1 = Pre-allocation: reserve the full Content-Length up front (no resume).
///  2 = Legacy direct write to final path (risky on interruption).
///
/// [throttle] implements the Speed Master per-task bandwidth cap.
class _ParsedContentRange {
  final int start;
  final int end;
  final int? total;

  const _ParsedContentRange(this.start, this.end, this.total);
}

String? _responseHeader(StreamedResponse response, String name) {
  final lower = name.toLowerCase();
  for (final entry in response.headers.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

_ParsedContentRange? _parseContentRange(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  final unsatisfied = RegExp(r'^bytes\s+\*/(\d+)$').firstMatch(trimmed);
  if (unsatisfied != null) {
    final total = int.tryParse(unsatisfied.group(1)!);
    return total == null ? null : _ParsedContentRange(0, -1, total);
  }
  final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(trimmed);
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  final end = int.tryParse(match.group(2)!);
  final total = match.group(3) == '*' ? null : int.tryParse(match.group(3)!);
  if (start == null ||
      end == null ||
      start > end ||
      (match.group(3) != '*' && total == null) ||
      (total != null && total <= end)) {
    return null;
  }
  return _ParsedContentRange(
    start,
    end,
    total,
  );
}

Future<Map<String, dynamic>> _readPartMetadata(File metadataFile) async {
  try {
    if (!await metadataFile.exists()) return <String, dynamic>{};
    final decoded = jsonDecode(await metadataFile.readAsString());
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<int?> _probeContentLength(
  Client client,
  Uri uri,
  Map<String, String> headers,
) async {
  try {
    final head = Request('HEAD', uri);
    head.headers.addAll(headers);
    final headResponse = await client
        .send(head)
        .timeout(const Duration(seconds: 15));
    await headResponse.stream.drain();
    final headLength = trustedDownloadByteCount(headResponse.contentLength);
    if (headLength != null) return headLength;
  } catch (_) {
    // Some CDNs reject HEAD. Fall through to the one-byte range probe.
  }

  // A number of video CDNs omit Content-Length on HEAD but expose the real
  // representation size in Content-Range for a one-byte range request. The
  // response body is cancelled immediately; no media is downloaded to disk.
  try {
    final probe = Request('GET', uri);
    probe.headers.addAll(headers);
    probe.headers['Range'] = 'bytes=0-0';
    final response = await client
        .send(probe)
        .timeout(const Duration(seconds: 15));
    try {
      final parsed = _parseContentRange(
        _responseHeader(response, 'content-range'),
      );
      if ((response.statusCode == 206 || response.statusCode == 416) &&
          trustedDownloadByteCount(parsed?.total) != null) {
        return trustedDownloadByteCount(parsed?.total);
      }
      // A server may ignore Range but still provide the full size in 200.
      if (response.statusCode == 200 &&
          trustedDownloadByteCount(response.contentLength) != null) {
        return trustedDownloadByteCount(response.contentLength);
      }
    } finally {
      await response.stream.listen((_) {}).cancel();
    }
  } catch (_) {
    // Total size is genuinely unavailable; the streaming GET still works.
  }
  return null;
}

@visibleForTesting
String? imageDownloadResponseError({
  required int statusCode,
  required Map<String, String> headers,
  required List<int> bodyBytes,
  int? receivedBytes,
  int? expectedBytes,
  List<int>? tailBytes,
}) {
  if (statusCode != 200) return 'HTTP $statusCode';
  final actualLength = receivedBytes ?? bodyBytes.length;
  if (actualLength <= 0 || bodyBytes.isEmpty) return 'empty response body';

  String? header(String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  final declaredLength =
      expectedBytes ?? int.tryParse(header('content-length') ?? '');
  if (declaredLength != null &&
      declaredLength > 0 &&
      declaredLength != actualLength) {
    return 'incomplete response body ($actualLength/$declaredLength bytes)';
  }

  final contentType = header('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase() ??
      '';
  if (contentType.startsWith('text/') ||
      contentType.startsWith('application/xhtml+xml') ||
      contentType.startsWith('application/json') ||
      contentType.endsWith('+json')) {
    return 'unexpected $contentType response';
  }

  final prefix = utf8
      .decode(bodyBytes.take(512).toList(), allowMalformed: true)
      .trimLeft()
      .toLowerCase();
  if (prefix.startsWith('<!doctype html') ||
      prefix.startsWith('<html') ||
      prefix.startsWith('<head')) {
    return 'server returned an HTML page instead of an image';
  }
  if (!isReusableImagePayload(
    length: actualLength,
    prefix: bodyBytes,
    tail: tailBytes ?? bodyBytes.skip(bodyBytes.length > 32 ? bodyBytes.length - 32 : 0).toList(),
  )) {
    return 'image payload is incomplete or invalid';
  }
  return null;
}

/// Lightweight image integrity check used before reusing cached page files.
///
/// It checks common image signatures and their terminal markers without
/// decoding the whole image. Unknown image formats remain reusable when they
/// have a plausible size and do not look like an error page.
@visibleForTesting
bool isReusableImagePayload({
  required int length,
  required List<int> prefix,
  required List<int> tail,
}) {
  if (length < 16 || prefix.isEmpty) return false;

  final text = utf8
      .decode(prefix.take(512).toList(), allowMalformed: true)
      .trimLeft()
      .toLowerCase();
  if (text.startsWith('<!doctype html') ||
      text.startsWith('<html') ||
      text.startsWith('<head') ||
      text.startsWith('{"error"') ||
      text.startsWith('{"message"') ||
      text.startsWith('access denied') ||
      text.startsWith('not found')) {
    return false;
  }

  bool startsWith(List<int> signature) {
    if (prefix.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (prefix[index] != signature[index]) return false;
    }
    return true;
  }

  bool endsWith(List<int> signature) {
    if (tail.length < signature.length) return false;
    final offset = tail.length - signature.length;
    for (var index = 0; index < signature.length; index++) {
      if (tail[offset + index] != signature[index]) return false;
    }
    return true;
  }

  const jpegSignature = [0xff, 0xd8, 0xff];
  if (startsWith(jpegSignature)) {
    return length >= 4 && endsWith(const [0xff, 0xd9]);
  }

  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (startsWith(pngSignature)) {
    return length >= 45 &&
        endsWith(const [
          0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44,
          0xae, 0x42, 0x60, 0x82,
        ]);
  }

  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) {
    return length >= 14 && endsWith(const [0x3b]);
  }

  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      prefix.length >= 12 &&
      prefix[8] == 0x57 &&
      prefix[9] == 0x45 &&
      prefix[10] == 0x42 &&
      prefix[11] == 0x50) {
    final declaredLength =
        prefix[4] | (prefix[5] << 8) | (prefix[6] << 16) | (prefix[7] << 24);
    return length >= 16 && declaredLength + 8 <= length;
  }

  if (startsWith(const [0x42, 0x4d]) && prefix.length >= 6) {
    final declaredLength =
        prefix[2] | (prefix[3] << 8) | (prefix[4] << 16) | (prefix[5] << 24);
    return length >= 16 && (declaredLength == 0 || declaredLength <= length);
  }

  if (text.startsWith('<?xml') || text.startsWith('<svg')) {
    final tailText =
        utf8.decode(tail, allowMalformed: true).toLowerCase();
    return tailText.contains('</svg>');
  }

  return true;
}

/// Reads only the beginning and end of a cached image, not the entire file.
Future<bool> isReusableDownloadedImage(File file) async {
  try {
    final length = await file.length();
    if (length < 16) return false;
    final handle = await file.open();
    try {
      final prefix = await handle.read(512);
      await handle.setPosition(length > 32 ? length - 32 : 0);
      final tail = await handle.read(32);
      return isReusableImagePayload(
        length: length,
        prefix: prefix,
        tail: tail,
      );
    } finally {
      await handle.close();
    }
  } catch (_) {
    return false;
  }
}

/// Download an individual file with durable HTTP Range resume support.
///
/// A video is always written to `<target>.part` and renamed only after the
/// stream reaches the expected length. A sidecar stores the URL, validators,
/// and discovered total size. On restart/pause, the client sends Range plus
/// If-Range, validates Content-Range, and never appends bytes from a different
/// representation.
Future<void> _downloadFile(
  String taskId,
  PageUrl pageUrl,
  Client client,
  ItemType itemType,
  SendPort replyPort, {
  int writeMode = 0,
  _Throttle? throttle,
  required String stagingSuffix,
}) async {
  final fileLabel = path.basename(pageUrl.fileName ?? 'download');
  final host = Uri.tryParse(pageUrl.url)?.host ?? 'unknown';
  replyPort.send(
    _DownloadPoolLog(
      taskId,
      'page request started file=$fileLabel host=$host',
      LogLevel.debug,
    ),
  );

  final outputPath = pageUrl.fileName;
  if (outputPath == null || outputPath.trim().isEmpty) {
    throw DownloadPoolException('Download output path is missing');
  }

  try {
    if (itemType != ItemType.anime) {
      const imageTimeout = Duration(seconds: 30);
      final part = File('$outputPath.part.$stagingSuffix');
      final backup = File('$outputPath.backup.$stagingSuffix');
      final out = File(outputPath);
      var movedExistingFile = false;
      var installedNewFile = false;
      try {
        final receivedBytes = await _withRetry<int>(
        () async {
          if (await part.exists()) await part.delete();
          final request = Request('GET', Uri.parse(pageUrl.url));
          request.headers.addAll(pageUrl.headers ?? const {});
          if (!request.headers.keys
              .any((key) => key.toLowerCase() == 'accept-encoding')) {
            request.headers['Accept-Encoding'] = 'identity';
          }
          final response = await client.send(request).timeout(
            imageTimeout,
            onTimeout: () => throw DownloadPoolException(
              'Image timeout after ${imageTimeout.inSeconds}s: ${pageUrl.url}',
            ),
          );
          if (response.statusCode != 200) {
            await response.stream.listen((_) {}).cancel();
            throw DownloadPoolException(
              'Invalid image response for $fileLabel: HTTP ${response.statusCode}',
            );
          }

          final prefix = <int>[];
          final tail = <int>[];
          var received = 0;
          final sink = part.openWrite();
          try {
            await for (final chunk
                in response.stream.timeout(imageTimeout)) {
              if (_isCancelled(taskId)) {
                throw DownloadPoolException(
                  'Task $taskId paused/cancelled',
                  null,
                );
              }
              sink.add(chunk);
              received += chunk.length;
              if (prefix.length < 512) {
                prefix.addAll(chunk.take(512 - prefix.length));
              }
              if (chunk.length >= 32) {
                tail
                  ..clear()
                  ..addAll(chunk.skip(chunk.length - 32));
              } else {
                tail.addAll(chunk);
                if (tail.length > 32) {
                  tail.removeRange(0, tail.length - 32);
                }
              }
            }
            await sink.flush();
          } finally {
            await sink.close();
          }

          final responseError = imageDownloadResponseError(
            statusCode: response.statusCode,
            headers: response.headers,
            bodyBytes: prefix,
            receivedBytes: received,
            expectedBytes: response.contentLength,
            tailBytes: tail,
          );
          if (responseError != null) {
            throw DownloadPoolException(
              'Invalid image response for $fileLabel: $responseError',
            );
          }
          return received;
        },
        3,
      );
        final stagedBytes = await part.length();
        if (stagedBytes != receivedBytes) {
          throw DownloadPoolException(
            'Incomplete staged image: $stagedBytes/$receivedBytes bytes',
          );
        }
        if (_isCancelled(taskId)) {
          throw DownloadPoolException('Task $taskId paused/cancelled', null);
        }
        if (_isCancelled(taskId)) {
          throw DownloadPoolException('Task $taskId paused/cancelled', null);
        }

        // POSIX filesystems atomically replace an existing path here. If the
        // platform refuses to do so, preserve the old file as a backup while
        // installing the verified replacement.
        try {
          await part.rename(outputPath);
          installedNewFile = true;
        } catch (_) {
          if (!await out.exists()) rethrow;
          await out.rename(backup.path);
          movedExistingFile = true;
          try {
            await part.rename(outputPath);
            installedNewFile = true;
          } catch (_) {
            await backup.rename(outputPath);
            movedExistingFile = false;
            rethrow;
          }
        }

        if (movedExistingFile) {
          try {
            if (await backup.exists()) await backup.delete();
          } catch (_) {
            // Keep the newly verified image if backup cleanup fails.
          }
        }
      } catch (_) {
        if (installedNewFile && await out.exists()) await out.delete();
        if (movedExistingFile && await backup.exists()) {
          await backup.rename(outputPath);
        }
        rethrow;
      } finally {
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {
          // Cleanup must not replace the original download error.
        }
      }
    } else {
      await _withRetry(() async {
        final finalPath = outputPath;
        final partFile = File('$finalPath.part');
        final metadataFile = File('$finalPath.part.meta');
        final uri = Uri.parse(pageUrl.url);
        final requestHeaders = <String, String>{
          ...?pageUrl.headers,
          // Do not let transparent gzip change the byte offsets.
          'Accept-Encoding': 'identity',
        };
        final metadata = await _readPartMetadata(metadataFile);
        final metadataUrl = metadata['url'];
        if (metadataUrl is String && metadataUrl != pageUrl.url) {
          if (await partFile.exists()) await partFile.delete();
          if (await metadataFile.exists()) await metadataFile.delete();
          metadata.clear();
        }

        int startFrom = await partFile.exists() ? await partFile.length() : 0;
        final rawKnownTotal = (metadata['totalBytes'] as num?)?.toInt();
        int? knownTotal = trustedDownloadByteCount(rawKnownTotal);

        if (knownTotal == null) {
          // HEAD is not reliable across video CDNs. The fallback range probe
          // also works after a paused download has already created .part.
          knownTotal = await _probeContentLength(client, uri, requestHeaders);
        }

        final request = Request('GET', uri);
        request.headers.addAll(requestHeaders);
        final requestedOffset = startFrom;
        if (requestedOffset > 0) {
          request.headers['Range'] = 'bytes=$requestedOffset-';
          final etag = metadata['etag'];
          final modified = metadata['lastModified'];
          if (etag is String && etag.isNotEmpty) {
            request.headers['If-Range'] = etag;
          } else if (modified is String && modified.isNotEmpty) {
            request.headers['If-Range'] = modified;
          }
        }

        final response = await client.send(request);
        final contentRangeHeader = _responseHeader(response, 'content-range');
        final parsedRange = _parseContentRange(contentRangeHeader);

        if (response.statusCode == 416) {
          // A complete .part can be finalized without downloading again.
          final remoteTotal =
              trustedDownloadByteCount(parsedRange?.total);
          if (requestedOffset > 0 &&
              remoteTotal != null &&
              remoteTotal == requestedOffset) {
            final out = File(finalPath);
            if (await out.exists()) await out.delete();
            await partFile.rename(finalPath);
            if (await metadataFile.exists()) await metadataFile.delete();
            replyPort.send(
              DownloadProgress(
                requestedOffset,
                requestedOffset,
                itemType,
                pageUrl: pageUrl,
                downloadedBytes: requestedOffset,
                totalBytes: requestedOffset,
              ),
            );
            return;
          }
          // The remote representation changed or the local part is invalid.
          // Remove only the partial state; the retry then starts from zero.
          if (await partFile.exists()) await partFile.delete();
          if (await metadataFile.exists()) await metadataFile.delete();
          throw DownloadPoolException(
            'HTTP 416 while resuming ${path.basename(finalPath)}',
          );
        }

        if (response.statusCode != 200 && response.statusCode != 206) {
          throw DownloadPoolException(
            'Failed to download file: $finalPath (HTTP ${response.statusCode})',
          );
        }

        final resumed = response.statusCode == 206;
        if (resumed) {
          // Never append an unverified partial response. This prevents a
          // server/CDN redirect or expired signed URL from corrupting a file.
          if (requestedOffset <= 0 ||
              parsedRange == null ||
              parsedRange.start != requestedOffset) {
            if (await partFile.exists()) await partFile.delete();
            if (await metadataFile.exists()) await metadataFile.delete();
            throw DownloadPoolException(
              'Invalid Content-Range while resuming ${path.basename(finalPath)}',
            );
          }
          startFrom = requestedOffset;
        } else if (requestedOffset > 0) {
          // The server ignored Range (or If-Range failed): overwrite the
          // partial file with the complete 200 representation.
          startFrom = 0;
          if (await partFile.exists()) await partFile.delete();
        }

        final responseLength = response.contentLength;
        final parsedTotal = trustedDownloadByteCount(parsedRange?.total);
        final rangedResponseLength = responseLength == null ||
                responseLength > maxTrustedDownloadBytes -
                    (resumed ? startFrom : 0)
            ? null
            : responseLength + (resumed ? startFrom : 0);
        final responseReportedTotal = parsedTotal ??
            (parsedRange?.total == null
                ? trustedDownloadByteCount(rangedResponseLength)
                : null);
        int? totalBytes = responseReportedTotal;
        totalBytes ??= knownTotal;

        final etag = _responseHeader(response, 'etag');
        final lastModified = _responseHeader(response, 'last-modified');
        await metadataFile.writeAsString(
          jsonEncode(<String, dynamic>{
            'url': pageUrl.url,
            if (totalBytes != null) 'totalBytes': totalBytes,
            if (etag != null && etag.isNotEmpty) 'etag': etag,
            if (lastModified != null && lastModified.isNotEmpty)
              'lastModified': lastModified,
          }),
          flush: true,
        );

        var received = startFrom;
        final sink = partFile.openWrite(
          mode: startFrom > 0 ? FileMode.append : FileMode.write,
        );
        var cancelled = false;
        try {
          await for (final chunk in response.stream) {
            if (_isCancelled(taskId)) {
              cancelled = true;
              break;
            }
            if (throttle != null) await throttle.acquire(chunk.length);
            if (_isCancelled(taskId)) {
              cancelled = true;
              break;
            }
            sink.add(chunk);
            received += chunk.length;
            try {
              replyPort.send(
                DownloadProgress.directFile(
                  downloadedBytes: received,
                  totalBytes: totalBytes,
                  itemType: itemType,
                  pageUrl: pageUrl,
                ),
              );
            } catch (_) {}
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        if (cancelled || _isCancelled(taskId)) {
          throw DownloadPoolException('Task $taskId paused/cancelled', null);
        }

        final written = await partFile.length();
        // Only enforce lengths declared by this GET response. A HEAD/range
        // probe is advisory and can be stale on signed/CDN URLs; treating it
        // as authoritative used to leave valid completed files stuck as
        // "incomplete" forever.
        if (responseReportedTotal != null &&
            written != responseReportedTotal) {
          throw DownloadPoolException(
            'Incomplete download: $written/$responseReportedTotal bytes ($finalPath)',
          );
        }
        if (written == 0) {
          throw DownloadPoolException('Downloaded file is empty: $finalPath');
        }

        final out = File(finalPath);
        if (await out.exists()) await out.delete();
        await partFile.rename(finalPath);
        if (await metadataFile.exists()) await metadataFile.delete();

        // If the server used chunked transfer, completion is the first moment
        // at which the exact final size is knowable. Publish it as real data.
        final finalBytes = await out.length();
        replyPort.send(
          DownloadProgress(
            finalBytes,
            finalBytes,
            itemType,
            pageUrl: pageUrl,
            downloadedBytes: finalBytes,
            totalBytes: finalBytes,
          ),
        );
      }, 3);
    }
    final output = File(outputPath);
    final writtenBytes = await output.length();
    replyPort.send(
      _DownloadPoolLog(
        taskId,
        'page saved file=$fileLabel bytes=$writtenBytes',
        LogLevel.debug,
      ),
    );
  } catch (e) {
    replyPort.send(
      _DownloadPoolLog(
        taskId,
        'page request failed file=$fileLabel host=$host',
        LogLevel.warning,
      ),
    );
    throw DownloadPoolException(
      'Failed to process file: $outputPath',
      e,
    );
  }
}

/// Process an M3U8 download
///
/// Uses a sliding-window (circular slot buffer) identical to
/// [_processFileDownload] so that a stalled segment never holds back the
/// other concurrency slots — as soon as one slot is free the next segment
/// starts immediately.
///
/// Byte-level progress: after each segment is written to disk we read its
/// actual size and accumulate it. HLS playlists do not carry the final MP4
/// size, so this worker intentionally does not manufacture a denominator.
/// The exact total is emitted by the merge step after the final file exists.
@visibleForTesting
DownloadProgress m3u8ProgressForTesting({
  required TsInfo? segment,
  required int completed,
  required int total,
  required ItemType itemType,
  required int downloadedBytes,
}) => DownloadProgress(
  completed,
  total,
  itemType,
  segment: segment,
  downloadedBytes: downloadedBytes,
  totalBytes: null,
);

Future<void> _processM3u8Download(
  String taskId,
  M3u8DownloadParams params,
  SendPort replyPort,
  Client client,
) async {
  int completed = params.initialCompletedSegments;
  final total = params.totalSegments > 0
      ? params.totalSegments
      : params.segments.length + params.initialCompletedSegments;

  if (total == 0) {
    replyPort.send(DownloadComplete());
    return;
  }

  // Byte accumulators — updated by completed segments AND in-flight chunks.
  // completedBytes: sum of all fully-downloaded segment sizes.
  // slotBytes: per-slot running total of in-flight (mid-download) bytes.
  int completedBytes = params.initialDownloadedBytes;
  final slotBytes = List<int>.filled(
    params.concurrentDownloads.clamp(1, 32),
    0,
  );

  // Throttle: only send a real-time progress update when at least this many
  // bytes of new data have arrived since the last send. 256 KB keeps the UI
  // smooth without flooding the main isolate with tiny messages.
  const int kProgressThrottleBytes = 256 * 1024;
  int _lastReportedBytes = 0;

  void _sendProgress(TsInfo? segment) {
    final inFlight = slotBytes.fold<int>(0, (a, b) => a + b);
    final totalDownloaded = completedBytes + inFlight;
    if (totalDownloaded - _lastReportedBytes >= kProgressThrottleBytes ||
        segment != null) {
      _lastReportedBytes = totalDownloaded;
      replyPort.send(
        m3u8ProgressForTesting(
          segment: segment,
          completed: completed,
          total: total,
          itemType: params.itemType,
          downloadedBytes: totalDownloaded,
        ),
      );
    }
  }

  try {
    final throttle = _Throttle(params.speedLimitKBs.toDouble());
    final int concurrency = params.concurrentDownloads.clamp(1, 32);
    final slots = List<Future<void>>.filled(concurrency, Future.value());

    for (int i = 0; i < params.segments.length; i++) {
      if (_isCancelled(taskId)) {
        await Future.wait(slots, eagerError: false).catchError((_) => <void>[]);
        replyPort.send(
          _toSendable(
            DownloadPoolException('M3U8 task $taskId cancelled by user', null),
          ),
        );
        return;
      }

      final slotIdx = i % concurrency;
      await slots[slotIdx];

      // Reset this slot's in-flight counter for the new segment.
      slotBytes[slotIdx] = 0;

      final segment = params.segments[i];
      final capturedSlotIdx = slotIdx;
      slots[slotIdx] =
          _downloadSegment(
                segment,
                params,
                client,
                throttle: throttle,
                onChunk: (bytes) {
                  slotBytes[capturedSlotIdx] += bytes;
                  _sendProgress(null); // throttled real-time update
                },
              )
              .then((_) {
                completed++;

                // Commit this slot's bytes to the completed accumulator.
                try {
                  final tsFile = File(
                    path.join(params.tempDir, '${segment.name}.ts'),
                  );
                  if (tsFile.existsSync()) {
                    completedBytes += tsFile.lengthSync();
                  } else {
                    completedBytes += slotBytes[capturedSlotIdx];
                  }
                } catch (_) {
                  completedBytes += slotBytes[capturedSlotIdx];
                }
                slotBytes[capturedSlotIdx] = 0;

                // Always send an update on segment completion (threshold bypassed).
                _lastReportedBytes = 0;
                _sendProgress(segment);
              })
              .catchError((error) {
                replyPort.send(
                  _toSendable(
                    DownloadPoolException(
                      'Error downloading segment ${segment.name}',
                      error,
                    ),
                  ),
                );
                throw error;
              });
    }

    // Drain remaining in-flight slots.
    await Future.wait(slots, eagerError: true);

    if (_isCancelled(taskId)) {
      replyPort.send(
        _toSendable(
          DownloadPoolException('M3U8 task $taskId cancelled by user', null),
        ),
      );
      return;
    }

    replyPort.send(DownloadComplete());
  } catch (e) {
    replyPort.send(
      _toSendable(DownloadPoolException('M3U8 download failed', e)),
    );
  }
}

/// Download a TS segment.
///
/// The retry wrapper is placed *around the whole operation* (connection +
/// stream read + file write) so that errors thrown mid-stream — e.g. the
/// `AnyhowException` rhttp surfaces when the CDN closes the connection
/// after a few hundred KB — actually trigger a retry. Previously only
/// `client.send()` (the headers handshake) was retried, so any failure
/// after that point would kill the whole HLS download with a misleading
/// "Failed to process segment" error and leave 5 other in-flight segments
/// orphaned.
///
/// A per-segment timeout of 45 seconds prevents the downloader from
/// hanging silently when a CDN stalls mid-stream (the "stuck at 0%"
/// symptom seen with Hydra on some providers).
Future<void> _downloadSegment(
  TsInfo ts,
  M3u8DownloadParams params,
  Client client, {
  void Function(int bytes)? onChunk,
  _Throttle? throttle,
}) async {
  const segmentTimeout = Duration(seconds: 45);
  final file = File(path.join(params.tempDir, '${ts.name}.ts'));
  final partFile = File('${file.path}.part');
  final doneFile = File('${file.path}.done');
  final decryptFile = File('${file.path}.decrypt.part');

  try {
    await _withRetry(() async {
      // A segment is committed in three steps:
      //   1. stream into .part,
      //   2. verify it is non-empty and atomically rename it to .ts,
      //   3. create .done only after the final file is durable.
      // This prevents an interrupted stream from becoming a valid-looking
      // zero-byte segment that later gets merged into an unreadable video.
      for (final stale in [partFile, decryptFile, file, doneFile]) {
        if (await stale.exists()) {
          try {
            await stale.delete();
          } catch (_) {}
        }
      }

      // Streaming keeps memory low even for 4K segments.
      final request = Request('GET', Uri.parse(ts.url));
      if (params.headers != null) {
        request.headers.addAll(params.headers!);
      }

      // Wrap the entire send+stream in a timeout so a stalled CDN
      // does not block the isolate indefinitely.
      final response = await client
          .send(request)
          .timeout(
            segmentTimeout,
            onTimeout: () => throw DownloadPoolException(
              'Segment ${ts.name}: connection timeout after ${segmentTimeout.inSeconds}s',
            ),
          );

      if (response.statusCode != 200) {
        throw DownloadPoolException(
          'Failed to download segment: ${ts.name} (HTTP ${response.statusCode})',
        );
      }

      final sink = partFile.openWrite();
      try {
        // Per-chunk inactivity watchdog — if no bytes arrive for
        // segmentTimeout the stream is considered stalled.
        await for (final chunk in response.stream.timeout(
          segmentTimeout,
          onTimeout: (_) {
            throw DownloadPoolException(
              'Segment ${ts.name}: stream stalled for ${segmentTimeout.inSeconds}s',
            );
          },
        )) {
          if (throttle != null) await throttle.acquire(chunk.length);
          sink.add(chunk);
          onChunk?.call(chunk.length);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final partLength = await partFile.length();
      if (partLength <= 0) {
        throw DownloadPoolException(
          'Segment ${ts.name}: server returned an empty body',
        );
      }

      await partFile.rename(file.path);
    }, 5);

    // Decrypt if necessary (outside the retry: a successful download
    // followed by an AES failure is not transient and shouldn't be
    // re-downloaded).
    if (params.key != null && !ts.isInitialization) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw DownloadPoolException(
          'Segment ${ts.name}: downloaded file is empty before decrypt',
        );
      }
      final index = int.parse(ts.name.substringAfter("TS_"));
      final decrypted = _aesDecrypt(
        (params.mediaSequence ?? 1) + (index - 1),
        bytes,
        params.key!,
        iv: params.iv,
      );
      if (decrypted.isEmpty) {
        throw DownloadPoolException(
          'Segment ${ts.name}: decryption produced an empty file',
        );
      }
      await decryptFile.writeAsBytes(decrypted, flush: true);
      await file.delete();
      await decryptFile.rename(file.path);
    }

    if (await file.length() <= 0) {
      throw DownloadPoolException(
        'Segment ${ts.name}: final file is empty',
      );
    }

    // The marker is deleted together with the temp directory after merging.
    await doneFile.writeAsBytes(const [], flush: true);
  } catch (e) {
    for (final stale in [partFile, decryptFile, doneFile]) {
      try {
        if (await stale.exists()) await stale.delete();
      } catch (_) {}
    }
    throw DownloadPoolException('Failed to process segment: ${ts.name}', e);
  }
}

/// AES decryption
Uint8List _aesDecrypt(
  int sequence,
  Uint8List encrypted,
  Uint8List key, {
  Uint8List? iv,
}) {
  try {
    if (iv == null) {
      iv = Uint8List(16);
      ByteData.view(iv.buffer).setUint64(8, sequence);
    }
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(encrypt.Encrypted(encrypted), iv: encrypt.IV(iv)),
    );
  } catch (e) {
    throw DownloadPoolException('Decryption failed', e);
  }
}

/// Helper for retry. Now uses bounded exponential backoff (200ms, 500ms,
/// 1000ms…) so transient network blips don't immediately fail a download
/// and so we don't hot-loop and burn CPU when a server is briefly unhappy.
Future<T> _withRetry<T>(Future<T> Function() operation, int maxRetries) async {
  int attempts = 0;
  Object? lastError;
  while (attempts < maxRetries) {
    attempts++;
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      if (attempts >= maxRetries) break;
      final backoffMs = 200 * (1 << (attempts - 1)); // 200, 400, 800, …
      await Future.delayed(Duration(milliseconds: backoffMs.clamp(200, 2000)));
    }
  }
  throw DownloadPoolException(
    'Operation failed after $maxRetries attempts',
    lastError,
  );
}

/// Pool exception
class DownloadPoolException implements Exception {
  final String message;
  final dynamic originalError;

  DownloadPoolException(this.message, [this.originalError]);

  @override
  String toString() =>
      'DownloadPoolException: $message${originalError != null ? ' ($originalError)' : ''}';
}
