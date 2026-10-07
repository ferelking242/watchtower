import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

double _widthFactor(WidgetTester tester) {
  final box = tester.widget<FractionallySizedBox>(
    find.byType(FractionallySizedBox),
  );
  return box.widthFactor!;
}

Widget _host(double? value, {bool paused = false}) => MaterialApp(
  home: Scaffold(body: MbGradientProgressBar(value: value, paused: paused)),
);

void main() {
  testWidgets('eases towards the new target instead of snapping', (
    tester,
  ) async {
    await tester.pumpWidget(_host(0.2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.2, 0.01));

    await tester.pumpWidget(_host(0.8));
    await tester.pump(const Duration(milliseconds: 80));
    final mid = _widthFactor(tester);
    expect(mid, greaterThan(0.2));
    expect(mid, lessThan(0.8));

    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.8, 0.01));
  });

  testWidgets('sub-pixel counter noise does not move the bar', (tester) async {
    await tester.pumpWidget(_host(0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.5, 0.0001));

    await tester.pumpWidget(_host(0.501));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_widthFactor(tester), closeTo(0.5, 0.0001));
  });

  testWidgets('snake sweep band travels while the transfer is active', (
    tester,
  ) async {
    await tester.pumpWidget(_host(0.6));
    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<Positioned>(find.byType(Positioned)).left!;
    await tester.pump(const Duration(milliseconds: 300));
    final second = tester.widget<Positioned>(find.byType(Positioned)).left!;
    expect(second, isNot(equals(first)));
  });

  testWidgets('snake band stops and resets when paused', (tester) async {
    await tester.pumpWidget(_host(0.6, paused: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Positioned), findsNothing);

    await tester.pumpWidget(_host(0.6));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Positioned), findsOneWidget);
  });

  testWidgets('indeterminate value keeps the sweeping indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
