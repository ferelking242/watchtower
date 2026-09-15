import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/models/wellness_recap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Saturday, so the current week starts on 31 August and holds no August
  // viewing history.
  final earlySeptember = DateTime(2026, 9, 5, 20);

  group('WellnessRecapPeriod', () {
    test('features last month while the month is young', () {
      final sessions = <WellnessViewingSession>[
        _session(id: 'aug', localStart: DateTime(2026, 8, 12, 20)),
      ];

      final featured = WellnessRecapPeriod.featured(sessions, earlySeptember);

      expect(featured.id, 'month-2026-08');
      expect(featured.hasReadyRecap(sessions, earlySeptember), isTrue);
    });

    test('a ready recap outlives an empty selected range', () {
      final sessions = <WellnessViewingSession>[
        _session(id: 'aug-1', localStart: DateTime(2026, 8, 12, 20)),
        _session(id: 'aug-2', localStart: DateTime(2026, 8, 13, 21)),
      ];

      // What the profile card promises.
      final featured = WellnessRecapPeriod.featured(sessions, earlySeptember);
      expect(featured.id, 'month-2026-08');
      expect(featured.hasReadyRecap(sessions, earlySeptember), isTrue);

      // The insights screen opens on this week, which holds nothing...
      final selected = WellnessInsights.fromSessions(
        sessions,
        period: WellnessPeriod.forRange(WellnessRange.week, earlySeptember),
      );
      expect(selected.isEmpty, isTrue);

      // ...so the recap surfaces must key off the history, not the range.
      expect(hasRecapWorthyHistory(sessions), isTrue);
    });

    test('never calls a month still in progress ready', () {
      final now = DateTime(2026, 9, 20, 20);
      final sessions = <WellnessViewingSession>[
        _session(id: 'sep', localStart: DateTime(2026, 9, 18, 20)),
      ];

      final featured = WellnessRecapPeriod.featured(sessions, now);

      expect(featured.id, 'month-2026-09');
      expect(featured.insightsFrom(sessions).isEmpty, isFalse);
      expect(featured.hasReadyRecap(sessions, now), isFalse);
    });

    test('offers a period for every month and year with activity', () {
      final sessions = <WellnessViewingSession>[
        _session(id: 'aug', localStart: DateTime(2026, 8, 12, 20)),
        _session(id: 'jul', localStart: DateTime(2026, 7, 4, 20)),
        _session(id: 'dec', localStart: DateTime(2025, 12, 24, 20)),
      ];

      final ids = WellnessRecapPeriod.available(sessions, earlySeptember)
          .map((period) => period.id)
          .toList(growable: false);

      expect(
        ids,
        containsAll(<String>[
          'month-2026-08',
          'month-2026-07',
          'month-2025-12',
          'year-2026',
          'year-2025',
        ]),
      );
    });

    test('opens on a period with activity when the range has none', () {
      final sessions = <WellnessViewingSession>[
        _session(id: 'dec', localStart: DateTime(2025, 12, 12, 20)),
      ];

      // All time has history, but the year it maps to (2026) is empty.
      expect(
        WellnessRecapPeriod.forRange(WellnessRange.allTime, earlySeptember)
            .insightsFrom(sessions)
            .isEmpty,
        isTrue,
      );

      final best = WellnessRecapPeriod.bestForRange(
        sessions,
        WellnessRange.allTime,
        earlySeptember,
      );

      expect(best.id, 'month-2025-12');
      expect(best.insightsFrom(sessions).isEmpty, isFalse);
    });

    test('keeps the matching period when the range has activity', () {
      final sessions = <WellnessViewingSession>[
        _session(id: 'sep', localStart: DateTime(2026, 9, 1, 20)),
      ];

      final best = WellnessRecapPeriod.bestForRange(
        sessions,
        WellnessRange.month,
        earlySeptember,
      );

      expect(best.id, 'month-2026-09');
    });
  });

  group('hasRecapWorthyHistory', () {
    test('ignores deleted and too-short sessions', () {
      final short = _session(
        id: 'short',
        localStart: DateTime(2026, 8, 12, 20),
        length: const Duration(seconds: 10),
      );
      final removed = _session(
        id: 'removed',
        localStart: DateTime(2026, 8, 13, 20),
        deleted: true,
      );

      expect(hasRecapWorthyHistory(<WellnessViewingSession>[short]), isFalse);
      expect(hasRecapWorthyHistory(<WellnessViewingSession>[removed]), isFalse);
      expect(
        hasRecapWorthyHistory(<WellnessViewingSession>[
          short,
          removed,
          _session(id: 'kept', localStart: DateTime(2026, 8, 14, 20)),
        ]),
        isTrue,
      );
    });
  });
}

/// Builds a session from local wall-clock time, the way playback records it, so
/// the expectations hold in any timezone.
WellnessViewingSession _session({
  required String id,
  required DateTime localStart,
  Duration length = const Duration(hours: 1),
  bool deleted = false,
}) {
  final localEnd = localStart.add(length);
  final watchedMs = length.inMilliseconds;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: WellnessMediaType.movie,
    source: WellnessPlaybackSource.streaming,
    contentId: id,
    title: 'Title $id',
    startedAtUtc: localStart.toUtc(),
    endedAtUtc: localEnd.toUtc(),
    timezoneOffsetMinutes: localStart.timeZoneOffset.inMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: false,
    segments: <WellnessPlaybackSegment>[
      WellnessPlaybackSegment(
        startedAtUtc: localStart.toUtc(),
        endedAtUtc: localEnd.toUtc(),
      ),
    ],
    updatedAtUtc: localEnd.toUtc(),
    deletedAtUtc: deleted ? localEnd.toUtc() : null,
  );
}
