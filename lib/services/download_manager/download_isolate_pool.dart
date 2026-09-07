import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;
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
    int writeMode = 0,
    int speedLimitKBs = 0,
    required void Function(DownloadProgress) onProgress,
    required FutureOr<void> Function() onComplete,
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
        Duration(milliseconds: (deficit / bytesPerSec * 1000).ceil()));
  }
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
    final throttle = _Throttle(params.speedLimitKBs.toDouble());
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
      slots[slotIdx] = _downloadFile(taskId, pageUrl, client, params.itemType, replyPort,
              writeMode: params.writeMode, throttle: throttle)
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
  final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(value.trim());
  if (match == null) return null;
  return _ParsedContentRange(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    match.group(3) == '*' ? null : int.parse(match.group(3)!),
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
    final request = Request('HEAD', uri);
    request.headers.addAll(headers);
    final response = await client.send(request).timeout(const Duration(seconds: 15));
    final length = response.contentLength;
    await response.stream.drain();
    return length != null && length > 0 ? length : null;
  } catch (_) {
    // HEAD is optional. The real GET below may still provide Content-Range.
    return null;
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
}) async {
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
      final bytes = response.bodyBytes;
      final finalPath = pageUrl.fileName!;
      if (writeMode == 0 && bytes.isNotEmpty) {
        final part = File('$finalPath.part');
        await part.writeAsBytes(bytes, flush: true);
        final out = File(finalPath);
        if (await out.exists()) await out.delete();
        await part.rename(finalPath);
      } else {
        await File(finalPath).writeAsBytes(bytes, flush: true);
      }
      if (kDebugMode) {
        debugPrint('[DLPool] ${path.basename(finalPath)} ok (${bytes.length}B)');
      }
    } else {
      await _withRetry(() async {
        final finalPath = pageUrl.fileName!;
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
        int? knownTotal = (metadata['totalBytes'] as num?)?.toInt();
        if (knownTotal != null && knownTotal <= 0) knownTotal = null;

        if (startFrom == 0 && knownTotal == null) {
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
          final remoteTotal = parsedRange?.total;
          if (requestedOffset > 0 &&
              remoteTotal != null &&
              remoteTotal == requestedOffset) {
            final out = File(finalPath);
            if (await out.exists()) await out.delete();
            await partFile.rename(finalPath);
            if (await metadataFile.exists()) await metadataFile.delete();
            replyPort.send(DownloadProgress(
              requestedOffset,
              requestedOffset,
              itemType,
              pageUrl: pageUrl,
              downloadedBytes: requestedOffset,
              totalBytes: requestedOffset,
            ));
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
          if (requestedOffset <= 0 || parsedRange == null ||
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
        int? totalBytes = parsedRange?.total;
        if (totalBytes == null && responseLength != null && responseLength > 0) {
          totalBytes = responseLength + (resumed ? startFrom : 0);
        }
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
              replyPort.send(DownloadProgress(
                received,
                totalBytes ?? received,
                itemType,
                pageUrl: pageUrl,
                downloadedBytes: received,
                totalBytes: totalBytes,
              ));
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
        if (totalBytes != null && written != totalBytes) {
          throw DownloadPoolException(
            'Incomplete download: $written/$totalBytes bytes ($finalPath)',
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
        replyPort.send(DownloadProgress(
          finalBytes,
          finalBytes,
          itemType,
          pageUrl: pageUrl,
          downloadedBytes: finalBytes,
          totalBytes: finalBytes,
        ));
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
}) =>
    DownloadProgress(
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
  int completed = 0;
  final total = params.segments.length;

  if (total == 0) {
    replyPort.send(DownloadComplete());
    return;
  }

  // Byte accumulators — updated by completed segments AND in-flight chunks.
  // completedBytes: sum of all fully-downloaded segment sizes.
  // slotBytes: per-slot running total of in-flight (mid-download) bytes.
  int completedBytes = 0;
  final slotBytes = List<int>.filled(params.concurrentDownloads.clamp(1, 32), 0);

  // Throttle: only send a real-time progress update when at least this many
  // bytes of new data have arrived since the last send. 256 KB keeps the UI
  // smooth without flooding the main isolate with tiny messages.
  const int kProgressThrottleBytes = 256 * 1024;
  int _lastReportedBytes = 0;

  void _sendProgress(TsInfo? segment) {
    final inFlight = slotBytes.fold<int>(0, (a, b) => a + b);
    final totalDownloaded = completedBytes + inFlight;
    if (totalDownloaded - _lastReportedBytes >= kProgressThrottleBytes || segment != null) {
      _lastReportedBytes = totalDownloaded;
      replyPort.send(m3u8ProgressForTesting(
        segment: segment,
        completed: completed,
        total: total,
        itemType: params.itemType,
        downloadedBytes: totalDownloaded,
      ));
    }
  }

  try {
    final throttle = _Throttle(params.speedLimitKBs.toDouble());
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

      // Reset this slot's in-flight counter for the new segment.
      slotBytes[slotIdx] = 0;

      final segment = params.segments[i];
      final capturedSlotIdx = slotIdx;
      slots[slotIdx] = _downloadSegment(
        segment, params, client,
        throttle: throttle,
        onChunk: (bytes) {
          slotBytes[capturedSlotIdx] += bytes;
          _sendProgress(null); // throttled real-time update
        },
      ).then((_) {
            completed++;

            // Commit this slot's bytes to the completed accumulator.
            try {
              final tsFile = File(path.join(params.tempDir, '${segment.name}.ts'));
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
  Client client, {
  void Function(int bytes)? onChunk,
  _Throttle? throttle,
}) async {
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
        await for (final chunk
            in response.stream.timeout(segmentTimeout, onTimeout: (_) {
          throw DownloadPoolException(
            'Segment ${ts.name}: stream stalled for ${segmentTimeout.inSeconds}s',
          );
        })) {
          if (throttle != null) await throttle.acquire(chunk.length);
          sink.add(chunk);
          onChunk?.call(chunk.length);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }, 5);

    // Decrypt if necessary (outside the retry: a successful download
    // followed by an AES failure is not transient and shouldn't be
    // re-downloaded).
    if (params.key != null && !ts.isInitialization) {
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
