/// On-disk record of a running app session.
///
/// Android ends Watchtower in ways Dart never observes: an ANR takes the
/// process down with SIGKILL, and a native heap abort (`Scudo ERROR: corrupted
/// chunk header`) aborts it from inside a plugin. Both stop the Dart runtime
/// instantly, so the next launch can only tell "the user swiped the app away"
/// from "the app died" by comparing a marker written while running with the
/// state it was left in.
library;

import 'dart:convert';

/// How the previous session ended, as seen from the next launch.
enum SessionEndKind {
  /// First launch, or the marker could not be read.
  unknown,

  /// The previous session reached a graceful shutdown.
  clean,

  /// The process disappeared while in the background. That is what the system
  /// does under memory pressure or when the task is swiped away, not an app
  /// defect.
  backgroundKill,

  /// The process disappeared while the app was on screen: an ANR kill or a
  /// native abort.
  foregroundCrash,
}

class SessionMarker {
  const SessionMarker({
    required this.startedAt,
    this.route = '/',
    this.foreground = true,
    this.clean = false,
    this.memoryPressure = false,
    this.lastBeatAt,
    this.uncleanStreak = 0,
  });

  final DateTime startedAt;
  final String route;
  final bool foreground;
  final bool clean;
  final bool memoryPressure;
  final DateTime? lastBeatAt;

  /// Consecutive sessions that ended without a clean shutdown.
  final int uncleanStreak;

  SessionMarker copyWith({
    String? route,
    bool? foreground,
    bool? clean,
    bool? memoryPressure,
    DateTime? lastBeatAt,
    int? uncleanStreak,
  }) {
    return SessionMarker(
      startedAt: startedAt,
      route: route ?? this.route,
      foreground: foreground ?? this.foreground,
      clean: clean ?? this.clean,
      memoryPressure: memoryPressure ?? this.memoryPressure,
      lastBeatAt: lastBeatAt ?? this.lastBeatAt,
      uncleanStreak: uncleanStreak ?? this.uncleanStreak,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'startedAt': startedAt.toIso8601String(),
        'route': route,
        'foreground': foreground,
        'clean': clean,
        'memoryPressure': memoryPressure,
        'lastBeatAt': lastBeatAt?.toIso8601String(),
        'uncleanStreak': uncleanStreak,
      };

  /// Returns null when [raw] is not a marker this version understands.
  static SessionMarker? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rawStart = decoded['startedAt'];
      if (rawStart is! String) return null;
      final startedAt = DateTime.tryParse(rawStart);
      if (startedAt == null) return null;
      final beat = decoded['lastBeatAt'];
      final streak = decoded['uncleanStreak'];
      return SessionMarker(
        startedAt: startedAt,
        route: decoded['route'] is String ? decoded['route'] as String : '/',
        foreground: decoded['foreground'] != false,
        clean: decoded['clean'] == true,
        memoryPressure: decoded['memoryPressure'] == true,
        lastBeatAt: beat is String ? DateTime.tryParse(beat) : null,
        uncleanStreak: streak is int ? streak : 0,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Decides how the previous session ended.
SessionEndKind classifyExit(SessionMarker? previous) {
  if (previous == null) return SessionEndKind.unknown;
  if (previous.clean) return SessionEndKind.clean;
  return previous.foreground
      ? SessionEndKind.foregroundCrash
      : SessionEndKind.backgroundKill;
}
