import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Engine mode for anime (video) downloads only.
/// Manga and novel always use the internal downloader.
enum DownloadMode {
  internalDownloader, // 0 — internal HLS/M3U8 downloader
  aria2,              // 1 — aria2c binary downloader
  external,           // 2 — hand off to ADM/1DM/FDM/IDM via intent
}

extension DownloadModeExt on DownloadMode {
  String get label {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Interne';
      case DownloadMode.aria2:
        return 'Aria2';
      case DownloadMode.external:
        return 'Externe';
    }
  }

  String get description {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Téléchargeur HLS intégré à l\'application. Idéal pour la majorité des streams.';
      case DownloadMode.aria2:
        return 'Moteur aria2c haute performance. Connexions multiples et reprise des téléchargements.';
      case DownloadMode.external:
        return 'Délègue à une app externe (ADM, 1DM, FDM, IDM…). Le téléchargement quitte l\'application.';
    }
  }

  bool get isDefault => this == DownloadMode.internalDownloader;
}

/// Archive format for manga downloads.
enum MangaArchiveFormat {
  folder,  // 0 — images in folder (no archive)
  cbz,     // 1 — CBZ (ZIP with images)
  cbr,     // 2 — CBR (RAR-like, stored as zip)
  cb7,     // 3 — CB7 (7z-like, stored as zip)
  zip,     // 4 — ZIP plain
}

extension MangaArchiveFormatExt on MangaArchiveFormat {
  String get label {
    switch (this) {
      case MangaArchiveFormat.folder:
        return 'Dossier (images)';
      case MangaArchiveFormat.cbz:
        return 'CBZ';
      case MangaArchiveFormat.cbr:
        return 'CBR';
      case MangaArchiveFormat.cb7:
        return 'CB7';
      case MangaArchiveFormat.zip:
        return 'ZIP';
    }
  }

  String get extension {
    switch (this) {
      case MangaArchiveFormat.folder:
        return '';
      case MangaArchiveFormat.cbz:
        return '.cbz';
      case MangaArchiveFormat.cbr:
        return '.cbr';
      case MangaArchiveFormat.cb7:
        return '.cb7';
      case MangaArchiveFormat.zip:
        return '.zip';
    }
  }
}

/// Enum for swipe left/right actions on download cards
enum SwipeAction { pauseResume, cancel, delete, retry, none }

extension SwipeActionExt on SwipeAction {
  String get label {
    switch (this) {
      case SwipeAction.pauseResume:
        return 'Pause / Reprendre';
      case SwipeAction.cancel:
        return 'Annuler';
      case SwipeAction.delete:
        return 'Supprimer';
      case SwipeAction.retry:
        return 'Réessayer';
      case SwipeAction.none:
        return 'Désactivé';
    }
  }
}

class DownloadSettingsService {
  static DownloadSettingsService? _instance;
  static DownloadSettingsService get instance =>
      _instance ??= DownloadSettingsService._();
  DownloadSettingsService._();

