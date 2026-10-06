import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as path;
part 'downloads_state_provider.g.dart';

/// Lecture sûre de l'enregistrement `Settings`.
///
/// Crash corrigé : `RangeError (length)` soulevé par la désérialisation Isar
/// d'un enregistrement `Settings` corrompu (ou écrit par un ancien schéma).
/// Ce `getSync` est appelé partout dans l'app (bibliothèque, détail, lecteur…
/// et surtout `processDownloads` à chaque tick via `onlyOnWifiStateProvider`)
/// : sans garde, UNE seule lecture corrompue tue la boucle de téléchargement
/// via `runZonedGuarded` et le bouton « Télécharger » ne fait plus rien.
///
/// L'implémentation vit dans `services/settings_store.dart` (partagée avec le
/// lecteur, le downloader et la réparation au démarrage) : réparation du
/// record illisible + journalisation systématique de la corruption.
Settings safeReadSettings() => readSettingsSafely(isar: isar);

@riverpod
class OnlyOnWifiState extends _$OnlyOnWifiState {
  @override
  bool build() {
    return safeReadSettings().downloadOnlyOnWifi ?? false;
  }

  void set(bool value) {
    final settings = safeReadSettings();
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..downloadOnlyOnWifi = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class SaveAsCBZArchiveState extends _$SaveAsCBZArchiveState {
  @override
  bool build() {
    return safeReadSettings().saveAsCBZArchive ?? false;
  }

  void set(bool value) {
    final settings = safeReadSettings();
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..saveAsCBZArchive = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DeleteDownloadAfterReadingState
    extends _$DeleteDownloadAfterReadingState {
  @override
  bool build() {
    return safeReadSettings().deleteDownloadAfterReading ?? false;
  }

  void set(bool value) {
    final settings = safeReadSettings();
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..deleteDownloadAfterReading = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class DownloadLocationState extends _$DownloadLocationState {
  @override
  (String, String) build() {
    _refresh();
    return ("", safeReadSettings().downloadLocation ?? "");
  }

  void set(String location) {
    final settings = safeReadSettings();
    final basePath = _storageProvider?.path;
    state = (basePath == null ? "" : path.join(basePath, 'download'), location);
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..downloadLocation = location
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Directory? _storageProvider;

  Future _refresh() async {
    try {
      _storageProvider = await StorageProvider().getDefaultDirectory();
      final settings = safeReadSettings();
      final basePath = _storageProvider?.path;
      state = (
        basePath == null ? "" : path.join(basePath, 'download'),
        settings.downloadLocation ?? "",
      );
    } catch (_) {
      // Keep the provider usable while storage is unavailable. The download
      // action will report the concrete filesystem error instead of crashing
      // the settings screen during its first build.
      final settings = safeReadSettings();
      state = ("", settings.downloadLocation ?? "");
    }
  }
}

@riverpod
class ConcurrentDownloadsState extends _$ConcurrentDownloadsState {
  @override
  int build() {
    return safeReadSettings().concurrentDownloads ?? 2;
  }

  void set(int value) {
    final settings = safeReadSettings();
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..concurrentDownloads = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

// ── Anime engine mode — JSON via DownloadSettingsService ──────────────────────

@riverpod
class DownloadModeState extends _$DownloadModeState {
  @override
  DownloadMode build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.animeDownloadMode;
  }

  Future<void> set(DownloadMode mode) async {
    state = mode;
    await DownloadSettingsService.instance.setAnimeDownloadMode(mode);
  }
}

// ── Manga archive format ──────────────────────────────────────────────────────

@riverpod
class MangaArchiveFormatState extends _$MangaArchiveFormatState {
  @override
  MangaArchiveFormat build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.mangaArchiveFormat;
  }

  Future<void> set(MangaArchiveFormat format) async {
    state = format;
    await DownloadSettingsService.instance.setMangaArchiveFormat(format);
  }
}

// ── Per-type connection settings ─────────────────────────────────────────────

@riverpod
class MangaConnectionsState extends _$MangaConnectionsState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.mangaConnections;
  }

  Future<void> set(int value) async {
    state = value;
    await DownloadSettingsService.instance.setMangaConnections(value);
  }
}

@riverpod
class AnimeConnectionsState extends _$AnimeConnectionsState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.animeConnections;
  }

  Future<void> set(int value) async {
    state = value;
    await DownloadSettingsService.instance.setAnimeConnections(value);
  }
}

@riverpod
class NovelConnectionsState extends _$NovelConnectionsState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.novelConnections;
  }

  Future<void> set(int value) async {
    state = value;
    await DownloadSettingsService.instance.setNovelConnections(value);
  }
}

// ── Per-type Only on WiFi ─────────────────────────────────────────────────────

@riverpod
class WatchOnlyOnWifiState extends _$WatchOnlyOnWifiState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.watchOnlyOnWifi;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setWatchOnlyOnWifi(v);
  }
}

