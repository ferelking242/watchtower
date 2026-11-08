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
const kLogTagImg = 'log_tag_img';
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
          kLogTagImg: true,
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
          kLogTagImg: true,
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
          kLogTagImg: true,
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
          kLogTagImg: true,
        };
    }
  }
}

class AppLogger {
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
  static void Function(String payload)? _workerLogForwarder;

  /// The user's "Logs" switch (À propos > Développeur). When it is off the
  /// whole pipeline is skipped at the top of [log] — no sanitisation, no
  /// formatting, no ring push, no broadcast, no console write. Callers run
  /// this on hot paths (per-frame watchdogs, download progress, extension
  /// workers), so a disabled switch must cost a single bool read.
  static bool _loggingEnabled = true;
  static bool get loggingEnabled => _loggingEnabled;
  static void setLoggingEnabled(bool enabled) => _loggingEnabled = enabled;

  /// Routes structured worker-isolate logs to the root isolate.
  /// The root isolate owns the persistent file sink and applies the user's
  /// active log filters.
  static void setWorkerLogForwarder(void Function(String payload)? forwarder) {
    _workerLogForwarder = forwarder;
  }

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

  // ── Flood budget (what keeps Verbose/Extreme from freezing the UI) ────────
  // Every accepted entry costs sanitisation (3 regex passes) + formatting + a
  // ring push and, while the overlay or the Logs page is open, one frame of
  // rebuilding. A chatty extension or a download in Extreme mode can emit
  // thousands of lines per second, enough to starve the UI isolate.
  //
  // Debug/Info lines are therefore capped per second. Warning/Error always
  // pass: a real failure must never disappear because of the cap. Discarded
  // lines are counted and reported, so a truncated log is never silent.
  static const int _kFloodLimitPerSecond = 400;
  static final Stopwatch _floodWindow = Stopwatch()..start();
  static int _floodCount = 0;
  static int _floodDropped = 0;

  /// Number of Debug/Info entries dropped by the flood budget since the last
  /// report. Exposed for diagnostics and the in-app log tools.
  static int get droppedByFloodBudget => _floodDropped;

  /// Returns false when this Debug/Info entry must be skipped to protect the
  /// UI isolate. Refills the window lazily, so no periodic timer is kept alive
  /// just for logging.
  static bool _allowThroughFloodBudget(LogLevel level) {
    if (level.index >= LogLevel.warning.index) return true;
    if (_floodWindow.elapsedMilliseconds >= 1000) {
      _floodWindow.reset();
      _floodCount = 0;
      if (_floodDropped > 0) {
        final dropped = _floodDropped;
        _floodDropped = 0;
        final summary =
            '[${_timestamp()}][${LogLevel.warning.label}] [LOG] '
            '$dropped lignes supprimées (plafond '
            '$_kFloodLimitPerSecond/s) — le mode de log est plus bavard que '
            'ce que l\'app peut afficher sans ralentir.';
        _emitToLive(summary);
        if (_initialized) _queueFileWrite(summary);
      }
    }
    if (_floodCount < _kFloodLimitPerSecond) {
      _floodCount++;
      return true;
    }
    _floodDropped++;
    return false;
  }

  /// The user's active file/log-viewer filters. Shared with extension workers
  /// so a noisy worker stops forwarding records the root isolate would discard
  /// anyway (see [applyWorkerFilterSnapshot]).
  static Map<String, Object?> get workerFilterSnapshot => {
    'minLevel': _minLevel,
    'disabledTags': _disabledTags.toList(growable: false),
    'suppressImages': _suppressImages,
  };

  /// Applies a filter snapshot sent by the root isolate. Called from a worker
  /// isolate's message loop; never throws on a malformed payload.
  static void applyWorkerFilterSnapshot(Object? snapshot) {
    if (snapshot is! Map) return;
    final minLevel = snapshot['minLevel'];
    if (minLevel is int) _minLevel = minLevel;
    final disabled = snapshot['disabledTags'];
    if (disabled is List) {
      _disabledTags = disabled.whereType<String>().toSet();
    }
    final suppressImages = snapshot['suppressImages'];
    if (suppressImages is bool) _suppressImages = suppressImages;
  }

  static void Function(Map<String, Object?> snapshot)? _logFilterBroadcaster;

