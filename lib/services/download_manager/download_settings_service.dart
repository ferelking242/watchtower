import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Engine mode for anime (video) downloads only.
/// Manga and novel always use the internal downloader.
enum DownloadMode {
  internalDownloader, // 0 — internal HLS/M3U8 downloader
  internalFallback,   // 1 — Internal first, ZeusDL if it fails (default)
  zeusDl,             // 2 — ZeusDL only (yt-dlp based)
  auto,               // 3 — intelligent automatic selection
}

extension DownloadModeExt on DownloadMode {
  String get label {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Téléchargeur HLS Interne';
      case DownloadMode.internalFallback:
        return 'Interne → ZeusDL (Fallback)';
      case DownloadMode.zeusDl:
        return 'ZeusDL Uniquement';
      case DownloadMode.auto:
        return 'Auto (Recommandé)';
    }
  }

  String get description {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Téléchargeur HLS interne. Idéal pour la majorité des streams M3U8.';
      case DownloadMode.internalFallback:
        return 'Utilise le moteur interne. Bascule automatiquement sur ZeusDL en cas d\'échec.';
      case DownloadMode.zeusDl:
        return 'Moteur ZeusDL uniquement (basé sur yt-dlp). Idéal pour les streams protégés.';
      case DownloadMode.auto:
        return 'Sélection automatique du meilleur moteur selon le type de source.';
    }
  }

  bool get isDefault => this == DownloadMode.internalFallback;
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

  /// Download engine mode for anime (video/HLS). Key 'animeDownloadMode'.
  /// Falls back to legacy 'downloadMode' key for migration.
  DownloadMode get animeDownloadMode {
    final idx =
        (_data['animeDownloadMode'] ?? _data['downloadMode']) as int? ??
        DownloadMode.internalFallback.index;
    return DownloadMode.values[idx.clamp(0, DownloadMode.values.length - 1)];
  }

  Future<void> setAnimeDownloadMode(DownloadMode mode) async {
    _data['animeDownloadMode'] = mode.index;
    // Mirror to legacy key for backward compat with engine_selector
    _data['downloadMode'] = mode.index;
    await _save();
  }

  /// Legacy getter — used by EngineSelector. Points to animeDownloadMode.
  DownloadMode get downloadMode => animeDownloadMode;
  Future<void> setDownloadMode(DownloadMode mode) => setAnimeDownloadMode(mode);

  // ── Per-type connection settings ─────────────────────────────────────────

  /// Concurrent image downloads per manga chapter (default 3).
  int get mangaConnections {
    return (_data['mangaConnections'] as int? ?? 3).clamp(1, 10);
  }

  Future<void> setMangaConnections(int value) async {
    _data['mangaConnections'] = value.clamp(1, 10);
    await _save();
  }

  /// Concurrent M3U8 segment downloads per anime episode (default 3).
  int get animeConnections {
    return (_data['animeConnections'] as int? ?? 3).clamp(1, 10);
  }

  Future<void> setAnimeConnections(int value) async {
    _data['animeConnections'] = value.clamp(1, 10);
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