  static const String _fileName = 'download_settings.json';
  Map<String, dynamic> _data = {};
  bool _loaded = false;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        _data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }

  // ── Anime engine mode ─────────────────────────────────────────────────────

  DownloadMode get animeDownloadMode {
    final raw = (_data['animeDownloadMode'] ?? _data['downloadMode']) as int?;
    if (raw == null) return DownloadMode.internalDownloader;
    if (raw >= DownloadMode.values.length) return DownloadMode.internalDownloader;
    return DownloadMode.values[raw.clamp(0, DownloadMode.values.length - 1)];
  }

  Future<void> setAnimeDownloadMode(DownloadMode mode) async {
    _data['animeDownloadMode'] = mode.index;
    _data['downloadMode'] = mode.index;
    await _save();
  }

  /// Legacy getter — used by EngineSelector.
  DownloadMode get downloadMode => animeDownloadMode;
  Future<void> setDownloadMode(DownloadMode mode) => setAnimeDownloadMode(mode);

  // ── Per-type connection settings ─────────────────────────────────────────

  int get mangaConnections {
    return (_data['mangaConnections'] as int? ?? 3).clamp(1, 10);
  }

  Future<void> setMangaConnections(int value) async {
    _data['mangaConnections'] = value.clamp(1, 10);
    await _save();
  }

  int get animeConnections {
    return (_data['animeConnections'] as int? ?? 3).clamp(1, 10);
  }

  Future<void> setAnimeConnections(int value) async {
    _data['animeConnections'] = value.clamp(1, 10);
    await _save();
  }

  int get novelConnections {
    return (_data['novelConnections'] as int? ?? 3).clamp(1, 10);
  }

  Future<void> setNovelConnections(int value) async {
    _data['novelConnections'] = value.clamp(1, 10);
    await _save();
  }

  // ── Manga archive format ───────────────────────────────────────────────────

  MangaArchiveFormat get mangaArchiveFormat {
    final idx = _data['mangaArchiveFormat'] as int?;
    if (idx == null) {
      final oldCbz = _data['saveAsCBZ'] as bool? ?? false;
      return oldCbz ? MangaArchiveFormat.cbz : MangaArchiveFormat.folder;
    }
    return MangaArchiveFormat.values[
        idx.clamp(0, MangaArchiveFormat.values.length - 1)];
  }

  Future<void> setMangaArchiveFormat(MangaArchiveFormat format) async {
    _data['mangaArchiveFormat'] = format.index;
    _data['saveAsCBZ'] = format == MangaArchiveFormat.cbz;
    await _save();
  }

  // ── Per-type Only on WiFi ─────────────────────────────────────────────────

  bool get watchOnlyOnWifi => _data['watchOnlyOnWifi'] as bool? ?? false;
  Future<void> setWatchOnlyOnWifi(bool v) async {
    _data['watchOnlyOnWifi'] = v;
    await _save();
  }

  bool get mangaOnlyOnWifi => _data['mangaOnlyOnWifi'] as bool? ?? false;
  Future<void> setMangaOnlyOnWifi(bool v) async {
    _data['mangaOnlyOnWifi'] = v;
    await _save();
  }

  bool get novelOnlyOnWifi => _data['novelOnlyOnWifi'] as bool? ?? false;
  Future<void> setNovelOnlyOnWifi(bool v) async {
    _data['novelOnlyOnWifi'] = v;
    await _save();
  }

  // ── Speed limit (KB/s, 0 = unlimited) ────────────────────────────────────

  int get speedLimitKBs => _data['speedLimitKBs'] as int? ?? 0;
  Future<void> setSpeedLimitKBs(int v) async {
    _data['speedLimitKBs'] = v.clamp(0, 100000);
    await _save();
  }

  // ── Auto-download new chapters/episodes ─────────────────────────────────

  bool get autoDownloadNewChapters => _data['autoDownloadNewChapters'] as bool? ?? false;
  Future<void> setAutoDownloadNewChapters(bool v) async {
    _data['autoDownloadNewChapters'] = v;
    await _save();
  }

  bool get autoDownloadNewEpisodes => _data['autoDownloadNewEpisodes'] as bool? ?? false;
  Future<void> setAutoDownloadNewEpisodes(bool v) async {
    _data['autoDownloadNewEpisodes'] = v;
    await _save();
  }

  // ── Anticipatory download (pre-fetch while watching/reading) ─────────────

  bool get anticipatoryDownloadWatch => _data['anticipatoryDownloadWatch'] as bool? ?? false;
  Future<void> setAnticipatoryDownloadWatch(bool v) async {
    _data['anticipatoryDownloadWatch'] = v;
    await _save();
  }

  bool get anticipatoryDownloadRead => _data['anticipatoryDownloadRead'] as bool? ?? false;
  Future<void> setAnticipatoryDownloadRead(bool v) async {
    _data['anticipatoryDownloadRead'] = v;
    await _save();
  }

  // ── Allow filler episodes ────────────────────────────────────────────────

  bool get downloadFillerEpisodes => _data['downloadFillerEpisodes'] as bool? ?? true;
  Future<void> setDownloadFillerEpisodes(bool v) async {
    _data['downloadFillerEpisodes'] = v;
    await _save();
  }

  // ── Delete after reading ─────────────────────────────────────────────────

  bool get deleteAfterMarkedRead => _data['deleteAfterMarkedRead'] as bool? ?? false;
  Future<void> setDeleteAfterMarkedRead(bool v) async {
    _data['deleteAfterMarkedRead'] = v;
    await _save();
  }

  bool get allowDeletingBookmarkedChapters =>
      _data['allowDeletingBookmarkedChapters'] as bool? ?? false;
  Future<void> setAllowDeletingBookmarkedChapters(bool v) async {
    _data['allowDeletingBookmarkedChapters'] = v;
    await _save();
  }

  // ── External downloader preference ────────────────────────────────────────

  String? get preferredExternalDownloader =>
      _data['preferredExternalDownloader'] as String?;
  Future<void> setPreferredExternalDownloader(String? v) async {
    _data['preferredExternalDownloader'] = v;
    await _save();
  }

  bool get alwaysUseExternalDownloader =>
      _data['alwaysUseExternalDownloader'] as bool? ?? false;
  Future<void> setAlwaysUseExternalDownloader(bool v) async {
    _data['alwaysUseExternalDownloader'] = v;
    await _save();
  }

  // ── Per-type simultaneous downloads (queue slots) ─────────────────────────

  int get watchSimultaneous =>
      (_data['watchSimultaneous'] as int? ?? 2).clamp(1, 20);
  Future<void> setWatchSimultaneous(int v) async {
    _data['watchSimultaneous'] = v.clamp(1, 20);
    await _save();
  }

  int get mangaSimultaneous =>
      (_data['mangaSimultaneous'] as int? ?? 3).clamp(1, 20);
  Future<void> setMangaSimultaneous(int v) async {
    _data['mangaSimultaneous'] = v.clamp(1, 20);
    await _save();
  }

  int get novelSimultaneous =>
      (_data['novelSimultaneous'] as int? ?? 3).clamp(1, 20);
  Future<void> setNovelSimultaneous(int v) async {
    _data['novelSimultaneous'] = v.clamp(1, 20);
    await _save();
  }

  // ── Per-source simultaneous downloads ─────────────────────────────────────

  int get watchSimultaneousPerSource =>
      (_data['watchSimPerSource'] as int? ?? 3).clamp(1, 10);
  Future<void> setWatchSimultaneousPerSource(int v) async {
    _data['watchSimPerSource'] = v.clamp(1, 10);
    await _save();
  }

  int get mangaSimultaneousPerSource =>
      (_data['mangaSimPerSource'] as int? ?? 2).clamp(1, 10);
  Future<void> setMangaSimultaneousPerSource(int v) async {
    _data['mangaSimPerSource'] = v.clamp(1, 10);
    await _save();
  }

  int get novelSimultaneousPerSource =>
      (_data['novelSimPerSource'] as int? ?? 2).clamp(1, 10);
  Future<void> setNovelSimultaneousPerSource(int v) async {
    _data['novelSimPerSource'] = v.clamp(1, 10);
    await _save();
  }

  // ── Download card layout ───────────────────────────────────────────────────

  DownloadCardLayout get downloadCardLayout {
    final idx = _data['cardLayout'] as int? ?? DownloadCardLayout.standard.index;
    return DownloadCardLayout.values[idx.clamp(0, DownloadCardLayout.values.length - 1)];
  }

  Future<void> setDownloadCardLayout(DownloadCardLayout v) async {
    _data['cardLayout'] = v.index;
    await _save();
  }

  // ── Source download order ──────────────────────────────────────────────────

  List<String> get sourceDownloadOrder {
    final raw = _data['sourceDownloadOrder'] as List?;
    if (raw == null) return [];
    return raw.whereType<String>().toList();
  }

  Future<void> setSourceDownloadOrder(List<String> order) async {
    _data['sourceDownloadOrder'] = order;
    await _save();
  }

  // ── Card buttons (which action buttons appear on each download card) ────────

  Set<CardButton> get enabledCardButtons {
    final raw = _data['cardButtons'] as List?;
    if (raw == null) return {CardButton.pauseResume};
    return raw
        .map((e) {
          final idx = e as int? ?? -1;
          if (idx < 0 || idx >= CardButton.values.length) return null;
          return CardButton.values[idx];
        })
        .whereType<CardButton>()
        .toSet();
  }

  Future<void> setEnabledCardButtons(Set<CardButton> buttons) async {
    _data['cardButtons'] = buttons.map((b) => b.index).toList();
    await _save();
  }

  // ── Swipe actions ─────────────────────────────────────────────────────────

  SwipeAction get swipeLeftAction {
    final idx =
        _data['swipeLeftAction'] as int? ?? SwipeAction.pauseResume.index;
    return SwipeAction.values[idx.clamp(0, SwipeAction.values.length - 1)];
  }

  Future<void> setSwipeLeftAction(SwipeAction action) async {
    _data['swipeLeftAction'] = action.index;
    await _save();
  }

  SwipeAction get swipeRightAction {
    final idx = _data['swipeRightAction'] as int? ?? SwipeAction.delete.index;
    return SwipeAction.values[idx.clamp(0, SwipeAction.values.length - 1)];
  }

  Future<void> setSwipeRightAction(SwipeAction action) async {
    _data['swipeRightAction'] = action.index;
    await _save();
  }
}

