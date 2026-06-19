import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';

/// Global registry that maps a download ID (chapter.id) to its active engine.
///
/// - External engine downloads (Aria2, etc.) register a [DownloadEngine] instance.
/// - Internal HLS / file downloads register the task ID string so the isolate
///   pool can be cancelled on pause.
///
/// Use this from [DownloadQueueState.togglePause] to actually pause/resume
/// running downloads, not just update the UI flag.
class ActiveDownloadRegistry {
  ActiveDownloadRegistry._();

  // External engines that implement DownloadEngine (e.g. Aria2)
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

  /// Pause the download.
  ///
  /// * External engine (e.g. Aria2): engine.pause() is called.
  /// * Internal (HLS/manga pool): cancel the current isolate task AND
  ///   unregister the chapter so [processDownloads] can re-pick it on
  ///   resume. Without unregistering, the chapter would still appear
  ///   "active" to the scheduler and resume would silently do nothing.
  static Future<void> pause(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.pause();
      return;
    }
    if (_internalTaskIds.containsKey(downloadId)) {
      final taskId = _internalTaskIds[downloadId]!;
      // Cancel both the bare and m3u8-prefixed variants — historically
      // both shapes have been registered depending on the call site.
      DownloadIsolatePool.instance.cancelTask(taskId);
      DownloadIsolatePool.instance.cancelTask('m3u8_$taskId');
      // Drop the entry so the scheduler considers this chapter idle on
      // resume and re-enqueues it via processDownloads. Already-downloaded
      // segments stay on disk and are skipped on the next attempt.
      _internalTaskIds.remove(downloadId);
    }
  }

  /// Resume a paused download.
  ///
  /// * External engine: engine.resume() is called.
  /// * Internal: the caller (UI) should re-invoke processDownloads after
  ///   removing the chapter from pausedIds. Because [pause] unregistered
  ///   the chapter, the scheduler will see it as idle and start a fresh
  ///   download which skips any files already on disk.
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
