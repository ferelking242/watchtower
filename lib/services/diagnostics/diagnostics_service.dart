/// Central place for what the daily log cannot answer on its own: did the last
/// run die, where was the app when it happened, and did the UI isolate stall.
///
/// `AppLogger` already writes a sanitised daily file and flushes it within
/// ~120 ms, so the last lines survive a hard kill. What it cannot know is
/// whether the process is *supposed* to be gone, which screen was open, and how
/// long the UI was frozen. This service keeps that state in a small marker file
/// next to the app support directory and turns it into a single report the user
/// can copy from the log viewer.
library;

import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/utils/log/logger.dart';

import 'diagnostics_report.dart';
import 'freeze_detector.dart';
import 'session_marker.dart';

class DiagnosticsService with WidgetsBindingObserver {
  DiagnosticsService._();

  static final DiagnosticsService instance = DiagnosticsService._();

  /// A stall this long is felt as a freeze and is the range where the system
  /// starts to consider an ANR, so it is worth a log line.
  static const Duration freezeThreshold = Duration(milliseconds: 1500);
  static const Duration _watchdogTick = Duration(milliseconds: 250);
  static const Duration _heartbeat = Duration(seconds: 15);
  static const int _maxSevereEvents = 20;

  /// Anything later than this is a suspended process, not a stalled isolate.
  static const Duration _suspendBound = Duration(seconds: 60);
  static const int _logTailLines = 40;

  File? _markerFile;
  SessionMarker? _marker;
  SessionMarker? _previousSession;
  SessionEndKind _previousExit = SessionEndKind.unknown;

  Timer? _watchdog;
  Timer? _routeWriteTimer;
  Stopwatch? _tickClock;
  late final FreezeDetector _freezes = FreezeDetector(
    tick: _watchdogTick,
    threshold: freezeThreshold,
  );
  Duration _sinceHeartbeat = Duration.zero;

  final List<String> _severeEvents = <String>[];
  int _freezeCount = 0;
  int _longestFreezeMs = 0;
  String _route = '/';
  String _appVersion = '?';
  String _appBuild = '?';
  String _deviceSummary = 'unknown device';

  bool _started = false;
  Future<void>? _writeFuture;
  bool _writeRequested = false;

  SessionEndKind get previousExit => _previousExit;
  int get freezeCount => _freezeCount;
  int get longestFreezeMs => _longestFreezeMs;

  /// Starts the marker, reads how the previous session ended and arms the UI
  /// watchdog. Safe to call once; later calls are ignored.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    await _resolveMarkerFile();
    await _describeApp();
    await _describeDevice();
    _previousSession = await _readMarker();
    _previousExit = classifyExit(_previousSession);

