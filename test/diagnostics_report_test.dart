import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/diagnostics/diagnostics_report.dart';
import 'package:watchtower/services/diagnostics/freeze_detector.dart';
import 'package:watchtower/services/diagnostics/session_marker.dart';

/// The marker is the only thing that lets the next launch tell a crash from a
/// normal exit, so a decode that silently loses the `clean` flag would make the
/// app report a crash on every start — or worse, hide a real one.
void main() {
  group('SessionMarker', () {
    test('round-trips every field', () {
      final marker = SessionMarker(
        startedAt: DateTime.utc(2026, 11, 23, 21, 13, 20),
        route: '/downloads',
        foreground: false,
        clean: true,
        memoryPressure: true,
        lastBeatAt: DateTime.utc(2026, 11, 23, 21, 14),
        uncleanStreak: 2,
      );

      final decoded = SessionMarker.decode(marker.encode());

      expect(decoded, isNotNull);
      expect(decoded!.startedAt, marker.startedAt);
      expect(decoded.route, '/downloads');
      expect(decoded.foreground, isFalse);
      expect(decoded.clean, isTrue);
      expect(decoded.memoryPressure, isTrue);
      expect(decoded.lastBeatAt, marker.lastBeatAt);
      expect(decoded.uncleanStreak, 2);
    });

    test('missing optional fields fall back to a running, foreground session',
        () {
      final decoded = SessionMarker.decode(
        '{"startedAt":"2026-11-23T20:00:00.000Z"}',
      );

      expect(decoded, isNotNull);
      expect(decoded!.route, '/');
      expect(decoded.foreground, isTrue);
      expect(decoded.clean, isFalse);
      expect(decoded.memoryPressure, isFalse);
      expect(decoded.lastBeatAt, isNull);
      expect(decoded.uncleanStreak, 0);
    });

    test('rejects truncated or foreign content', () {
      expect(SessionMarker.decode(''), isNull);
      expect(SessionMarker.decode('{"startedAt":'), isNull);
      expect(SessionMarker.decode('{"route":"/home"}'), isNull);
      expect(SessionMarker.decode('[]'), isNull);
      expect(SessionMarker.decode('{"startedAt":42}'), isNull);
    });

    test('copyWith keeps the identity fields', () {
      final marker = SessionMarker(
        startedAt: DateTime.utc(2026, 11, 23),
        route: '/',
      );

      final moved = marker.copyWith(route: '/settings', clean: true);

      expect(moved.startedAt, marker.startedAt);
      expect(moved.route, '/settings');
      expect(moved.clean, isTrue);
      expect(moved.foreground, isTrue);
    });
  });

  group('classifyExit', () {
    test('no marker means nothing to compare', () {
      expect(classifyExit(null), SessionEndKind.unknown);
    });

    test('a clean marker is a clean exit', () {
      final marker = SessionMarker(
        startedAt: DateTime.utc(2026, 11, 23),
        clean: true,
        foreground: false,
      );
      expect(classifyExit(marker), SessionEndKind.clean);
    });

    test('dying in the foreground is a crash, dying in the background is not',
        () {
      final startedAt = DateTime.utc(2026, 11, 23);
      expect(
        classifyExit(SessionMarker(startedAt: startedAt, foreground: true)),
        SessionEndKind.foregroundCrash,
      );
      expect(
        classifyExit(SessionMarker(startedAt: startedAt, foreground: false)),
        SessionEndKind.backgroundKill,
      );
    });
  });

  group('FreezeDetector', () {
    test('ignores ticks that arrive on schedule', () {
      final detector = FreezeDetector();

      expect(detector.addSample(const Duration(milliseconds: 250)), isNull);
      expect(detector.addSample(const Duration(milliseconds: 500)), isNull);
      expect(detector.addSample(const Duration(milliseconds: 750)), isNull);
    });

    test('reports a tick that arrives after a long block', () {
      final detector = FreezeDetector();

      expect(detector.addSample(const Duration(milliseconds: 250)), isNull);
      // 2.2 s of silence instead of the expected 250 ms.
      expect(
        detector.addSample(const Duration(milliseconds: 2450)),
        const Duration(milliseconds: 1950),
      );
    });

    test('reports a single stall once, then keeps the new schedule', () {
      final detector = FreezeDetector();

      expect(
        detector.addSample(const Duration(seconds: 10)),
        const Duration(milliseconds: 9750),
      );
      expect(
        detector.addSample(const Duration(milliseconds: 10250)),
        isNull,
      );
    });

    test('a small jitter below the threshold is not a freeze', () {
      final detector = FreezeDetector();

      expect(
        detector.addSample(const Duration(milliseconds: 1500)),
        isNull,
      );
    });

    test('reset discards the time spent in the background', () {
      final detector = FreezeDetector();

      detector.reset(const Duration(seconds: 600));
      expect(
        detector.addSample(const Duration(milliseconds: 600250)),
        isNull,
      );
    });
  });

  group('formatDiagnosticsReport', () {
    DiagnosticsReportData data({SessionEndKind? exit, SessionMarker? marker}) {
      return DiagnosticsReportData(
        generatedAt: DateTime.utc(2026, 11, 23, 22),
        appVersion: '1.4.2',
        appBuild: '87',
        deviceSummary: 'Android 15, 7500MB RAM (high)',
        sessionStartedAt: DateTime.utc(2026, 11, 23, 21, 55),
        sessionUptime: const Duration(minutes: 5, seconds: 3),
        currentRoute: '/home',
        previousExit: exit ?? SessionEndKind.clean,
        previousSession: marker,
        freezeCount: 2,
        longestFreezeMs: 2400,
        severeEvents: const ['2026-11-23T21:59:00.000Z ui-freeze: 2400ms'],
        logTail: const ['[21:58:59][WARN] [UI] slow frame'],
      );
    }

    test('summarises version, device, session and stalls', () {
      final report = formatDiagnosticsReport(data());

      expect(report, contains('app: 1.4.2 (build 87)'));
      expect(report, contains('device: Android 15, 7500MB RAM (high)'));
      expect(report, contains('up 5m3s'));
      expect(report, contains('current route: /home'));
      expect(report, contains('previous session: closed cleanly'));
      expect(report, contains('ui freezes: 2 (longest 2400ms)'));
      expect(report, contains('ui-freeze: 2400ms'));
      expect(report, contains('slow frame'));
    });

    test('adds the last route and heartbeat when the previous run died', () {
      final marker = SessionMarker(
        startedAt: DateTime.utc(2026, 11, 23, 21, 13, 20),
        route: '/watch',
        foreground: true,
        lastBeatAt: DateTime.utc(2026, 11, 23, 21, 13, 21),
        uncleanStreak: 3,
      );
      final report = formatDiagnosticsReport(
        data(exit: SessionEndKind.foregroundCrash, marker: marker),
      );

      expect(report, contains('died while on screen'));
      expect(report, contains('last route /watch'));
      expect(report, contains('unclean streak: 3'));
    });

    test('does not repeat the previous session when it closed cleanly', () {
      final marker = SessionMarker(
        startedAt: DateTime.utc(2026, 11, 23),
        route: '/watch',
        clean: true,
      );
      final report = formatDiagnosticsReport(
        data(exit: SessionEndKind.clean, marker: marker),
      );

      expect(report, isNot(contains('last route /watch')));
    });
  });
}