@riverpod
class MangaOnlyOnWifiState extends _$MangaOnlyOnWifiState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.mangaOnlyOnWifi;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setMangaOnlyOnWifi(v);
  }
}

@riverpod
class NovelOnlyOnWifiState extends _$NovelOnlyOnWifiState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.novelOnlyOnWifi;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setNovelOnlyOnWifi(v);
  }
}

// ── Speed limit ───────────────────────────────────────────────────────────────

@riverpod
class SpeedLimitKBsState extends _$SpeedLimitKBsState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.speedLimitKBs;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setSpeedLimitKBs(v);
  }
}

// ── Auto-download ─────────────────────────────────────────────────────────────

@riverpod
class AutoDownloadNewChaptersState extends _$AutoDownloadNewChaptersState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.autoDownloadNewChapters;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAutoDownloadNewChapters(v);
  }
}

@riverpod
class AutoDownloadNewEpisodesState extends _$AutoDownloadNewEpisodesState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.autoDownloadNewEpisodes;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAutoDownloadNewEpisodes(v);
  }
}

// ── Anticipatory download ─────────────────────────────────────────────────────

@riverpod
class AnticipatoryDownloadWatchState extends _$AnticipatoryDownloadWatchState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.anticipatoryDownloadWatch;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAnticipatoryDownloadWatch(v);
  }
}

@riverpod
class AnticipatoryDownloadReadState extends _$AnticipatoryDownloadReadState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.anticipatoryDownloadRead;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAnticipatoryDownloadRead(v);
  }
}

// ── Filler episodes ───────────────────────────────────────────────────────────

@riverpod
class DownloadFillerEpisodesState extends _$DownloadFillerEpisodesState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.downloadFillerEpisodes;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setDownloadFillerEpisodes(v);
  }
}

// ── Delete settings ───────────────────────────────────────────────────────────

@riverpod
class DeleteAfterMarkedReadState extends _$DeleteAfterMarkedReadState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.deleteAfterMarkedRead;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setDeleteAfterMarkedRead(v);
  }
}

@riverpod
class AllowDeletingBookmarkedChaptersState
    extends _$AllowDeletingBookmarkedChaptersState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.allowDeletingBookmarkedChapters;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAllowDeletingBookmarkedChapters(
      v,
    );
  }
}

// ── External downloader ───────────────────────────────────────────────────────

@riverpod
class AlwaysUseExternalDownloaderState
    extends _$AlwaysUseExternalDownloaderState {
  @override
  bool build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.alwaysUseExternalDownloader;
  }

  Future<void> set(bool v) async {
    state = v;
    await DownloadSettingsService.instance.setAlwaysUseExternalDownloader(v);
  }
}

@riverpod
class PreferredExternalDownloaderState
    extends _$PreferredExternalDownloaderState {
  @override
  String? build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.preferredExternalDownloader;
  }

  Future<void> set(String? v) async {
    state = v;
    await DownloadSettingsService.instance.setPreferredExternalDownloader(v);
  }
}

// ── Per-type simultaneous downloads ───────────────────────────────────────────

@riverpod
class WatchSimultaneousState extends _$WatchSimultaneousState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.watchSimultaneous;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setWatchSimultaneous(v);
  }
}

@riverpod
class MangaSimultaneousState extends _$MangaSimultaneousState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.mangaSimultaneous;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setMangaSimultaneous(v);
  }
}

@riverpod
class NovelSimultaneousState extends _$NovelSimultaneousState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.novelSimultaneous;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setNovelSimultaneous(v);
  }
}

// ── Per-source simultaneous downloads ─────────────────────────────────────────

@riverpod
class WatchSimultaneousPerSourceState
    extends _$WatchSimultaneousPerSourceState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.watchSimultaneousPerSource;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setWatchSimultaneousPerSource(v);
  }
}

@riverpod
class MangaSimultaneousPerSourceState
    extends _$MangaSimultaneousPerSourceState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.mangaSimultaneousPerSource;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setMangaSimultaneousPerSource(v);
  }
}

@riverpod
class NovelSimultaneousPerSourceState
    extends _$NovelSimultaneousPerSourceState {
  @override
  int build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.novelSimultaneousPerSource;
  }

  Future<void> set(int v) async {
    state = v;
    await DownloadSettingsService.instance.setNovelSimultaneousPerSource(v);
  }
}

