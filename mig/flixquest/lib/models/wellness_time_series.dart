import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'wellness.dart';
import 'wellness_insights.dart';
import 'wellness_recap.dart';

/// One bar's worth of the timeline: a labelled span of local time with the
/// watch time inside it.
class WellnessTimeBucket {
  const WellnessTimeBucket({
    required this.label,
    required this.fullLabel,
    required this.startLocal,
    required this.endLocal,
    required this.totalMs,
    this.split,
  });

  /// Short axis label — one or two characters wherever the axis is dense.
  final String label;

  /// Spelled-out label for the callout and for screen readers.
  final String fullLabel;

  final DateTime startLocal;

  /// Exclusive end of the bucket.
  final DateTime endLocal;

  final int totalMs;

  /// Media breakdown, when the bucket is at least a full day. Hour-level
  /// buckets have no breakdown to report.
  final WellnessMediaSplit? split;

  bool get isEmpty => totalMs == 0;

  /// Sessions that started inside this bucket, newest first.
  List<WellnessViewingSession> sessionsFrom(
    Iterable<WellnessViewingSession> sessions,
  ) {
    final inside = sessions.where((session) {
      final local = _localStartOf(session);
      return !local.isBefore(startLocal) && local.isBefore(endLocal);
    }).toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    return inside;
  }

  /// The session's own wall clock, rebuilt as a local-flavoured `DateTime`.
  ///
  /// Shifting a UTC instant by the recorded offset yields the right *fields*
  /// but keeps the UTC flag, and comparing that against a local bucket bound
  /// compares absolute instants — so a session would land in the wrong bucket
  /// by the device's UTC offset. Rebuilding the fields matches how
  /// [WellnessInsights] keys its daily buckets.
  static DateTime _localStartOf(WellnessViewingSession session) {
    final shifted = session.startedAtUtc
        .add(Duration(minutes: session.timezoneOffsetMinutes));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
    );
  }
}

/// The bucketed timeline behind the bar chart. Bucketing lives here rather
/// than in the widget so the boundaries can be tested without a chart.
class WellnessTimeSeries {
  const WellnessTimeSeries({required this.buckets, required this.unitLabel});

  final List<WellnessTimeBucket> buckets;

  /// What one bar represents — "day", "month", "year". Used in copy.
  final String unitLabel;

  int get maxMs =>
      buckets.fold<int>(0, (best, bucket) => math.max(best, bucket.totalMs));

  int get totalMs =>
      buckets.fold<int>(0, (total, bucket) => total + bucket.totalMs);

  int get activeBuckets => buckets.where((bucket) => !bucket.isEmpty).length;

  bool get isEmpty => buckets.isEmpty || maxMs == 0;

  /// Mean across *filled* buckets: an average that includes empty days is a
  /// line no bar can be read against.
  double get averageMs => activeBuckets == 0 ? 0 : totalMs / activeBuckets;

