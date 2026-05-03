import 'dart:async';
import 'dart:collection';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
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
const kLogTagWatch = 'log_tag_watch';
const kLogTagMaint = 'log_tag_maint';
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
          kLogTagReader: false, kLogTagWatch: false, kLogTagMaint: true,
        };
      case LogMode.verbose:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: false, kLogTagWatch: true, kLogTagMaint: true,
        };
      case LogMode.debug:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true, kLogTagWatch: true, kLogTagMaint: true,
        };
      case LogMode.extreme:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagZeus: true, kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: true, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true, kLogTagWatch: true, kLogTagMaint: true,
        };
    }
  }
}

class AppLogger {
  static final _logQueue = StreamController<String>();
  static late File _logFile;
  // dynamic to accept both dart:io.IOSink (native) and stub IOSink (web)
  static late dynamic _sink;
  static bool _initialized = false;

  // ── In-memory filter state ──────────────────────────────────────────────────
  static int _minLevel = 0; // default: DEBUG (max verbosity)
  static Set<String> _disabledTags = {};
  static bool _suppressImages = true;
  static LogMode _currentMode = LogMode.normal;

  /// Returns true when the active log mode is [LogMode.extreme].
  /// Callers use this to gate high-frequency per-page / per-segment logging
  /// that would flood the log in normal operation (e.g. every page
  /// downloaded in `download_provider.dart`).
  static bool get isExtremeMode => _currentMode == LogMode.extreme;

  // ── Live broadcast + ring buffer for the in-app overlay viewer ───────────
  // The broadcast stream re-emits every formatted log line so any UI (the
  // Logs screen or the floating Log Overlay) can subscribe and render in
  // real time. The ring buffer keeps the last N lines so a freshly opened
  // overlay shows recent context immediately.
  static final StreamController<String> _liveCtrl =
      StreamController<String>.broadcast();
  static const int _ringSize = 500;
  static final Queue<String> _ring = ListQueue<String>(_ringSize);

  /// Subscribe to live log entries. Always available, even before init() —
  /// so the overlay can be opened immediately at app startup.
  static Stream<String> get liveStream => _liveCtrl.stream;

  /// Snapshot of the most recent in-memory log lines (oldest → newest).
  static List<String> recentEntries() => List<String>.unmodifiable(_ring);

  /// Wipe the in-memory ring buffer (used by the overlay's "clear" action).
  static void clearRing() => _ring.clear();

  /// Always log — even before init() — to the in-memory ring + live stream.
  /// Useful for very-early startup messages (DB open, migrations, etc.) that
  /// should still be visible in the overlay even if the file logger isn't
  /// ready yet.
  static void _emitToLive(String entry) {
    if (_ring.length >= _ringSize) _ring.removeFirst();
    _ring.add(entry);
    if (!_liveCtrl.isClosed) {
      _liveCtrl.add(entry);
    }
  }

  /// Absolute path of the current session log file (one new file per app
  /// launch). Exposed so the in-app log viewer / overlay can offer a
  /// "download / share this session's log" action.
  static String? _currentSessionPath;
  static String? get currentSessionPath => _currentSessionPath;

  /// Folder where all per-session log files live (`<storage>/logs_sessions/`).
  static String? _sessionsDirPath;
  static String? get sessionsDirPath => _sessionsDirPath;

  static Future<void> init() async {
    final enabled = isar.settings.getSync(227)?.enableLogs ?? false;
    if (!enabled) return;

    await _loadSettings();

    final storage = StorageProvider();
    final directory = await storage.getDefaultDirectory();

    // ── New: one log file PER session, kept in `<storage>/logs_sessions/`.
    // Old `logs.txt` / `logs.bak.txt` files are left in place for backwards
    // compatibility with anything that already references them — but every
    // new app launch writes to its own file `session_<yyyy-MM-dd_HH-mm-ss>.log`.
    final sessionsDir = Directory(path.join(directory!.path, 'logs_sessions'));
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }
    _sessionsDirPath = sessionsDir.path;

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    _logFile = File(path.join(sessionsDir.path, 'session_$stamp.log'));
    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }
    _currentSessionPath = _logFile.path;

    // Best-effort retention: keep at most the 30 most recent session files.
    // Anything older is deleted silently so the storage footprint stays
    // bounded even for users that launch the app many times a day.
    try {
      final files = await sessionsDir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      for (var i = 30; i < files.length; i++) {
        try {
          await files[i].delete();
        } catch (_) {}
      }
    } catch (_) {}

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

      // Load the current log mode so isExtremeMode reflects the user's choice.
      final modeIndex = box.get(kLogMode, defaultValue: 0) as int;
      _currentMode = LogMode.values[modeIndex.clamp(0, LogMode.values.length - 1)];

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
        LogTag.watch: kLogTagWatch,
        LogTag.maintenance: kLogTagMaint,
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

    final formatted = entry.toString();
    if (kDebugMode) debugPrint(formatted);
    _logQueue.add(formatted);
    // Mirror to in-memory ring + live broadcast for the overlay viewer.
    _emitToLive(formatted);
  }

  static String _timestamp() {
    final now = DateTime.now();
    // Sortable ISO-like format with milliseconds: 2026-04-21 13:42:43.142
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  static Future<void> dispose() async {
    if (!_initialized) return;
    await _logQueue.close();
    await _liveCtrl.close();
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
  static const nav = 'NAV';
  static const manga = 'MANGA';
  static const page = 'PAGE';
  static const hls = 'HLS';
  static const install = 'INSTALL';
  static const reader = 'READER';
  static const search = 'SRCH';
  static const watch = 'WATCH';
  static const maintenance = 'MAINT';
}