// ── Card layout enum ──────────────────────────────────────────────────────────

/// Display modes for download queue cards.
///
/// - [minimal]  — ultra-dense single row, no cover art.
/// - [compact]  — two-line row, no cover art.
/// - [standard] — default: small cover + text + progress bar.
/// - [full]     — medium cover + engine badge + detailed byte progress.
/// - [media]    — large cover + full info panel, optimised for anime queues.
// IMPORTANT: do NOT reorder existing values — they are persisted as their
// integer index in the JSON settings file.  Append new values at the end only.
enum DownloadCardLayout { compact, standard, full, minimal, media }

extension DownloadCardLayoutExt on DownloadCardLayout {
  String get label {
    switch (this) {
      case DownloadCardLayout.minimal:
        return 'Minimal';
      case DownloadCardLayout.compact:
        return 'Compact';
      case DownloadCardLayout.standard:
        return 'Standard';
      case DownloadCardLayout.full:
        return 'Étendu';
      case DownloadCardLayout.media:
        return 'Médias';
    }
  }

  IconData get icon {
    switch (this) {
      case DownloadCardLayout.minimal:
        return Icons.density_small;
      case DownloadCardLayout.compact:
        return Icons.view_agenda_outlined;
      case DownloadCardLayout.standard:
        return Icons.view_stream_outlined;
      case DownloadCardLayout.full:
        return Icons.view_day_outlined;
      case DownloadCardLayout.media:
        return Icons.auto_awesome_mosaic_outlined;
    }
  }
}

// ── Card button enum ──────────────────────────────────────────────────────────

enum CardButton { pauseResume, retry, cancel, delete, openFolder }

extension CardButtonExt on CardButton {
  String get label {
    switch (this) {
      case CardButton.pauseResume:
        return 'Pause / Reprendre';
      case CardButton.retry:
        return 'Réessayer';
      case CardButton.cancel:
        return 'Annuler';
      case CardButton.delete:
        return 'Supprimer';
      case CardButton.openFolder:
        return 'Ouvrir dossier';
    }
  }

  IconData get icon {
    switch (this) {
      case CardButton.pauseResume:
        return Icons.pause_circle_outline;
      case CardButton.retry:
        return Icons.replay_outlined;
      case CardButton.cancel:
        return Icons.close_outlined;
      case CardButton.delete:
        return Icons.delete_outline;
      case CardButton.openFolder:
        return Icons.folder_open_outlined;
    }
  }
}
