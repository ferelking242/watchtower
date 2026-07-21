import 'dart:collection';
import 'dart:isolate';
import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/http/rhttp/src/model/settings.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/m3u8/models/ts_info.dart';
import 'package:watchtower/src/rust/frb_generated.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
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
        if (kDebugMode) print('[DownloadPool] Cannot reconfigure after initialization');
      }
      return;
    }
    _instance = DownloadIsolatePool._(poolSize: poolSize);
  }

  /// Initialize the Isolate pool
  Future<void> initialize() async {
    if (_initialized) return;

    if (kDebugMode) {
      if (kDebugMode) print('[DownloadPool] Initializing with $poolSize workers...');
    }

    for (int i = 0; i < poolSize; i++) {
      final worker = await _PoolWorker.create(i);
      _workers.add(worker);
      _availableWorkers.add(i); // All workers start as available
    }

    _initialized = true;
    if (kDebugMode) {
      if (kDebugMode) print('[DownloadPool] Pool initialized with $poolSize workers');
    }
  }

  /// Submit a file download task (manga/anime)
  Future<void> submitFileDownload({
    required String taskId,
    required List<PageUrl> pageUrls,
    required int concurrentDownloads,
    required ItemType itemType,
    required void Function(DownloadProgress) onProgress,
    required void Function() onComplete,
    required void Function(Exception) onError,
    void Function()? onCancelled,
  }) async {
    if (!_initialized) await initialize();

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
          onComplete();
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
    required int concurrentDownloads,
    required Map<String, String>? headers,
    required ItemType itemType,
    required void Function(DownloadProgress) onProgress,
    required void Function() onComplete,
    required void Function(Exception) onError,
    void Function()? onCancelled,
  }) async {
    if (!_initialized) await initialize();

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
        concurrentDownloads: concurrentDownloads,
        headers: headers,
        itemType: itemType,
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
          onComplete();
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
    _processQueue();
  }

  /// Process the task queue
  void _processQueue() {
    while (_taskQueue.isNotEmpty && _availableWorkers.isNotEmpty) {
      final task = _taskQueue.removeFirst();
      final workerIndex = _availableWorkers.first;
      _availableWorkers.remove(workerIndex);
      final worker = _workers[workerIndex];

      if (kDebugMode) {
        if (kDebugMode) print(
          '[DownloadPool] Worker $workerIndex starting task ${task.taskId}',
        );
      }

      worker.executeTask(task).then((_) {
        _availableWorkers.add(workerIndex); // Worker is free again
        if (kDebugMode) {
          if (kDebugMode) print(
            '[DownloadPool] Worker $workerIndex finished task ${task.taskId}, available workers: ${_availableWorkers.length}',
          );
        }
        _processQueue(); // Process the next task
      });
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

/// Parameters for file download
class FileDownloadParams {
  final List<PageUrl> pageUrls;
  final int concurrentDownloads;
  final ItemType itemType;

  FileDownloadParams({
    required this.pageUrls,
    required this.concurrentDownloads,
    required this.itemType,
  });
}

/// Parameters for M3U8 download
class M3u8DownloadParams {
  final List<TsInfo> segments;
  final String tempDir;
  final Uint8List? key;
  final Uint8List? iv;
  final int? mediaSequence;
  final int concurrentDownloads;
  final Map<String, String>? headers;
  final ItemType itemType;

  M3u8DownloadParams({
    required this.segments,
    required this.tempDir,
    required this.key,
    required this.iv,
    required this.mediaSequence,
    required this.concurrentDownloads,
    required this.headers,
    required this.itemType,
  });
}

/// Pool worker that executes tasks in a persistent Isolate
class _PoolWorker {
  final int id;
  late Isolate _isolate;
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

    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _WorkerInit(id, _receivePort.sendPort),
    );

    // The worker first sends back its task SendPort, then its cancel
    // SendPort. We complete the ready future once both are received.
    final taskPortCompleter = Completer<SendPort>();
    final cancelPortCompleter = Completer<SendPort>();
    _receivePort.listen((message) {
      if (message is _WorkerHandshake) {
        if (!taskPortCompleter.isCompleted) {
          taskPortCompleter.complete(message.taskPort);
        }
        if (!cancelPortCompleter.isCompleted) {
          cancelPortCompleter.complete(message.cancelPort);
        }
      } else if (message is SendPort && !taskPortCompleter.isCompleted) {
        // Backwards-compatible path (old worker entry point sent a bare
        // SendPort). Should not be hit but keeps things robust.
        taskPortCompleter.complete(message);
      }
    });

    _sendPort = await taskPortCompleter.future;
    _cancelPort = await cancelPortCompleter.future;
    _ready.complete();
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
    _isolate.kill();
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
        message.replyPort.send(_toSendable(DownloadPoolException('Task failed', e)));
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

  if (total == 0) {
    replyPort.send(DownloadComplete());
    return;
  }

  try {
    final int concurrency = params.concurrentDownloads.clamp(1, 32);
    // Circular slot buffer: slot i is awaited before launching item i,
    // guaranteeing at most `concurrency` downloads in flight at once.
    final slots = List<Future<void>>.filled(concurrency, Future.value());

    for (int i = 0; i < params.pageUrls.length; i++) {
      if (_isCancelled(taskId)) {
        await Future.wait(slots, eagerError: false).catchError((_) => <void>[]);
        replyPort.send(_toSendable(DownloadPoolException(
          'Task $taskId cancelled by user', null)));
        return;
      }

      final slotIdx = i % concurrency;
      await slots[slotIdx];

      final pageUrl = params.pageUrls[i];
      slots[slotIdx] = _downloadFile(pageUrl, client, params.itemType, replyPort)
          .then((_) {
            if (params.itemType != ItemType.anime) {
              completed++;
              replyPort.send(DownloadProgress(
                pageUrl: pageUrl, completed, total, params.itemType));
            }
          })
          .catchError((error) {
            replyPort.send(_toSendable(DownloadPoolException(
              'Error downloading ${pageUrl.fileName}', error)));
            throw error;
          });
    }

    // Drain all remaining in-flight slots.
    await Future.wait(slots, eagerError: true);

    if (_isCancelled(taskId)) {
      replyPort.send(_toSendable(DownloadPoolException(
        'Task $taskId cancelled by user', null)));
      return;
    }

    replyPort.send(DownloadComplete());
  } catch (e) {
    replyPort.send(_toSendable(DownloadPoolException('Download failed', e)));
  }
}

/// Download an individual file
Future<void> _downloadFile(
  PageUrl pageUrl,
  Client client,
  ItemType itemType,
  SendPort replyPort,
) async {
  try {
    if (itemType != ItemType.anime) {
        const imageTimeout = Duration(seconds: 30);
        final response = await _withRetry(
          () => client
              .get(Uri.parse(pageUrl.url), headers: pageUrl.headers)
              .timeout(
                imageTimeout,
                onTimeout: () => throw DownloadPoolException(
                  'Image timeout after ${imageTimeout.inSeconds}s: ${pageUrl.url}',
                ),
              ),
          3,
        );
        if (response.statusCode != 200) {
          throw DownloadPoolException(
            'HTTP ${response.statusCode} for ${pageUrl.url}',
          );
        }
        final file = File(pageUrl.fileName!);
        await file.writeAsBytes(response.bodyBytes);
        if (kDebugMode) {
          debugPrint('[DLPool] ${path.basename(pageUrl.fileName!)} ok (${response.bodyBytes.length}B)');
        }
      } else {
      // Streaming for videos — reports real byte progress ("14 MB / 58 MB").
      await _withRetry(() async {
        var request = Request('GET', Uri.parse(pageUrl.url));
        request.headers.addAll(pageUrl.headers ?? {});
        StreamedResponse response = await client.send(request);
        if (response.statusCode != 200) {
          throw DownloadPoolException(
            'Failed to download file: ${pageUrl.fileName!}',
          );
        }
        // Content-Length may be absent (chunked transfer). When present it
        // drives the "X MB / Y MB" label; when absent we still show bytes
        // received as "X MB" with no denominator.
        final int contentLength = response.contentLength ?? 0;
        int received = 0;

        final file = File(pageUrl.fileName!);
        final sink = file.openWrite();
        try {
          await for (var chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            try {
              replyPort.send(
                DownloadProgress(
                  received,
                  contentLength > 0 ? contentLength : received,
                  itemType,
                  pageUrl: pageUrl,
                  downloadedBytes: received,
                  totalBytes: contentLength > 0 ? contentLength : null,
                ),
              );
            } catch (_) {}
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      }, 3);
    }
  } catch (e) {
    throw DownloadPoolException(
      'Failed to process file: ${pageUrl.fileName!}',
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
/// actual size and accumulate it. The first batch of segments also seeds a
/// per-segment average that lets us estimate the remaining total — giving
/// the UI a "14 MB / 58 MB" label instead of a raw count or percentage.
Future<void> _processM3u8Download(
  String taskId,
  M3u8DownloadParams params,
  SendPort replyPort,
  Client client,
) async {
  int completed = 0;
  final total = params.segments.length;

  if (total == 0) {
    replyPort.send(DownloadComplete());
    return;
  }

  // Byte accumulators — updated after each segment lands.
  int downloadedBytes = 0;
  // Once we have sampled enough segments we lock the total estimate so it
  // does not jump around as the running average fluctuates.  The estimate
  // is frozen after kLockAfterSegments completed segments, whichever comes
  // first.  After locking, only downloadedBytes grows; the UI shows smooth
  // "14 MB / 58 MB" progress without the total jumping.
  int estimatedTotalBytes = 0;
  bool _totalLocked = false;
  // Number of segments after which the estimate is considered stable.
  const int kLockAfterSegments = 8;

  try {
    final int concurrency = params.concurrentDownloads.clamp(1, 32);
    final slots = List<Future<void>>.filled(concurrency, Future.value());

    for (int i = 0; i < params.segments.length; i++) {
      if (_isCancelled(taskId)) {
        await Future.wait(slots, eagerError: false).catchError((_) => <void>[]);
        replyPort.send(_toSendable(DownloadPoolException(
          'M3U8 task $taskId cancelled by user', null)));
        return;
      }

      final slotIdx = i % concurrency;
      await slots[slotIdx];

      final segment = params.segments[i];
      slots[slotIdx] = _downloadSegment(segment, params, client)
          .then((_) {
            completed++;

            // Read size of the written .ts file for byte-accurate progress.
            try {
              final tsFile = File(path.join(params.tempDir, '${segment.name}.ts'));
              if (tsFile.existsSync()) {
                downloadedBytes += tsFile.lengthSync();
              }
            } catch (_) {}

            // Estimate total only while we do not yet have a stable reading.
            // Once kLockAfterSegments segments have landed, lock the estimate
            // so the total does not keep jumping as different-sized segments
            // change the running average.
            if (!_totalLocked && completed > 0) {
              final avgBytesPerSegment = downloadedBytes ~/ completed;
              estimatedTotalBytes = avgBytesPerSegment * total;
              if (completed >= kLockAfterSegments) {
                _totalLocked = true;
              }
            }

            replyPort.send(DownloadProgress(
              segment: segment,
              completed,
              total,
              params.itemType,
              downloadedBytes: downloadedBytes,
              totalBytes: estimatedTotalBytes > 0 ? estimatedTotalBytes : null,
            ));
          })
          .catchError((error) {
            replyPort.send(_toSendable(DownloadPoolException(
              'Error downloading segment ${segment.name}', error)));
            throw error;
          });
    }

    // Drain remaining in-flight slots.
    await Future.wait(slots, eagerError: true);

    if (_isCancelled(taskId)) {
      replyPort.send(_toSendable(DownloadPoolException(
        'M3U8 task $taskId cancelled by user', null)));
      return;
    }

    replyPort.send(DownloadComplete());
  } catch (e) {
    replyPort.send(_toSendable(DownloadPoolException('M3U8 download failed', e)));
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
  Client client,
) async {
  const segmentTimeout = Duration(seconds: 45);
  final file = File(path.join(params.tempDir, '${ts.name}.ts'));

  try {
    await _withRetry(() async {
      // Make sure each retry starts from a clean .ts file — otherwise a
      // partially-written segment from a failed attempt would be appended
      // to and produce a corrupted .mp4 after merge.
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      // Streaming keeps memory low even for 4K segments.
      final request = Request('GET', Uri.parse(ts.url));
      if (params.headers != null) {
        request.headers.addAll(params.headers!);
      }

      // Wrap the entire send+stream in a timeout so a stalled CDN
      // does not block the isolate indefinitely.
      final response = await client.send(request).timeout(
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

      final sink = file.openWrite();
      try {
        // Per-chunk inactivity watchdog — if no bytes arrive for
        // segmentTimeout the stream is considered stalled.
        await response.stream
            .timeout(
              segmentTimeout,
              onTimeout: (_) => throw DownloadPoolException(
                'Segment ${ts.name}: stream stalled for ${segmentTimeout.inSeconds}s',
              ),
            )
            .forEach(sink.add);
      } finally {
        await sink.flush();
        await sink.close();
      }
    }, 5);

    // Decrypt if necessary (outside the retry: a successful download
    // followed by an AES failure is not transient and shouldn't be
    // re-downloaded).
    if (params.key != null) {
      final bytes = await file.readAsBytes();
      final index = int.parse(ts.name.substringAfter("TS_"));
      final decrypted = _aesDecrypt(
        (params.mediaSequence ?? 1) + (index - 1),
        bytes,
        params.key!,
        iv: params.iv,
      );
      await file.writeAsBytes(decrypted);
    }

    // Write a zero-byte marker so _filterExistingSegments can distinguish
    // a fully-written segment from a partially-written one left by an
    // interrupted download. The marker is deleted together with the temp
    // directory after merging.
    await File('${file.path}.done').writeAsBytes(const []);
  } catch (e) {
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