// ── Download card layout ───────────────────────────────────────────────────────

@riverpod
class DownloadCardLayoutState extends _$DownloadCardLayoutState {
  @override
  DownloadCardLayout build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.downloadCardLayout;
  }

  Future<void> set(DownloadCardLayout v) async {
    state = v;
    await DownloadSettingsService.instance.setDownloadCardLayout(v);
  }
}

// ── Card buttons ──────────────────────────────────────────────────────────────

@riverpod
class CardButtonsState extends _$CardButtonsState {
  @override
  Set<CardButton> build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.enabledCardButtons;
  }

  Future<void> set(Set<CardButton> buttons) async {
    state = buttons;
    await DownloadSettingsService.instance.setEnabledCardButtons(buttons);
  }

  Future<void> toggle(CardButton button) async {
    final next = Set<CardButton>.from(state);
    if (next.contains(button)) {
      next.remove(button);
    } else {
      next.add(button);
    }
    await set(next);
  }
}

// ── Swipe Actions ─────────────────────────────────────────────────────────────

@riverpod
class SwipeLeftActionState extends _$SwipeLeftActionState {
  @override
  SwipeAction build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.swipeLeftAction;
  }

  Future<void> set(SwipeAction action) async {
    state = action;
    await DownloadSettingsService.instance.setSwipeLeftAction(action);
  }
}

@riverpod
class SwipeRightActionState extends _$SwipeRightActionState {
  @override
  SwipeAction build() {
    DownloadSettingsService.instance.load();
    return DownloadSettingsService.instance.swipeRightAction;
  }

  Future<void> set(SwipeAction action) async {
    state = action;
    await DownloadSettingsService.instance.setSwipeRightAction(action);
  }
}

// ── In-memory download queue state ────────────────────────────────────────────

@riverpod
class DownloadQueueState extends _$DownloadQueueState {
  static const _pausedIdsKey = 'watchtower_download_paused_ids';

  @override
  DownloadQueueStateData build() {
    unawaited(_restorePausedIds());
    return const DownloadQueueStateData();
  }

