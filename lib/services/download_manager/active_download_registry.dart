import 'package:watchtower/models/manga.dart';
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

  // Per-engine metadata — mirrors what _internalItemType/_internalSource do
  // for pool tasks.  We keep them separate so the two paths stay independent.
  static final _engineItemType = <int, ItemType>{};
  static final _engineSource = <int, String>{};

  // Internal pool task IDs for M3u8Downloader / MDownloader
  static final _internalTaskIds = <int, String>{};

  // Per-download metadata for counting
  static final _internalItemType = <int, ItemType>{};
  static final _internalSource = <int, String>{};

  // ── Registration ──────────────────────────────────────────────────────────

  /// Register an external engine (e.g. Aria2) for [downloadId].
  ///
  /// [itemType] and [source] are required for accurate limit counting via
  /// [activeCountForType] and [activeCountForSource].  Without them the
  /// scheduler cannot enforce per-source caps for engine-backed downloads.
  static void registerEngine(
    int downloadId,
    DownloadEngine engine, {
    ItemType itemType = ItemType.anime,
    String source = '_unknown',
  }) {
    _engines[downloadId] = engine;
    _engineItemType[downloadId] = itemType;
    _engineSource[downloadId] = source;
    // Remove any stale internal-pool entry for the same ID
    _internalTaskIds.remove(downloadId);
    _internalItemType.remove(downloadId);
    _internalSource.remove(downloadId);
  }

  static void registerInternal(
    int downloadId,
    String taskId, {
    ItemType? itemType,
    String? source,
  }) {
    _internalTaskIds[downloadId] = taskId;
    _internalItemType[downloadId] = itemType ?? ItemType.manga;
    _internalSource[downloadId] = source ?? '_unknown';
    // Remove any stale engine entry for the same ID
    _engines.remove(downloadId);
    _engineItemType.remove(downloadId);
    _engineSource.remove(downloadId);
  }

  static void unregister(int downloadId) {
    _engines.remove(downloadId);
    _engineItemType.remove(downloadId);
    _engineSource.remove(downloadId);
    _internalTaskIds.remove(downloadId);
    _internalItemType.remove(downloadId);
    _internalSource.remove(downloadId);
  }

  // ── Counting ──────────────────────────────────────────────────────────────

  /// True when at least one download is actively running.
  static bool get hasActive =>
      _engines.isNotEmpty || _internalTaskIds.isNotEmpty;

  /// Number of active downloads (pool tasks + engines) for a given [ItemType].
  static int activeCountForType(ItemType type) {
    int count = 0;
    // Internal pool tasks
    for (final id in _internalTaskIds.keys) {
      if (_internalItemType[id] == type) count++;
    }
    // External engines — use the metadata stored at registerEngine time
    for (final id in _engines.keys) {
      if (_engineItemType[id] == type) count++;
    }
    return count;
  }

  /// Number of active downloads for a given [ItemType] + source combination.
  ///
  /// Includes both pool tasks (internal) and engine-backed (external) downloads
  /// so the per-source cap is enforced uniformly regardless of download engine.
  static int activeCountForSource(ItemType type, String source) {
    int count = 0;
    // Internal pool tasks
    for (final id in _internalTaskIds.keys) {
      if (_internalItemType[id] == type && _internalSource[id] == source) {
        count++;
      }
    }
    // External engines
    for (final id in _engines.keys) {
      if (_engineItemType[id] == type && _engineSource[id] == source) {
        count++;
      }
    }
    return count;
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
      // Cancel exactly the task that was registered — no guessing about
      // 'm3u8_' prefixes.  The caller always stores the actual pool task ID.
      final taskId = _internalTaskIds[downloadId]!;
      DownloadIsolatePool.instance.cancelTask(taskId);
      // Drop the entry so the scheduler considers this chapter idle on
      // resume and re-enqueues it via processDownloads. Already-downloaded
      // segments stay on disk and are skipped on the next attempt.
      _internalTaskIds.remove(downloadId);
      _internalItemType.remove(downloadId);
      _internalSource.remove(downloadId);
    }
  }

  /// Resume a paused download.
  ///
  /// * External engine: engine.resume() is called.
  /// * Internal: the re-query loop in processDownloads automatically picks
  ///   up the chapter on the next tick once it's no longer in pausedIds.
  static Future<void> resume(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.resume();
    }
    // Internal resume is handled automatically by processDownloads re-querying
    // Isar on each tick.
  }

  /// Cancel and remove the download from the registry.
  static Future<void> cancel(int downloadId) async {
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.cancel();
    } else if (_internalTaskIds.containsKey(downloadId)) {
      // Cancel exactly the registered task ID — no hardcoded prefix guessing.
      final taskId = _internalTaskIds[downloadId]!;
      DownloadIsolatePool.instance.cancelTask(taskId);
    }
    unregister(downloadId);
  }

  /// Whether a download is currently tracked (i.e. actively running).
  static bool isActive(int downloadId) =>
      _engines.containsKey(downloadId) ||
      _internalTaskIds.containsKey(downloadId);
}
