import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as path;
part 'downloads_state_provider.g.dart';

@riverpod
class OnlyOnWifiState extends _$OnlyOnWifiState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.downloadOnlyOnWifi ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
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
    return isar.settings.getSync(227)!.saveAsCBZArchive ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
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
    return isar.settings.getSync(227)!.deleteDownloadAfterReading ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
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
    return ("", isar.settings.getSync(227)!.downloadLocation ?? "");
  }

  void set(String location) {
    final settings = isar.settings.getSync(227);
    state = (path.join(_storageProvider!.path, 'downloads'), location);
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..downloadLocation = location
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Directory? _storageProvider;

  Future _refresh() async {
    _storageProvider = await StorageProvider().getDefaultDirectory();
    final settings = isar.settings.getSync(227);
    state = (
      path.join(_storageProvider!.path, 'downloads'),
      settings!.downloadLocation ?? "",
    );
  }
}

@riverpod
class ConcurrentDownloadsState extends _$ConcurrentDownloadsState {
  @override
  int build() {
    return isar.settings.getSync(227)!.concurrentDownloads ?? 2;
  }

  void set(int value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
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
    await DownloadSettingsService.instance
        .setAllowDeletingBookmarkedChapters(v);
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
  @override
  DownloadQueueStateData build() => const DownloadQueueStateData();

  void setPaused(int downloadId, bool paused) {
    final set = Set<int>.from(state.pausedIds);
    if (paused) {
      set.add(downloadId);
    } else {
      set.remove(downloadId);
    }
    state = state.copyWith(pausedIds: set);
  }

  void togglePause(int downloadId) {
    final set = Set<int>.from(state.pausedIds);
    final wasPaused = set.contains(downloadId);
    if (wasPaused) {
      set.remove(downloadId);
      ActiveDownloadRegistry.resume(downloadId);
    } else {
      set.add(downloadId);
      ActiveDownloadRegistry.pause(downloadId);
    }
    state = state.copyWith(pausedIds: set);
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

  void pauseAll(List<int> ids) {
    final set = Set<int>.from(state.pausedIds);
    for (final id in ids) {
      if (!set.contains(id)) {
        set.add(id);
        ActiveDownloadRegistry.pause(id);
      }
    }
    state = state.copyWith(pausedIds: set);
  }

  void resumeAll() {
    for (final id in state.pausedIds) {
      ActiveDownloadRegistry.resume(id);
    }
    state = state.copyWith(pausedIds: {});
  }
}

class DownloadQueueStateData {
  final Set<int> pausedIds;
  final Map<int, String> engineMap;
  final Map<int, int> retryCounts;
  final Map<int, double> speeds;

  const DownloadQueueStateData({
    this.pausedIds = const {},
    this.engineMap = const {},
    this.retryCounts = const {},
    this.speeds = const {},
  });

  DownloadQueueStateData copyWith({
    Set<int>? pausedIds,
    Map<int, String>? engineMap,
    Map<int, int>? retryCounts,
    Map<int, double>? speeds,
  }) {
    return DownloadQueueStateData(
      pausedIds: pausedIds ?? this.pausedIds,
      engineMap: engineMap ?? this.engineMap,
      retryCounts: retryCounts ?? this.retryCounts,
      speeds: speeds ?? this.speeds,
    );
  }
}
