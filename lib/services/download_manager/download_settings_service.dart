import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum DownloadMode {
  internalDownloader,
  fkFallbackZeus,
  zeusDl,
  auto,
}

extension DownloadModeExt on DownloadMode {
  String get label {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Internal';
      case DownloadMode.fkFallbackZeus:
        return 'FK + ZeusDL';
      case DownloadMode.zeusDl:
        return 'ZeusDL';
      case DownloadMode.auto:
        return 'Auto';
    }
  }

  String get description {
    switch (this) {
      case DownloadMode.internalDownloader:
        return 'Built-in downloader. Best for manga & images.';
      case DownloadMode.fkFallbackZeus:
        return 'FK downloader with ZeusDL fallback on failure.';
      case DownloadMode.zeusDl:
        return 'ZeusDL only. Best for streams & anti-bot sites.';
      case DownloadMode.auto:
        return 'Automatic engine selection based on source type.';
    }
  }


}

enum ArchiveFormat { cbz, cbr, zip, none }

extension ArchiveFormatExt on ArchiveFormat {
  String get label {
    switch (this) {
      case ArchiveFormat.cbz:
        return 'CBZ';
      case ArchiveFormat.cbr:
        return 'CBR';
      case ArchiveFormat.zip:
        return 'ZIP';
      case ArchiveFormat.none:
        return 'Folder (no archive)';
    }
  }

  String get extension {
    switch (this) {
      case ArchiveFormat.cbz:
        return '.cbz';
      case ArchiveFormat.cbr:
        return '.cbr';
      case ArchiveFormat.zip:
        return '.zip';
      case ArchiveFormat.none:
        return '';
    }
  }
}

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

  ArchiveFormat get archiveFormat {
    final idx = _data['archiveFormat'] as int? ?? ArchiveFormat.cbz.index;
    return ArchiveFormat.values[idx.clamp(0, ArchiveFormat.values.length - 1)];
  }

  Future<void> setArchiveFormat(ArchiveFormat format) async {
    _data['archiveFormat'] = format.index;
    await _save();
  }

  // Per-category concurrent downloads
  int get concurrentManga {
    return (_data['concurrentManga'] as int? ?? 2).clamp(1, 30);
  }

  Future<void> setConcurrentManga(int value) async {
    _data['concurrentManga'] = value.clamp(1, 30);
    await _save();
  }

  int get concurrentWatch {
    return (_data['concurrentWatch'] as int? ?? 1).clamp(1, 10);
  }

  Future<void> setConcurrentWatch(int value) async {
    _data['concurrentWatch'] = value.clamp(1, 10);
    await _save();
  }

  int get concurrentNovel {
    return (_data['concurrentNovel'] as int? ?? 3).clamp(1, 30);
  }

  Future<void> setConcurrentNovel(int value) async {
    _data['concurrentNovel'] = value.clamp(1, 30);
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
