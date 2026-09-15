import 'dart:math' as math;

import 'package:flixquest/widgets/wellness_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The charts are hand-painted, so the hit test is the part that can silently
/// disagree with what is drawn. These tests pin the geometry: a tap selects the
/// mark under the finger, tapping it again clears, and every value is reachable
/// as text or semantics rather than only through a gesture.
void main() {
  group('wellnessCompactDuration', () {
    test('formats axis-sized labels', () {
      expect(wellnessCompactDuration(0), '0');
      expect(wellnessCompactDuration(-5), '0');
      expect(wellnessCompactDuration(const Duration(minutes: 45).inMilliseconds),
          '45m');
      expect(wellnessCompactDuration(const Duration(hours: 2).inMilliseconds),
          '2h');
      expect(
        wellnessCompactDuration(
          const Duration(hours: 2, minutes: 20).inMilliseconds,
        ),
        '2h 20m',
      );
      // Past ten hours the minutes stop earning their width.
      expect(
        wellnessCompactDuration(
          const Duration(hours: 11, minutes: 30).inMilliseconds,
        ),
        '11h',
      );
    });
  });

  group('WellnessBarChart', () {
    final data = List<WellnessBarDatum>.generate(
      7,
      (index) => WellnessBarDatum(
        label: 'D$index',
        fullLabel: 'Day $index',
        value: (index + 1) * 600000,
      ),
      growable: false,
    );

    testWidgets('selects the bar under the finger and toggles it off',
        (tester) async {
      final taps = <int?>[];
      int? selected;
      await tester.pumpWidget(
        _host(
          width: 350,
          child: StatefulBuilder(
            builder: (context, setState) => WellnessBarChart(
              data: data,
              selectedIndex: selected,
              onSelected: (index) {
                taps.add(index);
                setState(() => selected = index);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = find.byType(WellnessBarChart);
      // Plot starts after a 38px gutter; seven slots across the remaining 312.
      const slot = (350 - 38) / 7;
      await tester.tapAt(
        tester.getTopLeft(chart) + Offset(38 + slot * 3.5, 100),
      );
      await tester.pumpAndSettle();
      expect(taps, [3]);
      expect(selected, 3);

      await tester.tapAt(
        tester.getTopLeft(chart) + Offset(38 + slot * 3.5, 100),
      );
      await tester.pumpAndSettle();
      expect(taps, [3, null]);
      expect(selected, isNull);
    });

    testWidgets('ignores taps in the tick gutter', (tester) async {
      final taps = <int?>[];
      await tester.pumpWidget(
        _host(
          width: 350,
          child: WellnessBarChart(data: data, onSelected: taps.add),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getTopLeft(find.byType(WellnessBarChart)) + const Offset(4, 100),
      );
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('a drag scrubs from bar to bar', (tester) async {
      final taps = <int?>[];
      int? selected;
      await tester.pumpWidget(
        _host(
          width: 350,
          child: StatefulBuilder(
            builder: (context, setState) => WellnessBarChart(
              data: data,
              selectedIndex: selected,
              onSelected: (index) {
                taps.add(index);
                setState(() => selected = index);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const slot = (350 - 38) / 7;
      final origin =
          tester.getTopLeft(find.byType(WellnessBarChart)) + Offset(38 + slot * .5, 100);
      final gesture = await tester.startGesture(origin);
      // The first move clears the drag slop while staying over the first bar,
      // so the scrub is reported from where the finger actually started.
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(slot, 0));
      await gesture.moveBy(const Offset(slot * 2, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      // Scrubbing never toggles off — it always lands on the bar it is over.
      expect(taps.first, 0);
      expect(taps.last, 3);
      expect(taps, isNot(contains(null)));
    });

    testWidgets('announces the busiest bar without a gesture', (tester) async {
      await tester.pumpWidget(_host(width: 350, child: WellnessBarChart(data: data)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Busiest Day 6, 1h')),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is nothing to show', (tester) async {
      await tester.pumpWidget(
        _host(
          width: 350,
          child: WellnessBarChart(
            data: const [
              WellnessBarDatum(label: 'M', value: 0),
              WellnessBarDatum(label: 'T', value: 0),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('No viewing recorded')),
        findsOneWidget,
      );
    });
  });

  group('WellnessDonutChart', () {
    const slices = [
      WellnessDonutSlice(label: 'Movies', value: 100, color: Color(0xFF3F51B5)),
      WellnessDonutSlice(label: 'Episodes', value: 100, color: Color(0xFF009688)),
      WellnessDonutSlice(label: 'Live TV', value: 100, color: Color(0xFFB3261E)),
    ];

    testWidgets('selects the slice under the finger', (tester) async {
      final taps = <int?>[];
      await tester.pumpWidget(
        _host(
          width: 148,
          child: WellnessDonutChart(
            slices: slices,
            centerLabel: '5h',
            centerCaption: 'this week',
            onSelected: taps.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(WellnessDonutChart));
      // Three equal slices sweep 120° each from twelve o'clock, clockwise, so
      // their midpoints sit at 60°, 180° and 300°.
      for (final degrees in [60.0, 180.0, 300.0]) {
        await tester.tapAt(center + _ringPoint(degrees));
        await tester.pumpAndSettle();
      }

      expect(taps, [0, 1, 2]);
    });

    testWidgets('ignores the hole in the middle', (tester) async {
      final taps = <int?>[];
      await tester.pumpWidget(
        _host(
          width: 148,
          child: WellnessDonutChart(
            slices: slices,
            centerLabel: '5h',
            onSelected: taps.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(WellnessDonutChart)));
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('hits the right slice when the parent stretches it',
        (tester) async {
      final taps = <int?>[];
      await tester.pumpWidget(
        _host(
          // Wider than the requested size: the painter uses the box it is
          // given, so the hit test has to agree with it.
          width: 260,
          child: WellnessDonutChart(
            slices: slices,
            centerLabel: '5h',
            onSelected: taps.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(WellnessDonutChart));
      await tester.tapAt(center + _ringPoint(180));
      await tester.pumpAndSettle();

      expect(taps, [1]);
    });

    testWidgets('keeps the headline number in the middle as text',
        (tester) async {
      await tester.pumpWidget(
        _host(
          width: 148,
          child: const WellnessDonutChart(
            slices: slices,
            centerLabel: '5h 30m',
            centerCaption: 'this week',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5h 30m'), findsOneWidget);
      expect(find.text('this week'), findsOneWidget);
    });
  });

  group('WellnessHeatmap', () {
    List<List<int>> grid() => List<List<int>>.generate(
          7,
          (day) => List<int>.generate(24, (hour) => day == 2 && hour == 9 ? 3600000 : 0),
          growable: false,
        );

    testWidgets('selects the cell under the finger and toggles it off',
        (tester) async {
      final taps = <(int, int)?>[];
      (int, int)? selected;
      await tester.pumpWidget(
        _host(
          width: 360,
          child: StatefulBuilder(
            builder: (context, setState) => WellnessHeatmap(
              values: grid(),
              selectedCell: selected,
              onSelected: (cell) {
                taps.add(cell);
                setState(() => selected = cell);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 30px day gutter, then 24 columns across the rest; rows are 17px.
      const cellWidth = (360 - 30) / 24;
      final origin = tester.getTopLeft(find.byType(WellnessHeatmap));
      final target = origin + Offset(30 + cellWidth * 9.5, 17 * 2.5);
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(taps, [(2, 9)]);

      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(taps, [(2, 9), null]);
    });

    testWidgets('ignores taps in the day gutter', (tester) async {
      final taps = <(int, int)?>[];
      await tester.pumpWidget(
        _host(
          width: 360,
          child: WellnessHeatmap(values: grid(), onSelected: taps.add),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getTopLeft(find.byType(WellnessHeatmap)) + const Offset(8, 20),
      );
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('carries a legend and names its busiest cell', (tester) async {
      await tester.pumpWidget(_host(width: 360, child: WellnessHeatmap(values: grid())));
      await tester.pumpAndSettle();

      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.textContaining('Peak 1h'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Busiest .* 1h')),
        findsOneWidget,
      );
    });
  });

  group('WellnessOrdinalBars', () {
    const data = [
      WellnessOrdinalDatum(label: 'Morning', value: 1800000, caption: '5a–12p'),
      WellnessOrdinalDatum(label: 'Afternoon', value: 3600000, caption: '12–5p'),
      WellnessOrdinalDatum(label: 'Evening', value: 7200000, caption: '5–10p'),
    ];

    testWidgets('prints every value beside its bar', (tester) async {
      await tester.pumpWidget(_host(width: 360, child: const WellnessOrdinalBars(data: data)));
      await tester.pumpAndSettle();

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('5a–12p'), findsOneWidget);
    });

    testWidgets('rows are the hit target and toggle', (tester) async {
      final taps = <int?>[];
      int? selected;
      await tester.pumpWidget(
        _host(
          width: 360,
          child: StatefulBuilder(
            builder: (context, setState) => WellnessOrdinalBars(
              data: data,
              selectedIndex: selected,
              onSelected: (index) {
                taps.add(index);
                setState(() => selected = index);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();
      expect(taps, [2]);

      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();
      expect(taps, [2, null]);
    });

    testWidgets('says so when there is nothing recorded', (tester) async {
      await tester.pumpWidget(
        _host(width: 360, child: const WellnessOrdinalBars(data: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing recorded yet.'), findsOneWidget);
    });
  });

  testWidgets('WellnessMeter always prints its number', (tester) async {
    await tester.pumpWidget(
      _host(
        width: 360,
        child: const WellnessMeter(
          label: 'Days with viewing',
          valueLabel: '43%',
          ratio: .43,
          caption: '3 of 7 days',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Days with viewing'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);
    expect(find.text('3 of 7 days'), findsOneWidget);
  });

  testWidgets('WellnessSplitMeter labels each part with value and share',
      (tester) async {
    await tester.pumpWidget(
      _host(
        width: 360,
        child: const WellnessSplitMeter(
          parts: [
            WellnessSplitPart(
              label: 'Mon–Fri',
              value: 5400000,
              color: Color(0xFF3F51B5),
            ),
            WellnessSplitPart(
              label: 'Sat–Sun',
              value: 1800000,
              color: Color(0xFF009688),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon–Fri'), findsOneWidget);
    expect(find.textContaining('1h 30m'), findsOneWidget);
    expect(find.textContaining('75%'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
  });

  testWidgets('WellnessSparkline keeps its own spoken summary', (tester) async {
    await tester.pumpWidget(
      _host(
        width: 360,
        child: const WellnessSparkline(
          values: [0, 600000, 1200000, 0, 3600000],
          semanticsLabel: 'Watch time for the last 5 days',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Watch time for the last 5 days'),
      findsOneWidget,
    );
  });
}

/// A point on the donut's ring, [degrees] measured clockwise from twelve.
Offset _ringPoint(double degrees, {double size = 148}) {
  final radius = (size - size * .15) / 2;
  final theta = degrees * math.pi / 180 - math.pi / 2;
  return Offset(radius * math.cos(theta), radius * math.sin(theta));
}

Widget _host({required Widget child, double width = 200}) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );
