import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';

/// Global registry that maps a download ID (chapter.id) to its active engine.
///
/// - ZeusDL downloads register a [DownloadEngine] instance.
/// - Internal HLS / file downloads register the task ID string so the isolate
///   pool can be cancelled on pause.
///
/// Use this from [DownloadQueueState.togglePause] to actually pause/resume
/// running downloads, not just update the UI flag.
class ActiveDownloadRegistry {
  ActiveDownloadRegistry._();

  // ZeusDL and other engines that implement DownloadEngine
  static final _engines = <int, DownloadEngine>{};

  // Internal pool task IDs for M3u8Downloader / MDownloader
  static final _internalTaskIds = <int, String>{};

  // ── Registration ──────────────────────────────────────────────────────────

  static void registerEngine(int downloadId, DownloadEngine engine) {
    _engines[downloadId] = engine;
    _internalTaskIds.remove(downloadId);
  }

  static void registerInternal(int downloadId, String taskId) {
    _internalTaskIds[downloadId] = taskId;
    _engines.remove(downloadId);
  }

  static void unregister(int downloadId) {
    _engines.remove(downloadId);
    _internalTaskIds.remove(downloadId);
  }

  // ── Control ───────────────────────────────────────────────────────────────

  /// Pause the download.  For ZeusDL: SIGSTOP.  For internal: cancel current
  /// batch (files already on disk are preserved; re-queuing restarts cleanly).
  static Future<void> pause(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.pause();
    } else if (_internalTaskIds.containsKey(downloadId)) {
      final taskId = _internalTaskIds[downloadId]!;
      // Cancel isolate pool task — the download loop exits gracefully.
      // The Isar record keeps isStartDownload=true so processDownloads can
      // re-pick it when resumed.
      DownloadIsolatePool.instance.cancelTask(taskId);
      DownloadIsolatePool.instance.cancelTask('m3u8_$taskId');
    }
  }

  /// Resume a paused download.  For ZeusDL: SIGCONT.  For internal: the
  /// caller (UI) should re-invoke processDownloads after removing from
  /// pausedIds, which will restart the download from where it left off.
  static Future<void> resume(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.resume();
    }
    // Internal resume is handled externally by re-triggering processDownloads.
  }

  /// Cancel and remove the download from the registry.
  static Future<void> cancel(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.cancel();
    } else if (_internalTaskIds.containsKey(downloadId)) {
      final taskId = _internalTaskIds[downloadId]!;
      DownloadIsolatePool.instance.cancelTask(taskId);
      DownloadIsolatePool.instance.cancelTask('m3u8_$taskId');
    }
    unregister(downloadId);
  }

  /// Whether a download is currently tracked (i.e. actively running).
  static bool isActive(int downloadId) =>
      _engines.containsKey(downloadId) ||
      _internalTaskIds.containsKey(downloadId);
}