  /// Registers the root-isolate transport used to push filter changes to the
  /// extension workers (see `GetIsolateService`).
  static void setLogFilterBroadcaster(
    void Function(Map<String, Object?> snapshot)? broadcaster,
  ) {
    _logFilterBroadcaster = broadcaster;
  }

  static void _broadcastLogFilters() {
    final broadcaster = _logFilterBroadcaster;
    if (broadcaster == null) return;
    try {
      broadcaster(workerFilterSnapshot);
    } catch (_) {
      // A worker that cannot be reached keeps its previous filters.
    }
  }

  /// True when an entry would be written to the session file given the active
  /// level, tag and image-suppression filters. Kept allocation-free: called on
  /// the hot path before any formatting work.
  static bool _passesLogFilters(LogLevel level, String? tag, String message) {
    if (level.index < _minLevel) return false;
    if (tag != null && _disabledTags.contains(tag) && level != LogLevel.error) {
      return false;
    }
    if (_suppressImages &&
        level == LogLevel.error &&
        (message.contains('Failed to load') || message.contains('Bad state'))) {
      return false;
    }
    return true;
  }

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

  /// Absolute path of today's log file (`<storage>/Watchtower/logs/YYYY-MM-DD.log`).
  /// Multiple sessions on the same calendar day append to the same file.
  /// Exposed so the in-app log viewer can offer a "share log" action.
  static String? _currentSessionPath;
  static String? get currentSessionPath => _currentSessionPath;

  /// Folder where daily log files live (`<storage>/Watchtower/logs/`).
  static String? _sessionsDirPath;
  static String? get sessionsDirPath => _sessionsDirPath;

  static Future<void> init() async {
    // File logging writes only while the user's "Logs" switch (À propos >
    // Développeur) is on. The caller reads the switch and passes it through
    // [setLoggingEnabled] before calling this, so a cold start with logging
    // off does not create a sink, scan the logs directory or write a session
    // header for a file that stays empty.
    await _bootstrapVerboseDownloadDiagnostics();
    await _loadSettings();
    if (!_loggingEnabled) return;
    log(
      'Diagnostic logging ready: mode=${_currentMode.displayName}',
      tag: LogTag.download,
    );

    final storage = StorageProvider();
    final directory = await storage.getDefaultDirectory();

    // Daily log file in `<storage>/Watchtower/logs/YYYY-MM-DD.log`.
    // A new file is created for each calendar day; sessions within the same
    // day append to the same file so nothing is lost between app launches.
    final sessionsDir = Directory(path.join(directory!.path, 'logs'));
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

    await _writeSessionHeader();
    await flush();
  }

  // ── Buffered file sink ────────────────────────────────────────────────────
  // Writing used to chain one Future per entry and, worse, run
  // `parent.create(recursive: true)` + `exists()` for **every** single line.
  // At Verbose/Extreme rates (extension workers log every request, downloads
  // log every segment) that is two filesystem stat calls plus a microtask per
  // line on the same isolate that renders the UI — the exact load that makes
  // the app stutter while a download or an extension runs.
  //
  // Entries are now appended to an in-memory buffer drained in batches: at once
  // when it reaches [_kLogBatchChars], otherwise at most [_kLogFlushInterval]
  // later. Ordering is preserved, memory stays bounded and the hot path
  // performs no I/O at all. The recovery path (folder or file deleted while the
  // app runs, sink closed by a hot restart) now runs only when a write
  // actually fails instead of on every line.
  static final List<String> _pendingLines = <String>[];
  static int _pendingChars = 0;
  static Timer? _logFlushTimer;
  static Future<void> _fileWriteQueue = Future<void>.value();

  static const int _kLogBatchChars = 48 * 1024;
  static const Duration _kLogFlushInterval = Duration(milliseconds: 400);

  static void _queueFileWrite(String entry) {
    _pendingLines.add(entry);
    _pendingChars += entry.length + 1;
    if (_pendingChars >= _kLogBatchChars) {
      // A burst (download in Extreme mode) must not sit in RAM waiting for the
      // timer: drain now, still as a single write.
      _logFlushTimer?.cancel();
      _logFlushTimer = null;
      unawaited(_drainPendingLines());
      return;
    }
    _logFlushTimer ??= Timer(_kLogFlushInterval, () {
      _logFlushTimer = null;
      unawaited(_drainPendingLines());
    });
  }

