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
  static final _interruptedIds = <int>{};

  // Insertion-ordered active download IDs, so preemption can keep the
  // downloads that started first and stop the newest ones.
  static final _activeOrder = <int>{};

  // IDs stopped because a lowered simultaneous-download limit preempted them.
  // Unlike [_interruptedIds] (cleared when the worker unregisters), this flag
  // survives the worker's own teardown so its failure path can tell a
  // deliberate preemption from a real error and requeue instead of failing.
  static final _preemptedIds = <int>{};

  // Last moment each download proved it was still alive (registered, or a
  // progress callback arrived).
  static final _heartbeat = <int, DateTime>{};

  // When pause/preempt/cancel last asked each download to stop.
  //
  // The registry entry is deliberately kept after a stop request until the
  // worker reaches its own `finally`. A worker stuck on an await that never
  // completes never gets there, so the entry (and its queue slot) survived for
  // the full [ghostTimeout] and the chapter could not be restarted: the row
  // spun its progress bar forever and the resume button did nothing. Stamping
  // the request lets [resume] and [reapGhosts] release the slot after a short,
  // bounded grace period instead of waiting ten minutes.
  static final _stopRequestedAt = <int, DateTime>{};

  /// How long a stopped worker gets to reach its `finally` before the registry
  /// treats its entry as a ghost.
  ///
  /// Long enough for a cancelled isolate to unwind a page/segment write (the
  /// pool's own inactivity watchdog is far shorter), short enough that a user
  /// who taps resume sees the download restart within one refresh.
  static const Duration cancelGrace = Duration(seconds: 20);

  /// A registered download that has produced no heartbeat for this long is
  /// treated as a ghost and released.
  ///
  /// Why this exists: [pause] deliberately keeps the registry entry until the
  /// worker unregisters itself. When a cancelled worker never reaches its
  /// `finally` (stuck on an await that no longer completes), the entry stayed
  /// forever, so the scheduler skipped that chapter on every tick and logged
  /// nothing but a single "no eligible item" line — the row spun in the UI and
  /// never resumed. The threshold is well above the pool's own retry/inactivity
  /// watchdog so a genuinely slow transfer is never reaped.
  static const Duration ghostTimeout = Duration(minutes: 10);

  /// Records that [downloadId] is still alive. Called on registration and on
  /// every progress callback.
  static void heartbeat(int downloadId) {
    if (!isActive(downloadId)) return;
    _heartbeat[downloadId] = DateTime.now();
  }

  /// Releases registry entries whose worker stopped reporting.
  ///
  /// Returns the IDs that were reaped, so the caller can log/requeue them.
  static List<int> reapGhosts({Duration? timeout, Duration? stopGrace}) {
    final limit = timeout ?? ghostTimeout;
    final grace = stopGrace ?? cancelGrace;
    final now = DateTime.now();
    final ghosts = <int>[];
    for (final id in allActiveIds) {
      // A stop request starts a much shorter clock: the worker was already
      // told to exit, so a slot it still holds is a ghost the moment the grace
      // period lapses, not after [ghostTimeout].
      final stopAt = _stopRequestedAt[id];
      if (stopAt != null) {
        if (now.difference(stopAt) > grace) ghosts.add(id);
        continue;
      }
      final last = _heartbeat[id];
      if (last == null) {
        // Registered but never heartbeated: start the clock now instead of
        // reaping a download that just claimed its slot.
        _heartbeat[id] = now;
        continue;
      }
      if (now.difference(last) > limit) ghosts.add(id);
    }
    for (final id in ghosts) {
      // Re-issue the cancellation: the worker ignored the first one (that is
      // why its entry outlived the grace period), so it must not keep writing
      // to the same files once the scheduler starts a fresh worker for this
      // chapter.
      final taskId = _internalTaskIds[id];
      if (taskId != null) {
        DownloadIsolatePool.instance.cancelTask(taskId);
      }
      unregister(id);
      _preemptedIds.remove(id);
    }
    return ghosts;
  }

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
    _interruptedIds.remove(downloadId);
    _stopRequestedAt.remove(downloadId);
    _heartbeat[downloadId] = DateTime.now();
    _engines[downloadId] = engine;
    _engineItemType[downloadId] = itemType;
    _engineSource[downloadId] = source;
    _activeOrder.add(downloadId);
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
    _interruptedIds.remove(downloadId);
    _stopRequestedAt.remove(downloadId);
    _heartbeat[downloadId] = DateTime.now();
    _internalTaskIds[downloadId] = taskId;
    _internalItemType[downloadId] = itemType ?? ItemType.manga;
    _internalSource[downloadId] = source ?? '_unknown';
    _activeOrder.add(downloadId);
    // Remove any stale engine entry for the same ID
    _engines.remove(downloadId);
    _engineItemType.remove(downloadId);
    _engineSource.remove(downloadId);
  }

  /// Claim a chapter before the first asynchronous step of its worker.
  ///
  /// Multiple queue schedulers can observe the same persisted item at once;
  /// this synchronous check-and-register prevents them from launching
  /// duplicate workers for it.
  static bool tryRegisterInternal(
    int downloadId,
    String taskId, {
    ItemType? itemType,
    String? source,
  }) {
    if (isActive(downloadId)) return false;
    registerInternal(
      downloadId,
      taskId,
      itemType: itemType,
      source: source,
    );
    return true;
  }

  static void unregister(int downloadId) {
    _engines.remove(downloadId);
    _engineItemType.remove(downloadId);
    _engineSource.remove(downloadId);
    _internalTaskIds.remove(downloadId);
    _internalItemType.remove(downloadId);
    _internalSource.remove(downloadId);
    _activeOrder.remove(downloadId);
    _interruptedIds.remove(downloadId);
    _heartbeat.remove(downloadId);
    _stopRequestedAt.remove(downloadId);
  }

  // ── Counting ──────────────────────────────────────────────────────────────

  /// True when at least one download is actively running.
  static bool get hasActive =>
      _engines.isNotEmpty || _internalTaskIds.isNotEmpty;

  /// Number of active downloads (pool tasks + engines) for a given [ItemType].
  ///
  /// Downloads stopped by a lowered limit are still counted: they are draining
  /// but their network work has not stopped yet, so treating them as free would
  /// let the queue overshoot the new limit for as long as the teardown takes.
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

  /// Every active download ID (internal pool tasks + engines), in the order
  /// the workers were registered.
  static List<int> get allActiveIds => _activeOrder.toList(growable: false);

  /// [ItemType] of an active download, or `null` when it is not active.
  static ItemType? activeTypeOf(int downloadId) =>
      _internalItemType[downloadId] ?? _engineItemType[downloadId];

  /// Source recorded for an active download, or `null` when it is not active.
  static String? activeSourceOf(int downloadId) =>
      _internalSource[downloadId] ?? _engineSource[downloadId];

  // ── Control ───────────────────────────────────────────────────────────────

  /// Pause the download.
  ///
  /// * External engine (e.g. Aria2): engine.pause() is called.
  /// * Internal (HLS/manga pool): cancel the current isolate task, but keep
  ///   it registered until its worker exits. This prevents a fast resume from
  ///   starting a second worker against the same files while cancellation is
  ///   still draining. The worker's `finally` block unregisters it.
  static Future<void> pause(int downloadId) async {
    _interruptedIds.add(downloadId);
    _stopRequestedAt[downloadId] = DateTime.now();
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.pause();
      return;
    }
    if (_internalTaskIds.containsKey(downloadId)) {
      // Cancel exactly the task that was registered — no guessing about
      // 'm3u8_' prefixes.  The caller always stores the actual pool task ID.
      final taskId = _internalTaskIds[downloadId]!;
      DownloadIsolatePool.instance.cancelTask(taskId);
      // Keep the registry entry until the worker's completion callback has
      // drained. The scheduler will pick this chapter up after that callback
      // unregisters it, provided the persisted status is no longer paused.
    }
  }

  /// Resume a paused download.
  ///
  /// * External engine: engine.resume() is called.
  /// * Internal: the re-query loop in processDownloads automatically picks
  ///   up the chapter on the next tick once it's no longer in pausedIds.
  static Future<void> resume(int downloadId) async {
    // The user asked for this download to run again, so it is no longer a
    // ghost-in-waiting: drop the stop stamp before deciding what to release.
    _stopRequestedAt.remove(downloadId);
    if (_engines.containsKey(downloadId)) {
      await _engines[downloadId]!.resume();
      return;
    }
    // Internal resume is handled automatically by processDownloads re-querying
    // Isar on each tick — but only once this entry is gone, and a worker that
    // never reached its `finally` leaves it behind. If its task is no longer
    // live in the pool, the entry is a ghost: release it now so the next tick
    // can restart the chapter, instead of the row sitting idle for the whole
    // staleness window.
    //
    // `isTaskActive` only covers tasks already handed to a worker; a task still
    // sitting in the pool queue after its cancellation never appears there, so
    // a cancelled-then-resumed row could keep its entry and never restart.
    final taskId = _internalTaskIds[downloadId];
    if (taskId != null && !DownloadIsolatePool.instance.isTaskActive(taskId)) {
      unregister(downloadId);
    }
  }

  /// Cancel and remove the download from the registry.
  ///
  /// Idempotent: calling it twice (or after the entry is gone) is a no-op and
  /// never launches a ghost worker against the same partial `.part` file.
  static Future<void> cancel(int downloadId) async {
    _interruptedIds.add(downloadId);
    final engine = _engines[downloadId];
    if (engine != null) {
      try {
        await engine.cancel();
      } catch (_) {}
      unregister(downloadId);
      return;
    }
    final taskId = _internalTaskIds[downloadId];
    if (taskId != null) {
      DownloadIsolatePool.instance.cancelTask(taskId);
    }
    // Release the slot synchronously so a second cancel is a no-op and the
    // scheduler can never re-claim a chapter the user just removed. Cancelled
    // rows carry status='cancelled', so the scheduler will not re-queue them.
    unregister(downloadId);
  }

  /// Stops a running download because a lowered concurrency limit put it over
  /// budget, *without* unregistering it.
  ///
  /// Mirrors [pause]'s cooperative contract: the registry entry (and the
  /// [wasInterrupted] flag) is kept until the worker's own `finally` unregisters
  /// it. That way the scheduler never starts a second worker for the same
  /// download while the first is still draining, and the worker exits without
  /// marking the download failed or complete. [wasPreempted] stays set so an
  /// engine failure path can requeue instead of failing.
  static Future<void> preempt(int downloadId) async {
    _interruptedIds.add(downloadId);
    _preemptedIds.add(downloadId);
    _stopRequestedAt[downloadId] = DateTime.now();
    final engine = _engines[downloadId];
    if (engine != null) {
      try {
        await engine.cancel();
      } catch (_) {}
      return;
    }
    final taskId = _internalTaskIds[downloadId];
    if (taskId != null) {
      DownloadIsolatePool.instance.cancelTask(taskId);
    }
  }

  /// Marks [downloadId] as preempted by a lowered concurrency limit.
  static void markPreempted(int downloadId) => _preemptedIds.add(downloadId);
  /// Whether [downloadId] was preempted (and not yet re-dispatched).
  static bool wasPreempted(int downloadId) => _preemptedIds.contains(downloadId);

  /// Clears the preemption flag once it has been handled.
  static void clearPreempted(int downloadId) => _preemptedIds.remove(downloadId);

  /// Whether a download is currently tracked (i.e. actively running).
  static bool isActive(int downloadId) =>
      _engines.containsKey(downloadId) ||
      _internalTaskIds.containsKey(downloadId);

  /// True after a user pause/cancel interrupted the current attempt. Kept
  /// until a fresh internal worker registers, so a fast resume cannot let the
  /// cancelled worker mark itself complete.
  static bool wasInterrupted(int downloadId) =>
      _interruptedIds.contains(downloadId);
}