  int indexOfBusiest() {
    var best = -1;
    var bestValue = 0;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].totalMs > bestValue) {
        bestValue = buckets[i].totalMs;
        best = i;
      }
    }
    return best;
  }

  /// Index of the bucket containing [moment], or -1.
  int indexOf(DateTime moment) {
    for (var i = 0; i < buckets.length; i++) {
      if (!moment.isBefore(buckets[i].startLocal) &&
          moment.isBefore(buckets[i].endLocal)) {
        return i;
      }
    }
    return -1;
  }

  factory WellnessTimeSeries.forRange(
    WellnessInsights insights,
    WellnessRange range, {
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    switch (range) {
      case WellnessRange.week:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return WellnessTimeSeries(
          unitLabel: 'day',
          buckets: List<WellnessTimeBucket>.generate(
            7,
            (index) => _dayBucket(insights, start.add(Duration(days: index))),
            growable: false,
          ),
        );
      case WellnessRange.month:
        final dayCount = DateTime(today.year, today.month + 1, 0).day;
        return WellnessTimeSeries(
          unitLabel: 'day',
          buckets: List<WellnessTimeBucket>.generate(
            dayCount,
            (index) => _dayBucket(
              insights,
              DateTime(today.year, today.month, index + 1),
              shortLabel: '${index + 1}',
            ),
            growable: false,
          ),
        );
      case WellnessRange.year:
        return WellnessTimeSeries(
          unitLabel: 'month',
          buckets: List<WellnessTimeBucket>.generate(
            12,
            (index) => _monthBucket(insights, today.year, index + 1),
            growable: false,
          ),
        );
      case WellnessRange.allTime:
        final years = insights.dailyWatchedMs.keys
            .map((day) => day.year)
            .toSet()
            .toList()
          ..sort();
        if (years.isEmpty) years.add(today.year);
        return WellnessTimeSeries(
          unitLabel: 'year',
          buckets: years
              .map((year) => _yearBucket(insights, year))
              .toList(growable: false),
        );
    }
  }

  factory WellnessTimeSeries.forRecap(
    WellnessInsights insights,
    WellnessRecapPeriod period,
  ) {
    switch (period.kind) {
      case WellnessRecapPeriodKind.day:
        final weekday = period.startLocal.weekday - 1;
        return WellnessTimeSeries(
          unitLabel: 'block',
          buckets: List<WellnessTimeBucket>.generate(6, (index) {
            final startHour = index * 4;
            final start = period.startLocal.add(Duration(hours: startHour));
            final total = insights.hourOfWeekMs[weekday]
                .skip(startHour)
                .take(4)
                .fold<int>(0, (sum, hour) => sum + hour);
            return WellnessTimeBucket(
              label: DateFormat.j().format(DateTime(2024, 1, 1, startHour)),
              fullLabel: '${DateFormat.j().format(start)} – '
                  '${DateFormat.j().format(start.add(const Duration(hours: 4)))}',
              startLocal: start,
              endLocal: start.add(const Duration(hours: 4)),
              totalMs: total,
            );
          }, growable: false),
        );
      case WellnessRecapPeriodKind.week:
        return WellnessTimeSeries(
          unitLabel: 'day',
          buckets: List<WellnessTimeBucket>.generate(
            7,
            (index) => _dayBucket(
              insights,
              period.startLocal.add(Duration(days: index)),
            ),
            growable: false,
          ),
        );
      case WellnessRecapPeriodKind.month:
        final dayCount = DateTime(
          period.startLocal.year,
          period.startLocal.month + 1,
          0,
        ).day;
        final weeks = (dayCount / 7).ceil();
        return WellnessTimeSeries(
          unitLabel: 'week',
          buckets: List<WellnessTimeBucket>.generate(weeks, (week) {
            final start = period.startLocal.add(Duration(days: week * 7));
            var end = start.add(const Duration(days: 7));
            if (end.isAfter(period.endLocal)) end = period.endLocal;
            var total = 0;
            var split = WellnessMediaSplit.empty;
            for (var day = start;
                day.isBefore(end);
                day = day.add(const Duration(days: 1))) {
              total += insights.dailyWatchedMs[day] ?? 0;
              split += insights.dailyMediaMs[day] ?? WellnessMediaSplit.empty;
            }
            return WellnessTimeBucket(
              label: 'W${week + 1}',
              fullLabel: '${DateFormat.MMMd().format(start)} – '
                  '${DateFormat.MMMd().format(end.subtract(const Duration(days: 1)))}',
              startLocal: start,
              endLocal: end,
              totalMs: total,
              split: split,
            );
          }, growable: false),
        );
      case WellnessRecapPeriodKind.year:
        return WellnessTimeSeries(
          unitLabel: 'month',
          buckets: List<WellnessTimeBucket>.generate(
            12,
            (index) =>
                _monthBucket(insights, period.startLocal.year, index + 1),
            growable: false,
          ),
        );
    }
  }
}

WellnessTimeBucket _dayBucket(
  WellnessInsights insights,
  DateTime day, {
  String? shortLabel,
}) =>
    WellnessTimeBucket(
      label: shortLabel ?? DateFormat.E().format(day),
      fullLabel: DateFormat.MMMEd().format(day),
      startLocal: day,
      endLocal: day.add(const Duration(days: 1)),
      totalMs: insights.dailyWatchedMs[day] ?? 0,
      split: insights.dailyMediaMs[day] ?? WellnessMediaSplit.empty,
    );

WellnessTimeBucket _monthBucket(
  WellnessInsights insights,
  int year,
  int month,
) {
  final start = DateTime(year, month);
  final end = DateTime(year, month + 1);
  var total = 0;
  var split = WellnessMediaSplit.empty;
  for (final entry in insights.dailyWatchedMs.entries) {
    if (entry.key.year != year || entry.key.month != month) continue;
    total += entry.value;
    split += insights.dailyMediaMs[entry.key] ?? WellnessMediaSplit.empty;
  }
  return WellnessTimeBucket(
    label: DateFormat.MMM().format(start),
    fullLabel: DateFormat.yMMMM().format(start),
    startLocal: start,
    endLocal: end,
    totalMs: total,
    split: split,
  );
}

WellnessTimeBucket _yearBucket(WellnessInsights insights, int year) {
  var total = 0;
  var split = WellnessMediaSplit.empty;
  for (final entry in insights.dailyWatchedMs.entries) {
    if (entry.key.year != year) continue;
    total += entry.value;
    split += insights.dailyMediaMs[entry.key] ?? WellnessMediaSplit.empty;
  }
  return WellnessTimeBucket(
    label: '$year',
    fullLabel: '$year',
    startLocal: DateTime(year),
    endLocal: DateTime(year + 1),
    totalMs: total,
    split: split,
  );
}
