import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/utils/constant.dart';

// ─── Log Settings Keys (Hive box: advanced_settings) ──────────────────────────
const _kLogBox = 'advanced_settings';
const kLogMinLevel = 'log_min_level';
const kLogMode = 'log_mode';
const kLogTagExt = 'log_tag_ext';
const kLogTagDl = 'log_tag_dl';
const kLogTagNet = 'log_tag_net';
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
          kLogTagUi: false, kLogTagManga: false,
          kLogTagPage: false, kLogTagHls: false, kLogTagInstall: true,
          kLogTagReader: false, kLogTagWatch: false, kLogTagMaint: true,
        };
      case LogMode.verbose:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: false, kLogTagWatch: true, kLogTagMaint: true,
        };
      case LogMode.debug:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: false, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true, kLogTagWatch: true, kLogTagMaint: true,
        };
      case LogMode.extreme:
        return {
          kLogTagExt: true, kLogTagDl: true, kLogTagNet: true,
          kLogTagUi: true, kLogTagManga: true,
          kLogTagPage: true, kLogTagHls: true, kLogTagInstall: true,
          kLogTagReader: true, kLogTagWatch: true, kLogTagMaint: true,
        };
    }
  }
}

class AppLogger {
  static final _logQueue = StreamController<String>();
  static File? _logFile;
  // dynamic to accept both dart:io.IOSink (native) and stub IOSink (web)
  static dynamic _sink;
  static bool _initialized = false;
  static bool _queueListenerAttached = false;

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

  /// Public getter so interceptors can read the image-suppression flag.
  static bool get suppressImages => _suppressImages;

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

  /// Throttle guard for [_pushToNtfy] — avoids flooding the phone with a
  /// notification storm when the same error repeats every frame (e.g. a
  /// build-method exception firing on every rebuild).
  static DateTime? _lastNtfyPush;
  static const _ntfyThrottle = Duration(seconds: 8);

