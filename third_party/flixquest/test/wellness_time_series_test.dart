import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/models/wellness_recap.dart';
import 'package:flixquest/models/wellness_time_series.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bucketing lives in the model rather than the painter, so the boundaries a
/// bar stands for can be asserted without rendering a chart.
void main() {
  // 2026-08-17 is a Monday, so this week runs Mon 17 – Sun 23.
  final now = DateTime(2026, 8, 21, 12);
  final period = WellnessPeriod(
    startUtc: DateTime.utc(2026, 8, 17),
    endUtc: DateTime.utc(2026, 8, 24),
  );

  group('forRange', () {
    test('week buckets run Monday to Sunday and carry the day they cover', () {
      final insights = _insights(
        [
          _session(
            id: 'thu',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 19),
          ),
        ],
        period,
      );

      final series =
          WellnessTimeSeries.forRange(insights, WellnessRange.week, now: now);

      expect(series.unitLabel, 'day');
      expect(series.buckets, hasLength(7));
      expect(series.buckets.first.startLocal, DateTime(2026, 8, 17));
      expect(series.buckets.last.startLocal, DateTime(2026, 8, 23));
      expect(series.buckets[3].startLocal, DateTime(2026, 8, 20));
      expect(series.buckets[3].endLocal, DateTime(2026, 8, 21));
      expect(series.buckets[3].fullLabel, contains('Aug 20'));
      expect(series.buckets[3].totalMs, const Duration(hours: 1).inMilliseconds);
      expect(series.buckets[3].isEmpty, isFalse);
      expect(series.buckets[0].isEmpty, isTrue);
      expect(series.indexOfBusiest(), 3);
      expect(series.activeBuckets, 1);
      expect(series.totalMs, const Duration(hours: 1).inMilliseconds);
    });

    test('averages only the filled buckets', () {
      final insights = _insights(
        [
          _session(
            id: 'mon',
            start: DateTime.utc(2026, 8, 17, 20),
            end: DateTime.utc(2026, 8, 17, 21),
          ),
          _session(
            id: 'tue',
            start: DateTime.utc(2026, 8, 18, 20),
            end: DateTime.utc(2026, 8, 18, 23),
          ),
        ],
        period,
      );

      final series =
          WellnessTimeSeries.forRange(insights, WellnessRange.week, now: now);

      // Two filled buckets of 1h and 3h: an average that counted the five
      // empty days would sit below every visible bar.
      expect(series.activeBuckets, 2);
      expect(series.averageMs, const Duration(hours: 2).inMilliseconds);
    });

    test('indexOf finds the bucket containing a moment', () {
      final series = WellnessTimeSeries.forRange(
        _insights(const [], period),
        WellnessRange.week,
        now: now,
      );

      expect(series.indexOf(DateTime(2026, 8, 17)), 0);
      expect(series.indexOf(DateTime(2026, 8, 19, 23, 59)), 2);
      expect(series.indexOf(DateTime(2026, 8, 23, 23, 59)), 6);
      expect(series.indexOf(DateTime(2026, 8, 24)), -1);
      expect(series.indexOf(DateTime(2026, 8, 16, 23)), -1);
      expect(series.isEmpty, isTrue);
    });

    test('month buckets cover every calendar day of the month', () {
      final insights = _insights(
        [
          _session(
            id: 'twentieth',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 18, 30),
          ),
        ],
        period,
      );

      final series =
          WellnessTimeSeries.forRange(insights, WellnessRange.month, now: now);

      expect(series.buckets, hasLength(31));
      expect(series.unitLabel, 'day');
      expect(series.buckets.first.label, '1');
      expect(series.buckets.last.label, '31');
      expect(series.buckets[19].startLocal, DateTime(2026, 8, 20));
      expect(
        series.buckets[19].totalMs,
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(series.totalMs, const Duration(minutes: 30).inMilliseconds);
    });

    test('year buckets are twelve months of the current year', () {
      final insights = _insights(
        [
          _session(
            id: 'august',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 19),
          ),
          _session(
            id: 'last-year',
            start: DateTime.utc(2025, 8, 20, 18),
            end: DateTime.utc(2025, 8, 20, 19),
          ),
        ],
        WellnessPeriod(
          startUtc: DateTime.utc(2025),
          endUtc: DateTime.utc(2027),
        ),
      );

      final series =
          WellnessTimeSeries.forRange(insights, WellnessRange.year, now: now);

      expect(series.buckets, hasLength(12));
      expect(series.unitLabel, 'month');
      expect(series.buckets[7].startLocal, DateTime(2026, 8));
      expect(series.buckets[7].endLocal, DateTime(2026, 9));
      expect(series.buckets[7].totalMs, const Duration(hours: 1).inMilliseconds);
      // The 2025 session belongs to another year's bar, not this one.
      expect(series.totalMs, const Duration(hours: 1).inMilliseconds);
    });

    test('all-time buckets are one per recorded year', () {
      final insights = _insights(
        [
          _session(
            id: '2025',
            start: DateTime.utc(2025, 3, 4, 18),
            end: DateTime.utc(2025, 3, 4, 19),
          ),
          _session(
            id: '2026',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 20),
          ),
        ],
        WellnessPeriod(
          startUtc: DateTime.utc(2024),
          endUtc: DateTime.utc(2027),
          unbounded: true,
        ),
      );

      final series = WellnessTimeSeries.forRange(
        insights,
        WellnessRange.allTime,
        now: now,
      );

      expect(series.unitLabel, 'year');
      expect(series.buckets.map((bucket) => bucket.label), ['2025', '2026']);
      expect(series.buckets.first.totalMs, const Duration(hours: 1).inMilliseconds);
      expect(series.buckets.last.totalMs, const Duration(hours: 2).inMilliseconds);
      expect(series.indexOfBusiest(), 1);
    });

    test('all-time falls back to the current year with no history', () {
      final series = WellnessTimeSeries.forRange(
        _insights(const [], period),
        WellnessRange.allTime,
        now: now,
      );

      expect(series.buckets, hasLength(1));
      expect(series.buckets.single.label, '2026');
      expect(series.isEmpty, isTrue);
    });

    test('day buckets report the media split behind the bar', () {
      final insights = _insights(
        [
          _session(
            id: 'movie',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 19),
          ),
          _session(
            id: 'episode',
            start: DateTime.utc(2026, 8, 20, 20),
            end: DateTime.utc(2026, 8, 20, 20, 30),
            mediaType: WellnessMediaType.episode,
            seriesId: 'series-1',
          ),
        ],
        period,
      );

      final split =
          WellnessTimeSeries.forRange(insights, WellnessRange.week, now: now)
              .buckets[3]
              .split!;

      expect(split.movieMs, const Duration(hours: 1).inMilliseconds);
      expect(split.episodeMs, const Duration(minutes: 30).inMilliseconds);
      expect(split.liveMs, 0);
    });
  });

  group('forRecap', () {
    test('a day is six four-hour blocks', () {
      final insights = _insights(
        [
          _session(
            id: 'evening',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 19),
          ),
        ],
        period,
      );

      final series = WellnessTimeSeries.forRecap(
        insights,
        WellnessRecapPeriod.today(DateTime(2026, 8, 20, 21)),
      );

      expect(series.unitLabel, 'block');
      expect(series.buckets, hasLength(6));
      expect(series.buckets[4].startLocal, DateTime(2026, 8, 20, 16));
      expect(series.buckets[4].endLocal, DateTime(2026, 8, 20, 20));
      expect(series.buckets[4].totalMs, const Duration(hours: 1).inMilliseconds);
      expect(series.totalMs, const Duration(hours: 1).inMilliseconds);
    });

    test('a week matches the live weekly chart', () {
      final insights = _insights(
        [
          _session(
            id: 'thu',
            start: DateTime.utc(2026, 8, 20, 18),
            end: DateTime.utc(2026, 8, 20, 19),
          ),
        ],
        period,
      );

      final recap = WellnessTimeSeries.forRecap(
        insights,
        WellnessRecapPeriod.week(now),
      );
      final live =
          WellnessTimeSeries.forRange(insights, WellnessRange.week, now: now);

      expect(recap.buckets.map((bucket) => bucket.totalMs),
          live.buckets.map((bucket) => bucket.totalMs));
      expect(recap.buckets.first.startLocal, live.buckets.first.startLocal);
    });

    test('a month is clipped weeks that add up to the month', () {
      final insights = _insights(
        [
          _session(
            id: 'first',
            start: DateTime.utc(2026, 8, 3, 18),
            end: DateTime.utc(2026, 8, 3, 19),
          ),
          _session(
            id: 'last-day',
            start: DateTime.utc(2026, 8, 31, 18),
            end: DateTime.utc(2026, 8, 31, 19),
          ),
        ],
        WellnessPeriod(
          startUtc: DateTime.utc(2026, 8),
          endUtc: DateTime.utc(2026, 9),
        ),
      );
      final recapPeriod = WellnessRecapPeriod.month(DateTime(2026, 8), now);

      final series = WellnessTimeSeries.forRecap(insights, recapPeriod);

      expect(series.unitLabel, 'week');
      expect(series.buckets, hasLength(5));
      expect(series.buckets.first.label, 'W1');
      // The trailing week stops at the month boundary rather than spilling
      // into September.
      expect(series.buckets.last.endLocal, recapPeriod.endLocal);
      expect(series.totalMs, const Duration(hours: 2).inMilliseconds);
      expect(series.buckets.first.split!.movieMs,
          const Duration(hours: 1).inMilliseconds);
    });

    test('a year is twelve months of that year', () {
      final insights = _insights(
        [
          _session(
            id: 'march',
            start: DateTime.utc(2025, 3, 4, 18),
            end: DateTime.utc(2025, 3, 4, 19),
          ),
        ],
        WellnessPeriod(
          startUtc: DateTime.utc(2025),
          endUtc: DateTime.utc(2026),
        ),
      );

      final series = WellnessTimeSeries.forRecap(
        insights,
        WellnessRecapPeriod.year(2025),
      );

      expect(series.buckets, hasLength(12));
      expect(series.unitLabel, 'month');
      expect(series.buckets[2].totalMs, const Duration(hours: 1).inMilliseconds);
      expect(series.indexOfBusiest(), 2);
    });
  });

  group('sessionsFrom', () {
    test('keeps the sessions that started inside the bucket, newest first', () {
      final inside = _session(
        id: 'inside',
        start: DateTime.utc(2026, 8, 20, 18),
        end: DateTime.utc(2026, 8, 20, 19),
      );
      final later = _session(
        id: 'later',
        start: DateTime.utc(2026, 8, 20, 21),
        end: DateTime.utc(2026, 8, 20, 22),
      );
      final outside = _session(
        id: 'outside',
        start: DateTime.utc(2026, 8, 21, 9),
        end: DateTime.utc(2026, 8, 21, 10),
      );
      final sessions = [inside, later, outside];
      final series = WellnessTimeSeries.forRange(
        _insights(sessions, period),
        WellnessRange.week,
        now: now,
      );

      final found = series.buckets[3].sessionsFrom(sessions);

      expect(found.map((session) => session.id), ['later', 'inside']);
    });

    test('buckets by the recorded wall clock, not the UTC instant', () {
      // Recorded at 23:00 UTC in a UTC+3 zone: the viewer's own clock said
      // 02:00 the next morning, so that is the day the session belongs to.
      final overnight = _session(
        id: 'overnight',
        start: DateTime.utc(2026, 8, 20, 23),
        end: DateTime.utc(2026, 8, 21),
        timezoneOffsetMinutes: 180,
      );
      final sessions = [overnight];
      final series = WellnessTimeSeries.forRange(
        _insights(sessions, period),
        WellnessRange.week,
        now: now,
      );

      expect(series.buckets[3].sessionsFrom(sessions), isEmpty);
      expect(
        series.buckets[4].sessionsFrom(sessions).map((s) => s.id),
        ['overnight'],
      );
      // The bucket totals agree with the session list they sit next to.
      expect(series.buckets[3].totalMs, 0);
      expect(series.buckets[4].totalMs, greaterThan(0));
    });
  });
}

WellnessInsights _insights(
  List<WellnessViewingSession> sessions,
  WellnessPeriod period,
) =>
    WellnessInsights.fromSessions(sessions, period: period);

WellnessViewingSession _session({
  required String id,
  required DateTime start,
  required DateTime end,
  String? seriesId,
  WellnessMediaType mediaType = WellnessMediaType.movie,
  int timezoneOffsetMinutes = 0,
}) {
  final watchedMs = end.difference(start).inMilliseconds;
  return WellnessViewingSession(
    id: id,
    ownerId: 'guest',
    deviceId: 'device',
    mediaType: mediaType,
    source: WellnessPlaybackSource.streaming,
    contentId: 'content-$id',
    seriesId: seriesId,
    title: 'Title $id',
    startedAtUtc: start,
    endedAtUtc: end,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    watchedMs: watchedMs,
    durationMs: watchedMs,
    progressEndMs: watchedMs,
    completed: false,
    segments: <WellnessPlaybackSegment>[
      WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end),
    ],
    updatedAtUtc: end,
  );
}
