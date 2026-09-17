import 'package:intl/intl.dart';

import 'wellness.dart';
import 'wellness_insights.dart';

enum WellnessRecapPeriodKind { day, week, month, year }

/// A named slice of viewing history a shareable recap can be built for.
///
/// Recap periods are deliberately independent of the range selected on the
/// insights screen: a finished month can have a recap ready to revisit while
/// the selected range (this week, by default) holds nothing at all.
class WellnessRecapPeriod {
  const WellnessRecapPeriod({
    required this.id,
    required this.label,
    required this.captionLabel,
    required this.kind,
    required this.startLocal,
    required this.endLocal,
  });

  factory WellnessRecapPeriod.today(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return WellnessRecapPeriod(
      id: 'day-${DateFormat('yyyy-MM-dd').format(start)}',
      label: 'Today',
      captionLabel: 'Today’s recap',
      kind: WellnessRecapPeriodKind.day,
      startLocal: start,
      endLocal: start.add(const Duration(days: 1)),
    );
  }

  factory WellnessRecapPeriod.week(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    return WellnessRecapPeriod(
      id: 'week-${DateFormat('yyyy-MM-dd').format(start)}',
      label: 'This week',
      captionLabel: 'This week’s recap',
      kind: WellnessRecapPeriodKind.week,
      startLocal: start,
      endLocal: start.add(const Duration(days: 7)),
    );
  }

  factory WellnessRecapPeriod.month(DateTime month, DateTime now) {
    final start = DateTime(month.year, month.month);
    final label = start.year == now.year
        ? DateFormat.MMMM().format(start)
        : DateFormat.yMMMM().format(start);
    return WellnessRecapPeriod(
      id: 'month-${DateFormat('yyyy-MM').format(start)}',
      label: label,
      captionLabel: 'My $label recap',
      kind: WellnessRecapPeriodKind.month,
      startLocal: start,
      endLocal: DateTime(start.year, start.month + 1),
    );
  }

  factory WellnessRecapPeriod.year(int year) {
    final start = DateTime(year);
    return WellnessRecapPeriod(
      id: 'year-$year',
      label: '$year',
      captionLabel: 'My $year recap',
      kind: WellnessRecapPeriodKind.year,
      startLocal: start,
      endLocal: DateTime(year + 1),
    );
  }

  /// The recap that lines up with the range selected on the insights screen.
  factory WellnessRecapPeriod.forRange(WellnessRange range, DateTime now) =>
      switch (range) {
        WellnessRange.week => WellnessRecapPeriod.week(now),
        WellnessRange.month => WellnessRecapPeriod.month(now, now),
        WellnessRange.year ||
        WellnessRange.allTime =>
          WellnessRecapPeriod.year(now.year),
      };

  final String id;
  final String label;
  final String captionLabel;
  final WellnessRecapPeriodKind kind;
  final DateTime startLocal;
  final DateTime endLocal;

  WellnessPeriod get wellnessPeriod => WellnessPeriod(
        startUtc: startLocal.toUtc(),
        endUtc: endLocal.toUtc(),
      );

  bool isCompleteAt(DateTime now) => !endLocal.isAfter(now);

  WellnessInsights insightsFrom(Iterable<WellnessViewingSession> sessions) =>
      WellnessInsights.fromSessions(sessions, period: wellnessPeriod);

  /// Whether this period is both finished and backed by enough activity to
  /// render a recap. Every "recap ready" surface answers this same question so
  /// the promise and the recap behind it can never disagree.
  bool hasReadyRecap(
    Iterable<WellnessViewingSession> sessions,
    DateTime now,
  ) =>
      isCompleteAt(now) && !insightsFrom(sessions).isEmpty;

  /// Periods worth offering as recaps: the current day, week, month and year,
  /// then every month with activity (newest first) and the years they fall in.
  static List<WellnessRecapPeriod> available(
    Iterable<WellnessViewingSession> sessions,
    DateTime now,
  ) {
    final periods = <WellnessRecapPeriod>[];
    final ids = <String>{};
    void add(WellnessRecapPeriod period) {
      if (ids.add(period.id)) periods.add(period);
    }

    add(WellnessRecapPeriod.today(now));
    add(WellnessRecapPeriod.week(now));
    add(WellnessRecapPeriod.month(now, now));
    add(WellnessRecapPeriod.year(now.year));

    final months = recapWorthySessions(sessions)
        .map((session) {
          final local = session.startedAtUtc.add(
            Duration(minutes: session.timezoneOffsetMinutes),
          );
          return DateTime(local.year, local.month);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    for (final month in months.take(12)) {
      add(WellnessRecapPeriod.month(month, now));
    }

    final years = months.map((month) => month.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    for (final year in years) {
      add(WellnessRecapPeriod.year(year));
    }
    return periods;
  }

  /// The recap the app leads with: last month early in the month, the year in
  /// late December and January, and the month in progress otherwise. Periods
  /// without activity are skipped so the featured recap is a real one.
  static WellnessRecapPeriod featured(
    Iterable<WellnessViewingSession> sessions,
    DateTime now,
  ) {
    if (now.month == DateTime.january) {
      final previousYear = WellnessRecapPeriod.year(now.year - 1);
      if (!previousYear.insightsFrom(sessions).isEmpty) {
        return previousYear;
      }
    }
    if (now.month == DateTime.december && now.day >= 15) {
      return WellnessRecapPeriod.year(now.year);
    }
    if (now.day <= 10) {
      final previousMonth = WellnessRecapPeriod.month(
        DateTime(now.year, now.month - 1),
        now,
      );
      if (!previousMonth.insightsFrom(sessions).isEmpty) {
        return previousMonth;
      }
    }
    return WellnessRecapPeriod.month(now, now);
  }

  /// The period a share sheet should open on for [range]: the matching period
  /// when it has activity, otherwise the most recent one that does, so the
  /// sheet never opens on a blank recap.
  static WellnessRecapPeriod bestForRange(
    Iterable<WellnessViewingSession> sessions,
    WellnessRange range,
    DateTime now,
  ) {
    final forRange = WellnessRecapPeriod.forRange(range, now);
    if (!forRange.insightsFrom(sessions).isEmpty) return forRange;
    return available(sessions, now).firstWhere(
      (period) => !period.insightsFrom(sessions).isEmpty,
      orElse: () => forRange,
    );
  }
}

/// Sessions a recap can be built from: still present, and long enough to count.
Iterable<WellnessViewingSession> recapWorthySessions(
  Iterable<WellnessViewingSession> sessions,
) =>
    sessions.where((session) => !session.isDeleted && session.qualifies);

/// Whether there is any history at all worth offering a recap for, regardless
/// of the range currently on screen.
bool hasRecapWorthyHistory(Iterable<WellnessViewingSession> sessions) =>
    recapWorthySessions(sessions).isNotEmpty;
