import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:path/path.dart' as path;

// ─── Log Settings Keys (Hive box: advanced_settings) ──────────────────────────
const _kLogBox = 'advanced_settings';
const kLogMinLevel = 'log_min_level';
const kLogMode = 'log_mode';
const kLogTagExt = 'log_tag_ext';
const kLogTagDl = 'log_tag_dl';
const kLogTagNet = 'log_tag_net';
const kLogTagZeus = 'log_tag_zeus';
const kLogTagUi = 'log_tag_ui';
const kLogTagManga = 'log_tag_manga';
const kLogTagPage = 'log_tag_page';
const kLogTagHls = 'log_tag_hls';
const kLogTagInstall = 'log_tag_install';
const kLogTagReader = 'log_tag_reader';
const kLogSuppressImages = 'log_suppress_images';

// ─── Log Modes ─────────────────────────────────────────────────────────────────
enum LogMode {
  normal,
  verbose,
  debug,
  extreme;

  String get displayName {
    switch (this) {
      case LogMode.normal:
        return 'Normal';
      case LogMode.verbose:
        return 'Verbose';
      case LogMode.debug:
        return 'Debug';
      case LogMode.extreme:
        return 'Extreme';
    }
  }

  String get description {
    switch (this) {
      case LogMode.normal:
        return 'INFO+ · extensions & installs uniquement';
      case LogMode.verbose:
        return 'DEBUG+ · réseau, téléchargements, manga, HLS';
      case LogMode.debug:
        return 'DEBUG+ · tout sauf lectures page par page';
      case LogMode.extreme:
        return '⚡ TOUT logger – chaque page, segment HLS, événement lecteur';
    }
  }

  int get minLevel => this == LogMode.normal ? 1 : 0;

  bool get isHeavy => this == LogMode.debug || this == LogMode.extreme;

  Map<String, bool> get defaultTags {
    switch (this) {
      case LogMode.normal:
        return {
          kLogTagExt: true, kLogTagDl: false, kLogTagNet: false,
          kLogTagZeus: false, kLogTagUi: false, kLogTagManga: false,
          kLogTagPage: false, kLogTagHls: false, kLogTagInstall: true,
          kLogTagReader: false,
        };
      case LogMode.verbose:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: false,
        };
      case LogMode.debug:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true,
        };
      case LogMode.extreme:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: true, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true,
        };
    }
  }
}

class AppLogger {
  static final _logQueue = StreamController<String>();
  static late File _logFile;
  static late IOSink _sink;
  static bool _initialized = false;

  // ── In-memory filter state ──────────────────────────────────────────────────
  static int _minLevel = 0; // default: DEBUG (max verbosity)
  static Set<String> _disabledTags = {};
  static bool _suppressImages = true;

  static Future<void> init() async {
    final enabled = isar.settings.getSync(227)?.enableLogs ?? false;
    if (!enabled) return;

    await _loadSettings();

    final storage = StorageProvider();
    final directory = await storage.getDefaultDirectory();
    _logFile = File(path.join(directory!.path, 'logs.txt'));

    if (await _logFile.exists() && await _logFile.length() > 200 * 1024) {
      final backup = File(path.join(directory.path, 'logs.bak.txt'));
      if (await backup.exists()) await backup.delete();
      await _logFile.rename(backup.path);
    }

    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }

    _sink = _logFile.openWrite(mode: FileMode.append);
    _initialized = true;

    _logQueue.stream.listen((entry) {
      _sink.writeln(entry);
    });

    await _writeSessionHeader();
  }

  // Call this after changing settings in the UI to update in-memory filters
  static Future<void> reloadSettings() => _loadSettings();

  static Future<void> _loadSettings() async {
    try {
      final box = await Hive.openBox(_kLogBox);
      _minLevel = box.get(kLogMinLevel, defaultValue: 0) as int;
      _suppressImages = box.get(kLogSuppressImages, defaultValue: true) as bool;

      final disabled = <String>{};
      final tagMap = {
        LogTag.extension_: kLogTagExt,
        LogTag.download: kLogTagDl,
        LogTag.network: kLogTagNet,
        LogTag.zeus: kLogTagZeus,
        LogTag.ui: kLogTagUi,
        LogTag.manga: kLogTagManga,
        LogTag.page: kLogTagPage,
        LogTag.hls: kLogTagHls,
        LogTag.install: kLogTagInstall,
        LogTag.reader: kLogTagReader,
        LogTag.repo: kLogTagExt, // REPO shares the EXT toggle
      };
      for (final entry in tagMap.entries) {
        final enabled = box.get(entry.value, defaultValue: true) as bool;
        if (!enabled) disabled.add(entry.key);
      }
      _disabledTags = disabled;
    } catch (_) {}
  }

  static Future<void> _writeSessionHeader() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.operatingSystem;
      final now = _timestamp();
      final header = '''
══════════════════════════════════════════
  WATCHTOWER SESSION STARTED
  Date   : $now
  Version: ${info.version} (build ${info.buildNumber})
  OS     : $platform
══════════════════════════════════════════''';
      _logQueue.add(header);
    } catch (_) {
      _logQueue.add('[${_timestamp()}][INFO] Logger initialized');
    }
  }

  // Returns true if this image-related error should be suppressed
  static bool shouldSuppressImageError(String message) {
    return _suppressImages &&
        (message.contains('Failed to load') || message.contains('Bad state'));
  }

  static void log(
    String message, {
    LogLevel logLevel = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_initialized) return;

    // Filter by minimum level
    if (logLevel.index < _minLevel) return;

    // Filter by disabled tags
    if (tag != null && _disabledTags.contains(tag)) return;

    // Suppress image errors if configured
    if (_suppressImages &&
        logLevel == LogLevel.error &&
        (message.contains('Failed to load') ||
            message.contains('Bad state'))) {
      return;
    }

    final tagPart = tag != null ? '[$tag] ' : '';
    final entry = StringBuffer(
      '[${_timestamp()}][${logLevel.label}] $tagPart$message',
    );

    if (error != null) {
      entry.write('\n  Error: $error');
    }

    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n');
      final limited = lines.take(12).join('\n  ');
      entry.write('\n  Stack:\n  $limited');
      if (lines.length > 12) {
        entry.write('\n  ... (${lines.length - 12} more lines hidden)');
      }
    }

    if (kDebugMode) debugPrint(entry.toString());
    _logQueue.add(entry.toString());
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static Future<void> dispose() async {
    if (!_initialized) return;
    await _logQueue.close();
    await _sink.flush();
    await _sink.close();
    _initialized = false;
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get displayName {
    switch (this) {
      case LogLevel.debug:
        return 'Debug';
      case LogLevel.info:
        return 'Info';
      case LogLevel.warning:
        return 'Warning';
      case LogLevel.error:
        return 'Error';
    }
  }

  @override
  String toString() => label;
}

abstract final class LogTag {
  static const extension_ = 'EXT';
  static const zeus = 'ZEUS';
  static const download = 'DL';
  static const network = 'NET';
  static const repo = 'REPO';
  static const ui = 'UI';
  static const manga = 'MANGA';
  static const page = 'PAGE';
  static const hls = 'HLS';
  static const install = 'INSTALL';
  static const reader = 'READER';
}
