import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

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
const kLogNtfyEnabled = 'log_ntfy_enabled';
const _kVerboseDownloadBootstrap = 'verbose_download_diagnostics_v1';

final _sensitiveLogFieldPattern = RegExp(
  r'\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key|'
  r'x-auth-token|x-access-token|x-refresh-token|api[_-]?key|'
  r'access[_-]?token|refresh[_-]?token|token)\b'
  r'(\s*[:=]\s*)([^\r\n,}\]]+)',
  caseSensitive: false,
);
final _filePathFieldPattern = RegExp(
  r"""(\b(?:path|file(?:name|path)?)\s*[:=]\s*['"]?)([^'"\r\n,)]+)""",
  caseSensitive: false,
);
final _logUrlPattern = RegExp(
  r'https?://[^\s<>"\)\]\},]+',
  caseSensitive: false,
);

/// Remove credentials and request-specific URL data before logs reach the
/// overlay, session file, debug console, or remote error notifications.
String sanitizeLogText(String input) {
  // URLs are reduced first so signed query strings and fragments disappear
  // as a unit, rather than leaving part of a redaction marker in the URL.
  final withoutUrls = input.replaceAllMapped(_logUrlPattern, (match) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null || uri.host.isEmpty) return 'https://[redacted-url]';
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final query = uri.hasQuery ? '?[REDACTED]' : '';
    final fragment = uri.hasFragment ? '#[REDACTED]' : '';
    return '${uri.scheme}://$host$port/[redacted-path]$query$fragment';
  });
  final withoutCredentials = withoutUrls.replaceAllMapped(
    _sensitiveLogFieldPattern,
    (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
  );
  final withoutFilePaths = withoutCredentials.replaceAllMapped(
    _filePathFieldPattern,
    (match) => '${match.group(1)}[redacted-path]',
  );
  return withoutFilePaths;
}

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
          kLogTagExt: true,
          kLogTagDl: false,
          kLogTagNet: false,
          kLogTagUi: false,
          kLogTagManga: false,
          kLogTagPage: false,
          kLogTagHls: false,
          kLogTagInstall: true,
          kLogTagReader: false,
          kLogTagWatch: false,
          kLogTagMaint: true,
        };
      case LogMode.verbose:
        return {
          kLogTagExt: true,
          kLogTagDl: true,
          kLogTagNet: true,
          kLogTagUi: true,
          kLogTagManga: true,
          kLogTagPage: false,
          kLogTagHls: true,
          kLogTagInstall: true,
          kLogTagReader: false,
          kLogTagWatch: true,
          kLogTagMaint: true,
        };
      case LogMode.debug:
        return {
          kLogTagExt: true,
          kLogTagDl: true,
          kLogTagNet: true,
          kLogTagUi: true,
          kLogTagManga: true,
          kLogTagPage: false,
          kLogTagHls: true,
          kLogTagInstall: true,
          kLogTagReader: true,
          kLogTagWatch: true,
          kLogTagMaint: true,
        };
      case LogMode.extreme:
        return {
          kLogTagExt: true,
          kLogTagDl: true,
          kLogTagNet: true,
          kLogTagUi: true,
          kLogTagManga: true,
          kLogTagPage: true,
          kLogTagHls: true,
          kLogTagInstall: true,
          kLogTagReader: true,
          kLogTagWatch: true,
          kLogTagMaint: true,
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
  static bool _ntfyEnabled = true;
  static LogMode _currentMode = LogMode.verbose;

  /// Returns true when the active log mode is [LogMode.extreme].
  /// Callers use this to gate high-frequency per-page / per-segment logging
  /// that would flood the log in normal operation (e.g. every page
  /// downloaded in `download_provider.dart`).
  static bool get isExtremeMode => _currentMode == LogMode.extreme;

  /// Public getter so interceptors can read the image-suppression flag.
  static bool get suppressImages => _suppressImages;

  /// Whether error logs push a generic signal to the public ntfy topic.
  static bool get ntfyEnabled => _ntfyEnabled;

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

  /// Fire-and-forget generic signal only. The topic is public, so log messages,
  /// URLs, paths, and stack traces must remain in the local log viewer.
  static void _pushToNtfy() {
    if (!_ntfyEnabled) return;
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
                'Title': 'Watchtower error',
                'Priority': 'default',
                'Tags': 'warning',
              },
              body: utf8.encode(
                'Watchtower encountered an error. Open the in-app logs for details.',
              ),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline or ntfy unreachable — the error is still in the in-app
        // log viewer/overlay, nothing more to do here.
      }
    });
  }

  /// Absolute path of today's log file (`<storage>/Watchtower/.dev/YYYY-MM-DD.log`).
  /// Multiple sessions on the same calendar day append to the same file.
  /// Exposed so the in-app log viewer can offer a "share log" action.
  static String? _currentSessionPath;
  static String? get currentSessionPath => _currentSessionPath;

  /// Folder where daily log files live (`<storage>/Watchtower/.dev/`).
  static String? _sessionsDirPath;
  static String? get sessionsDirPath => _sessionsDirPath;

  static Future<void> init() async {
    // File logging is always enabled — regardless of the enableLogs setting.
    // One daily file per calendar day, appended across sessions (never reset).
    // Location: <storage>/Watchtower/.dev/YYYY-MM-DD.log
    // The enableLogs setting now only controls the in-app log-viewer filters.
    await _bootstrapVerboseDownloadDiagnostics();
    await _loadSettings();
    log(
      'Diagnostic logging ready: mode=${_currentMode.displayName}',
      tag: LogTag.download,
    );

    final storage = StorageProvider();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) return;
        }
      } catch (_) {
        // Activity not yet attached (cold start race); skip file logging.
        return;
      }
    }
    final directory = await storage.getDefaultDirectory();

    // Daily log file in `<storage>/Watchtower/.dev/YYYY-MM-DD.log`.
    // A new file is created for each calendar day; sessions within the same
    // day append to the same file so nothing is lost between app launches.
    final sessionsDir = Directory(path.join(directory!.path, '.dev'));
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }
    _sessionsDirPath = sessionsDir.path;

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final dateOnly = '${now.year}-${two(now.month)}-${two(now.day)}';
    _logFile = File(path.join(sessionsDir.path, '$dateOnly.log'));
    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }
    _currentSessionPath = _logFile.path;

    // Delete log files older than 30 days.
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      await for (final e in sessionsDir.list()) {
        if (e is File && e.path.endsWith('.log')) {
          try {
            final stat = await e.stat();
            if (stat.modified.isBefore(cutoff)) await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    _sink = _logFile.openWrite(mode: FileMode.append);
    _initialized = true;

    _logQueue.stream.listen((entry) {
      // Guard against writes to a closed sink.
      // IOSink has no public `isClosed` getter; catch the StateError
      // that is thrown if the underlying file has been closed (e.g. on
      // hot-restart or explicit dispose()), rather than letting the
      // exception propagate into the stream and kill the listener.
      try {
        _sink.writeln(entry);
      } catch (_) {
        // Sink is closed — entries are still available in _ring and _liveCtrl.
      }
    });

    await _writeSessionHeader();
  }

  // Call this after changing settings in the UI to update in-memory filters
  static Future<void> reloadSettings() => _loadSettings();

  /// Persists the ntfy crash-signal toggle and applies it immediately.
  static Future<void> setNtfyEnabled(bool enabled) async {
    _ntfyEnabled = enabled;
    try {
      final box = await Hive.openBox(_kLogBox);
      await box.put(kLogNtfyEnabled, enabled);
    } catch (_) {
      // The in-memory flag still applies for this session.
    }
  }

  /// Existing installs may have Normal mode and download tags disabled. Turn
  /// on Verbose once for this diagnostics rollout, then respect later choices
  /// made in Advanced settings.
  static Future<void> _bootstrapVerboseDownloadDiagnostics() async {
    try {
      final box = await Hive.openBox(_kLogBox);
      if (box.get(_kVerboseDownloadBootstrap, defaultValue: 0) == 1) return;
      await box.put(kLogMode, LogMode.verbose.index);
      await box.put(kLogMinLevel, LogMode.verbose.minLevel);
      for (final entry in LogMode.verbose.defaultTags.entries) {
        await box.put(entry.key, entry.value);
      }
      await box.put(_kVerboseDownloadBootstrap, 1);
    } catch (error) {
      debugPrint('Could not enable verbose download diagnostics.');
    }
  }

  static Future<void> _loadSettings() async {
    try {
      final box = await Hive.openBox(_kLogBox);
      // Load the current log mode so isExtremeMode reflects the user's choice.
      final modeIndex =
          box.get(kLogMode, defaultValue: LogMode.verbose.index) as int;
      _currentMode =
          LogMode.values[modeIndex.clamp(0, LogMode.values.length - 1)];
      _minLevel =
          box.get(kLogMinLevel, defaultValue: _currentMode.minLevel) as int;
      _suppressImages = box.get(kLogSuppressImages, defaultValue: true) as bool;
      _ntfyEnabled = box.get(kLogNtfyEnabled, defaultValue: true) as bool;

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
        final defaultEnabled = _currentMode.defaultTags[entry.value] ?? true;
        final enabled =
            box.get(entry.value, defaultValue: defaultEnabled) as bool;
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
    final safeMessage = sanitizeLogText(message);
    final tagPart = tag != null ? '[$tag] ' : '';
    final entry = StringBuffer(
      '[${_timestamp()}][${logLevel.label}] $tagPart$safeMessage',
    );

    if (error != null) {
      entry.write('\n  Error: ${sanitizeLogText(error.toString())}');
    }

    if (stackTrace != null) {
      final lines = sanitizeLogText(stackTrace.toString()).split('\n');
      final limited = lines.take(12).join('\n  ');
      entry.write('\n  Stack:\n  $limited');
      if (lines.length > 12) {
        entry.write('\n  ... (${lines.length - 12} more lines hidden)');
      }
    }

    final formatted = entry.toString();

    // The ntfy topic is public; send only a generic signal and keep the
    // diagnostic message and stack trace in local logs.
    if (logLevel == LogLevel.error) {
      _pushToNtfy();
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
    if (tag != null &&
        _disabledTags.contains(tag) &&
        logLevel != LogLevel.error) {
      return;
    }
    if (_suppressImages &&
        logLevel == LogLevel.error &&
        (safeMessage.contains('Failed to load') ||
            safeMessage.contains('Bad state'))) {
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