  /// Fire-and-forget: sends ERROR-level log entries to the same ntfy topic
  /// used for CI build notifications, so a crash on-device reaches the
  /// phone as a push notification with the full message + stack — no PC,
  /// no adb, no DevTools required to see what broke.
  static void _pushToNtfy(String formatted) {
    final now = DateTime.now();
    if (_lastNtfyPush != null &&
        now.difference(_lastNtfyPush!) < _ntfyThrottle) {
      return;
    }
    _lastNtfyPush = now;
    // Never let a notification failure crash the app or block the caller.
    Future(() async {
      try {
        await http
            .post(
              Uri.parse('https://ntfy.sh/watchtower'),
              headers: const {
                'Title': 'Watchtower crash',
                'Priority': 'high',
                'Tags': 'boom',
              },
              body: utf8.encode(
                formatted.length > 3800
                    ? formatted.substring(0, 3800)
                    : formatted,
              ),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline or ntfy unreachable — the error is still in the in-app
        // log viewer/overlay, nothing more to do here.
      }
    });
  }

  /// Absolute path of today's log file (`<storage>/Watchtower/logs/YYYY-MM-DD.log`).
  /// Multiple sessions on the same calendar day append to the same file.
  /// Exposed so the in-app log viewer can offer a "share log" action.
  static String? _currentSessionPath;
  static String? get currentSessionPath => _currentSessionPath;

  /// Folder where daily log files live (`<storage>/Watchtower/logs/`).
  static String? _sessionsDirPath;
  static String? get sessionsDirPath => _sessionsDirPath;

  static Future<void> init() async {
    if (_initialized) return;

    // File logging is always enabled — regardless of the enableLogs setting.
    // One daily file per calendar day, appended across sessions (never reset).
    // Location: <storage>/Watchtower/logs/YYYY-MM-DD.log
    // The enableLogs setting now only controls the in-app log-viewer filters.
    await _loadSettings();

    if (kIsWeb) return;

    // Do not request Permission.storage here. On modern Android it is
    // deprecated/non-applicable and a denied result used to return before
    // creating any file. StorageProvider already falls back to an app-scoped
    // directory when shared storage is unavailable.
    final candidates = <Directory>[];
    // Try the user-visible shared folder first. This is the canonical Android
    // location requested by the app; when Android refuses access, the
    // app-scoped candidate below still preserves every log entry.
    if (Platform.isAndroid) {
      candidates.add(const Directory('/storage/emulated/0/watchtower/logs'));
    }
    try {
      final directory = await StorageProvider().getDefaultDirectory();
      if (directory != null) {
        candidates.add(Directory(path.join(directory.path, 'logs')));
      }
    } catch (e, st) {
      debugPrint('[AppLogger] shared log directory unavailable: $e\n$st');
    }
    try {
      final support = await getApplicationSupportDirectory();
      candidates.add(Directory(path.join(support.path, 'Watchtower', 'logs')));
    } catch (e, st) {
      debugPrint('[AppLogger] app support log directory unavailable: $e\n$st');
    }

    for (final sessionsDir in candidates) {
      try {
        await sessionsDir.create(recursive: true);
        final now = DateTime.now();
        String two(int n) => n.toString().padLeft(2, '0');
        final dateOnly = '${now.year}-${two(now.month)}-${two(now.day)}';
        final logFile = File(path.join(sessionsDir.path, '$dateOnly.log'));
        if (!await logFile.exists()) {
          await logFile.create(recursive: true);
        }
        _logFile = logFile;
        _sessionsDirPath = sessionsDir.path;
        _currentSessionPath = logFile.path;
        _sink = logFile.openWrite(mode: FileMode.append);
        break;
      } catch (e, st) {
        debugPrint('[AppLogger] cannot open ${sessionsDir.path}: $e\n$st');
      }
    }

    if (_sink == null || _logFile == null) {
      debugPrint('[AppLogger] no writable log directory found');
      return;
    }

    // Delete log files older than 30 days.
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      await for (final e in Directory(_sessionsDirPath!).list()) {
        if (e is File && e.path.endsWith('.log')) {
          try {
            final stat = await e.stat();
            if (stat.modified.isBefore(cutoff)) await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    _initialized = true;

    if (!_queueListenerAttached) {
      _queueListenerAttached = true;
      _logQueue.stream.listen((entry) {
        if (!_initialized || _sink == null) return;
        try {
          _sink.writeln(entry);
          // Flush urgent entries so crash context survives process kills
          // without forcing a filesystem sync for every debug line.
          if (entry.contains('][ERROR]')) {
            final Future<void> flush = _sink.flush();
            unawaited(flush);
          }
        } catch (_) {
          // Entries remain available in _ring and _liveCtrl.
        }
      });
    }

    await _writeSessionHeader();
  }

  /// Returns all retained log files, oldest first. The hidden `.dev` folder
  /// remains a read-only legacy fallback for logs written by older builds.
  static Future<List<File>> listLogFiles() async {
    if (kIsWeb) return [];
    final directories = <String>{};
    if (_sessionsDirPath != null) directories.add(_sessionsDirPath!);
    try {
      final base = await StorageProvider().getDefaultDirectory();
      if (base != null) {
        directories.add(path.join(base.path, 'logs'));
        directories.add(path.join(base.path, '.dev'));
      }
    } catch (_) {}

    final files = <File>[];
    for (final directoryPath in directories) {
      try {
        final directory = Directory(directoryPath);
        if (!await directory.exists()) continue;
        await for (final entry in directory.list()) {
          if (entry is File && entry.path.endsWith('.log')) files.add(entry);
        }
      } catch (_) {}
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Reads all retained sessions for the viewer and export actions.
  static Future<String?> readAllLogs() async {
    final files = await listLogFiles();
    if (files.isEmpty) return null;
    final chunks = <String>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        if (content.isNotEmpty) chunks.add(content);
      } catch (_) {}
    }
    if (chunks.isEmpty) return null;
    return chunks.join('\n');
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
      final now = _timestamp();
      _logQueue.add(
        '\n── Session $now · v${info.version}+${info.buildNumber} ──────────────',
      );
    } catch (_) {
      _logQueue.add('\n── Session ${_timestamp()} ──');
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

    // Remote crash reporting — pushes ERROR-level entries to ntfy so they
    // reach the phone as a notification without needing a PC/adb/DevTools
    // to read logcat. Fire-and-forget, throttled, never blocks/crashes on
    // its own failure (no network, ntfy down, etc.).
    if (logLevel == LogLevel.error) {
      _pushToNtfy(formatted);
    }

    // ALWAYS push to the in-memory ring + live broadcast so the floating
    // overlay and log viewer's in-memory fallback always work, even when
    // file logging is disabled (enableLogs = false).
    _emitToLive(formatted);

    if (kDebugMode) debugPrint(formatted);

    // Gate file writing on full initialisation (requires enableLogs = true).
    if (!_initialized) return;

    // Apply file-writing filters (level, tags, image suppression).
    if (logLevel.index < _minLevel) return;
    if (tag != null && _disabledTags.contains(tag) && logLevel != LogLevel.error) return;
    if (_suppressImages &&
        logLevel == LogLevel.error &&
        (message.contains('Failed to load') ||
            message.contains('Bad state'))) {
      return;
    }

    _logQueue.add(formatted);
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
    _initialized = false;
    final sink = _sink;
    _sink = null;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
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
