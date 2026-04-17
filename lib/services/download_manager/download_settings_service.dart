import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Enum for download engine mode
enum DownloadMode {
  internalDownloader, // 0 — internal manga/file downloader (FK)
  fkFallbackZeus, // 1 — FK downloader with automatic ZeusDL fallback (default)
  zeusDl, // 2 — ZeusDL only
  auto, // 3 — intelligent automatic selection
}

extension DownloadModeExt on DownloadMode {
  String get label {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Internal Downloader';
      case DownloadMode.fkFallbackZeus:
        return 'FK Fallback Zeus';
      case DownloadMode.zeusDl:
        return 'ZeusDL';
      case DownloadMode.auto:
        return 'Auto (Recommended)';
    }
  }

  String get description {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Built-in downloader. Best for manga, images, and simple files.';
      case DownloadMode.fkFallbackZeus:
        return 'Uses the internal downloader. Automatically switches to ZeusDL if a download fails.';
      case DownloadMode.zeusDl:
        return 'ZeusDL engine only. Best for protected streams, m3u8, and anti-bot sites.';
      case DownloadMode.auto:
        return 'App automatically selects the best engine based on source type.';
    }
  }
}

/// Enum for swipe left/right actions on download cards
enum SwipeAction { pauseResume, cancel, delete, retry, none }

extension SwipeActionExt on SwipeAction {
  String get label {
    switch (this) {
      case SwipeAction.pauseResume:
        return 'Pause / Resume';
      case SwipeAction.cancel:
        return 'Cancel';
      case SwipeAction.delete:
        return 'Delete';
      case SwipeAction.retry:
        return 'Retry';
      case SwipeAction.none:
        return 'Disabled';
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

  DownloadMode get downloadMode {
    final idx = _data['downloadMode'] as int? ?? DownloadMode.fkFallbackZeus.index;
    return DownloadMode.values[idx.clamp(0, DownloadMode.values.length - 1)];
  }

  Future<void> setDownloadMode(DownloadMode mode) async {
    _data['downloadMode'] = mode.index;
    await _save();
  }

  SwipeAction get swipeLeftAction {
    final idx = _data['swipeLeftAction'] as int? ?? SwipeAction.pauseResume.index;
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