  Future<void> _restorePausedIds() async {
    final savedIds = <int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      savedIds.addAll(
        (prefs.getStringList(_pausedIdsKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet(),
      );
    } catch (_) {
      // Isar remains the durable source of truth for paused queue items.
    }

    try {
      final pausedIds = isar.downloads
          .where()
          .findAllSync()
          .where(
            (download) =>
                download.id != null &&
                download.isDownload != true &&
                download.status == 'paused',
          )
          .map((download) => download.id!)
          .toSet();
      state = state.copyWith(pausedIds: pausedIds);
      _persistPausedIds(pausedIds);
    } catch (error, stackTrace) {
      // If Isar is temporarily unavailable during startup, use the last saved
      // UI snapshot. The database status will reconcile it on the next launch.
      if (savedIds.isNotEmpty) {
        state = state.copyWith(pausedIds: savedIds);
      }
      AppLogger.log(
        'Could not restore paused downloads from Isar',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _persistPausedIds(Set<int> ids) {
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setStringList(
          _pausedIdsKey,
          ids.map((id) => id.toString()).toList(),
        ),
      ),
    );
  }

  void setPaused(int downloadId, bool paused) {
    final set = Set<int>.from(state.pausedIds);
    if (paused) {
      set.add(downloadId);
      unawaited(ActiveDownloadRegistry.pause(downloadId));
    } else {
      set.remove(downloadId);
      unawaited(ActiveDownloadRegistry.resume(downloadId));
    }
    state = state.copyWith(pausedIds: set);
    _persistPausedIds(set);

    try {
      isar.writeTxnSync(() {
        final download = isar.downloads.getSync(downloadId);
        if (download == null || download.isDownload == true) return;
        isar.downloads.putSync(
          download
            ..isDownload = false
            ..isStartDownload = true
            ..status = paused ? 'paused' : 'queued',
        );
      });
    } catch (error, stackTrace) {
      AppLogger.log(
        'Could not persist paused state for download $downloadId',
        logLevel: LogLevel.error,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void togglePause(int downloadId) {
    final stored = isar.downloads.getSync(downloadId);
    final wasPaused =
        state.pausedIds.contains(downloadId) || stored?.status == 'paused';
    setPaused(downloadId, !wasPaused);
  }

  void setEngine(int downloadId, String engine) {
    final map = Map<int, String>.from(state.engineMap);
    map[downloadId] = engine;
    state = state.copyWith(engineMap: map);
  }

  void incrementRetry(int downloadId) {
    final map = Map<int, int>.from(state.retryCounts);
    map[downloadId] = (map[downloadId] ?? 0) + 1;
    state = state.copyWith(retryCounts: map);
  }

  void setSpeed(int downloadId, double speedMBs) {
    final map = Map<int, double>.from(state.speeds);
    map[downloadId] = speedMBs;
    state = state.copyWith(speeds: map);
  }

  /// Progression volatile du téléchargement courant.
  ///
  /// Le poids final d'une playlist HLS n'est connu qu'après la fusion. On ne
  /// doit donc pas écrire une estimation dans le modèle Isar et la présenter
  /// comme une taille réelle. Cette valeur sert uniquement à rendre la carte
  /// fluide pendant le téléchargement.
  void setLiveProgress(int downloadId, DownloadLiveProgress progress) {
    final map = Map<int, DownloadLiveProgress>.from(state.liveProgress);
    map[downloadId] = progress;
    state = state.copyWith(liveProgress: map);
  }

  void clearLiveProgress(int downloadId) {
    if (!state.liveProgress.containsKey(downloadId)) return;
    final map = Map<int, DownloadLiveProgress>.from(state.liveProgress)
      ..remove(downloadId);
    state = state.copyWith(liveProgress: map);
  }

  /// Speed Master — queue priority (0 = normal, 1 = haute).
  /// Consumed by [processDownloads] to order waiting downloads; a re-kick of
  /// processDownloads after changing this makes it effective immediately.
  void setPriority(int downloadId, int priority) {
    final map = Map<int, int>.from(state.priorities);
    map[downloadId] = priority.clamp(0, 1);
    state = state.copyWith(priorities: map);
  }

  void pauseAll(List<int> ids) {
    for (final id in ids) {
      final download = isar.downloads.getSync(id);
      if (download == null ||
          download.isDownload == true ||
          const {'failed', 'cancelled', 'completed'}.contains(
            download.status,
          )) {
        continue;
      }
      setPaused(id, true);
    }
  }

  void resumeAll([Iterable<int>? downloadIds]) {
    final storedPausedIds = isar.downloads
        .where()
        .findAllSync()
        .where(
          (download) =>
              download.id != null &&
              download.isDownload != true &&
              download.status == 'paused',
        )
        .map((download) => download.id!)
        .toSet();
    final ids =
        downloadIds?.toSet() ?? {...state.pausedIds, ...storedPausedIds};
    for (final id in ids) {
      final download = isar.downloads.getSync(id);
      if (download?.status == 'paused' && download?.isDownload != true) {
        setPaused(id, false);
      } else if (state.pausedIds.contains(id)) {
        final paused = Set<int>.from(state.pausedIds)..remove(id);
        state = state.copyWith(pausedIds: paused);
        _persistPausedIds(paused);
      }
    }
  }
}

class DownloadQueueStateData {
  final Set<int> pausedIds;
  final Map<int, String> engineMap;
  final Map<int, int> retryCounts;
  final Map<int, double> speeds;
  final Map<int, int> priorities;
  final Map<int, DownloadLiveProgress> liveProgress;

  const DownloadQueueStateData({
    this.pausedIds = const {},
    this.engineMap = const {},
    this.retryCounts = const {},
    this.speeds = const {},
    this.priorities = const {},
    this.liveProgress = const {},
  });

  DownloadQueueStateData copyWith({
    Set<int>? pausedIds,
    Map<int, String>? engineMap,
    Map<int, int>? retryCounts,
    Map<int, double>? speeds,
    Map<int, int>? priorities,
    Map<int, DownloadLiveProgress>? liveProgress,
  }) {
    return DownloadQueueStateData(
      pausedIds: pausedIds ?? this.pausedIds,
      engineMap: engineMap ?? this.engineMap,
      retryCounts: retryCounts ?? this.retryCounts,
      speeds: speeds ?? this.speeds,
      priorities: priorities ?? this.priorities,
      liveProgress: liveProgress ?? this.liveProgress,
    );
  }
}

/// Transfer progress that is only valid for the current app session.
/// For images, byte fields describe the image currently being transferred;
/// completed/total units remain the count of fully saved pages.
class DownloadLiveProgress {
  final int? downloadedBytes;
  final int? totalBytes;
  final int completedUnits;
  final int totalUnits;
  final bool isIndeterminate;

  const DownloadLiveProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.completedUnits,
    required this.totalUnits,
    this.isIndeterminate = false,
  });
}