    _marker = SessionMarker(
      startedAt: DateTime.now(),
      route: _route,
      foreground: true,
      clean: false,
      uncleanStreak: _previousExit == SessionEndKind.clean ||
              _previousExit == SessionEndKind.unknown
          ? 0
          : (_previousSession?.uncleanStreak ?? 0) + 1,
    );
    await _writeMarker();
    _reportPreviousSession();
    _startWatchdog();
  }

  /// Breadcrumb for the next run: a native abort leaves no Dart stack, so the
  /// screen the user was on is often the only clue.
  void markRoute(String location) {
    if (location.isEmpty || location == _route) return;
    _route = location;
    _marker = _marker?.copyWith(route: location);
    // A tab switch can fire several navigations in a row; one write per burst
    // is enough for a breadcrumb.
    _routeWriteTimer?.cancel();
    _routeWriteTimer = Timer(const Duration(seconds: 2), _writeMarker);
  }

  /// Records an error that already went to the log, so the report shows the
  /// sequence of failures without the user having to scroll a 2000-line file.
  void noteError(String source, Object error) {
    final text = error.toString();
    _severeEvents.add(
      '${DateTime.now().toIso8601String()} $source: '
      '${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
    );
    if (_severeEvents.length > _maxSevereEvents) {
      _severeEvents.removeAt(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _marker = _marker?.copyWith(foreground: true);
        _writeMarker();
        final clock = _tickClock;
        if (clock != null) _freezes.reset(clock.elapsed);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _marker = _marker?.copyWith(foreground: false);
        _writeMarker();
      case AppLifecycleState.detached:
        unawaited(markCleanShutdown());
    }
  }

  /// Writes the "closed cleanly" marker so the next launch does not report a
  /// crash. Called on `detached` and from the app widget's `dispose`.
  Future<void> markCleanShutdown() async {
    if (!_started) return;
    _watchdog?.cancel();
    _watchdog = null;
    _routeWriteTimer?.cancel();
    _routeWriteTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _marker = _marker?.copyWith(clean: true, foreground: false);
    await _writeMarker();
    _started = false;
  }

  DiagnosticsReportData reportData() {
    return DiagnosticsReportData(
      generatedAt: DateTime.now(),
      appVersion: _appVersion,
      appBuild: _appBuild,
      deviceSummary: _deviceSummary,
      sessionStartedAt: _marker?.startedAt ?? DateTime.now(),
      sessionUptime: DateTime.now().difference(
        _marker?.startedAt ?? DateTime.now(),
      ),
      currentRoute: _route,
      previousExit: _previousExit,
      previousSession: _previousSession,
      freezeCount: _freezeCount,
      longestFreezeMs: _longestFreezeMs,
      severeEvents: List<String>.of(_severeEvents),
      logTail: _tail(AppLogger.recentEntries(), _logTailLines),
    );
  }

  String buildReport() => formatDiagnosticsReport(reportData());

  // ── Watchdog ──────────────────────────────────────────────────────────────

  /// What the process looked like when the isolate stopped answering.
  ///
  /// A stall that only names the route cannot be acted on: the same 2 s freeze
  /// looks identical whether the isolate was blocked on one long synchronous
  /// call or starved because four chapter downloads and the kernel were
  /// fighting over the same cores. Resident size separates the two (memory
  /// pressure) and the tail of the log ring says what was running.
  String _stallContext() {
    final buffer = StringBuffer();
    try {
      final rssMb = ProcessInfo.currentRss ~/ (1 << 20);
      buffer.write('rss ${rssMb}MB');
    } catch (_) {
      buffer.write('rss ?');
    }
    final recent = AppLogger.recentEntries();
    if (recent.isNotEmpty) {
      // Two lines are enough to name the concurrent work; the full ring is
      // already on disk for context.
      final tail = recent.length > 2
          ? recent.sublist(recent.length - 2)
          : recent;
      buffer.write(' | after ${tail.map(_condense).join(' / ')}');
    }
    return buffer.toString();
  }

  static String _condense(String entry) {
    // Entries already start with `[timestamp][LEVEL] `; the timestamp is the
    // stall moment itself, so only the payload is worth repeating.
    final cut = entry.indexOf('] ');
    final body = cut >= 0 ? entry.substring(cut + 2) : entry;
    return body.length <= 90 ? body : '${body.substring(0, 90)}…';
  }

  void _startWatchdog() {
    if (_watchdog != null) return;
    final clock = Stopwatch()..start();
    _tickClock = clock;
    _freezes.reset(Duration.zero);
    _watchdog = Timer.periodic(_watchdogTick, (_) => _onTick());
  }

  void _onTick() {
    final clock = _tickClock;
    if (clock == null) return;
    final drift = _freezes.addSample(clock.elapsed);

    if (drift != null && drift > _suspendBound) {
      // Minutes of lateness means the process was suspended (backgrounded or
      // doze), not that the UI isolate was busy. Re-base instead of reporting.
      _freezes.reset(clock.elapsed);
    } else if (drift != null) {
      _freezeCount++;
      final ms = drift.inMilliseconds;
      final stallContext = _stallContext();
      if (ms > _longestFreezeMs) _longestFreezeMs = ms;
      AppLogger.log(
        'UI isolate stalled for ${ms}ms (route $_route, $stallContext)',
        logLevel: LogLevel.warning,
        tag: LogTag.ui,
      );
      noteError('ui-freeze', 'UI isolate stalled for ${ms}ms');
    }

    _sinceHeartbeat += _watchdogTick;
    if (_sinceHeartbeat >= _heartbeat) {
      _sinceHeartbeat = Duration.zero;
      _marker = _marker?.copyWith(lastBeatAt: DateTime.now());
      _writeMarker();
    }
  }

  // ── Marker file ───────────────────────────────────────────────────────────

  Future<SessionMarker?> _readMarker() async {
    final file = _markerFile;
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      return SessionMarker.decode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Coalesces writes: route changes and heartbeats can land while a write is
  /// still running, and only the latest state matters.
  Future<void> _writeMarker() {
    final running = _writeFuture;
    if (running != null) {
      _writeRequested = true;
      return running;
    }
    final future = _drainMarkerWrites();
    _writeFuture = future;
    return future;
  }

  Future<void> _drainMarkerWrites() async {
    final file = _markerFile;
    if (file == null) {
      _writeFuture = null;
      return;
    }
    try {
      do {
        _writeRequested = false;
        final snapshot = _marker;
        if (snapshot == null) break;
        await file.writeAsString(snapshot.encode(), flush: true);
      } while (_writeRequested);
    } catch (error) {
      AppLogger.log(
        'diagnostics marker write failed: $error',
        logLevel: LogLevel.debug,
        tag: LogTag.ui,
      );
    } finally {
      _writeFuture = null;
    }
  }

  Future<void> _resolveMarkerFile() async {
    try {
      final dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'diagnostics'),
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      _markerFile = File(p.join(dir.path, 'session.json'));
    } catch (_) {
      _markerFile = null;
    }
  }

  // ── Startup reporting ─────────────────────────────────────────────────────

  void _reportPreviousSession() {
    final previous = _previousSession;
    final streak = _marker?.uncleanStreak ?? 0;
    switch (_previousExit) {
      case SessionEndKind.unknown:
      case SessionEndKind.clean:
        return;
      case SessionEndKind.backgroundKill:
        AppLogger.log(
          'Previous session ended in the background '
          '(last route ${previous?.route ?? '?'}, '
          'last heartbeat ${previous?.lastBeatAt?.toIso8601String() ?? 'none'}, '
          'streak $streak)',
          logLevel: LogLevel.info,
          tag: LogTag.ui,
        );
      case SessionEndKind.foregroundCrash:
        AppLogger.log(
          'Previous session died while on screen — ANR kill or native abort '
          '(started ${previous?.startedAt.toIso8601String() ?? '?'}, '
          'last route ${previous?.route ?? '?'}, '
          'last heartbeat ${previous?.lastBeatAt?.toIso8601String() ?? 'none'}, '
          'memory pressure ${previous?.memoryPressure}, streak $streak)',
          logLevel: LogLevel.error,
          tag: LogTag.ui,
        );
        noteError('previous-session', describeExit(_previousExit));
    }
  }

  Future<void> _describeApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _appBuild = info.buildNumber;
    } catch (_) {}
  }

  Future<void> _describeDevice() async {
    final memory = DeviceCapabilities.physicalMemoryMB;
    var summary = '${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}';
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        summary = '${info.manufacturer} ${info.model}, '
            'Android ${info.version.release} (sdk ${info.version.sdkInt})';
      } catch (_) {
        summary = 'Android ${Platform.operatingSystemVersion}';
      }
    }
    if (memory > 0) {
      summary = '$summary, ${memory}MB RAM (${DeviceCapabilities.ramTier})';
    }
    _deviceSummary = summary;
  }

  static List<String> _tail(List<String> lines, int count) {
    if (lines.length <= count) return List<String>.of(lines);
    return lines.sublist(lines.length - count);
  }
}