  /// Joins the buffered entries into one batch and appends it to the session
  /// file. Batches are serialised through [_fileWriteQueue] so entries can
  /// never interleave on disk.
  static Future<void> _drainPendingLines() {
    if (_pendingLines.isEmpty) return _fileWriteQueue;
    final batch = '${_pendingLines.join('\n')}\n';
    _pendingLines.clear();
    _pendingChars = 0;
    _fileWriteQueue = _fileWriteQueue
        .then((_) => _appendToLogFile(batch))
        .catchError((Object _) {});
    return _fileWriteQueue;
  }

  /// Waits for all queued entries to reach the current log file.
  /// Call before exporting or sharing logs so the latest failures are included.
  static Future<void> flush() async {
    _logFlushTimer?.cancel();
    _logFlushTimer = null;
    await _drainPendingLines();
    await _fileWriteQueue;
    if (!_initialized) return;
    try {
      await _sink.flush();
    } catch (_) {
      // Keep the in-memory logs available if the file sink has been closed.
    }
  }

  /// Appends one batch, recreating the folder, file and sink if they went away
  /// while the app was running.
  static Future<void> _appendToLogFile(String batch) async {
    try {
      _sink.write(batch);
    } catch (_) {
      try {
        await _reopenLogSink();
        _sink.write(batch);
      } catch (_) {
        // Entries remain available in the in-memory ring and live stream.
      }
    }
  }

  static Future<void> _reopenLogSink() async {
    try {
      await _sink.flush();
    } catch (_) {
      // A deleted or already-closed sink is replaced below.
    }
    try {
      await _sink.close();
    } catch (_) {
      // Same: the sink is unusable, a fresh one is opened below.
    }
    await _logFile.parent.create(recursive: true);
    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }
    _sink = _logFile.openWrite(mode: FileMode.append);
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
        LogTag.image: kLogTagImg,
        LogTag.repo: kLogTagExt, // REPO shares the EXT toggle
      };
      for (final entry in tagMap.entries) {
        final defaultEnabled = _currentMode.defaultTags[entry.value] ?? true;
        final enabled =
            box.get(entry.value, defaultValue: defaultEnabled) as bool;
        if (!enabled) disabled.add(entry.key);
      }
      _disabledTags = disabled;
      // Workers mirror the root filters so they stop forwarding noise.
      _broadcastLogFilters();
    } catch (_) {}
  }

  static Future<void> _writeSessionHeader() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final now = _timestamp();
      _queueFileWrite(
        '\n── Session $now · v${info.version}+${info.buildNumber} ──────────────',
      );
    } catch (_) {
      _queueFileWrite('\n── Session ${_timestamp()} ──');
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
    // 0. Master switch. When logging is disabled in À propos > Développeur,
    //    nothing below (flood budget, worker hop, sanitisation, formatting,
    //    ring/broadcast, console) is worth paying for on a hot path.
    if (!_loggingEnabled) return;

    // 1. Cheapest gate first: a Debug/Info flood is dropped before it reaches
    //    sanitisation, formatting, the ring buffer or a widget rebuild.
    if (!_allowThroughFloodBudget(logLevel)) return;

    // 2. Inside an extension worker a record exists only to be forwarded: drop
    //    the ones the root isolate would discard anyway, before sanitising,
    //    encoding them as JSON and paying the isolate hop.
    final workerForwarder = _workerLogForwarder;
    if (workerForwarder != null &&
        !_passesLogFilters(logLevel, tag, message)) {
      return;
    }

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
      entry.write('\n  Stack:\n  ${lines.join('\n  ')}');
    }

    final formatted = entry.toString();

    if (workerForwarder != null) {
      try {
        workerForwarder(
          jsonEncode({
            'message': safeMessage,
            'level': logLevel.index,
            'tag': tag,
            'error': error == null ? null : sanitizeLogText(error.toString()),
            'stackTrace': stackTrace == null
                ? null
                : sanitizeLogText(stackTrace.toString()),
          }),
        );
      } catch (_) {
        // Worker logs must never interrupt the request being diagnosed.
      }
    }

    // The ntfy topic is public; send only a generic signal and keep the
    // diagnostic message and stack trace in local logs.
    if (logLevel == LogLevel.error && workerForwarder == null) {
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
    if (!_passesLogFilters(logLevel, tag, safeMessage)) return;

    _queueFileWrite(formatted);
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
    await flush();
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
  static const image = 'IMG';
}
