/// Formatting of the single diagnostic report the user can copy or share.
///
/// Kept free of IO so the layout can be unit-tested; [DiagnosticsService]
/// collects the values and calls [formatDiagnosticsReport].
library;

import 'session_marker.dart';

class DiagnosticsReportData {
  const DiagnosticsReportData({
    required this.generatedAt,
    required this.appVersion,
    required this.appBuild,
    required this.deviceSummary,
    required this.sessionStartedAt,
    required this.sessionUptime,
    required this.currentRoute,
    required this.previousExit,
    required this.previousSession,
    required this.freezeCount,
    required this.longestFreezeMs,
    this.severeEvents = const <String>[],
    this.logTail = const <String>[],
  });

  final DateTime generatedAt;
  final String appVersion;
  final String appBuild;
  final String deviceSummary;
  final DateTime sessionStartedAt;
  final Duration sessionUptime;
  final String currentRoute;
  final SessionEndKind previousExit;
  final SessionMarker? previousSession;
  final int freezeCount;
  final int longestFreezeMs;
  final List<String> severeEvents;
  final List<String> logTail;
}

String formatDiagnosticsReport(DiagnosticsReportData data) {
  final out = StringBuffer()
    ..writeln('Watchtower diagnostics report')
    ..writeln('generated: ${data.generatedAt.toIso8601String()}')
    ..writeln('app: ${data.appVersion} (build ${data.appBuild})')
    ..writeln('device: ${data.deviceSummary}')
    ..writeln(
      'session: started ${data.sessionStartedAt.toIso8601String()}, '
      'up ${_humanDuration(data.sessionUptime)}',
    )
    ..writeln('current route: ${data.currentRoute}')
    ..writeln('previous session: ${describeExit(data.previousExit)}');

  final previous = data.previousSession;
  if (previous != null && data.previousExit != SessionEndKind.clean) {
    out
      ..writeln(
        '  started ${previous.startedAt.toIso8601String()}, '
        'last route ${previous.route}',
      )
      ..writeln(
        '  last heartbeat: '
        '${previous.lastBeatAt?.toIso8601String() ?? 'none'}',
      )
      ..writeln(
        '  memory pressure reported: ${previous.memoryPressure}, '
        'unclean streak: ${previous.uncleanStreak}',
      );
  }

  out.writeln(
    'ui freezes: ${data.freezeCount} '
    '(longest ${data.longestFreezeMs}ms)',
  );

  if (data.severeEvents.isNotEmpty) {
    out.writeln('severe events (most recent last):');
    for (final event in data.severeEvents) {
      out.writeln('  $event');
    }
  }

  if (data.logTail.isNotEmpty) {
    out.writeln('log tail:');
    for (final line in data.logTail) {
      out.writeln('  $line');
    }
  }
  return out.toString();
}

String describeExit(SessionEndKind kind) {
  switch (kind) {
    case SessionEndKind.unknown:
      return 'first launch, nothing to compare';
    case SessionEndKind.clean:
      return 'closed cleanly';
    case SessionEndKind.backgroundKill:
      return 'process killed in background (memory pressure or task swipe)';
    case SessionEndKind.foregroundCrash:
      return 'process died while on screen (ANR kill or native crash)';
  }
}

String _humanDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}
