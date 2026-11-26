import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/music/components/shimmers/music_shimmer.dart';
import 'package:watchtower/modules/music/modules/home/home_rail.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('HomeRailSkeleton', () {
    testWidgets('draws one placeholder per announced card', (tester) async {
      await _pump(
        tester,
        const HomeRailSkeleton(itemCount: 3, itemWidth: 120, itemHeight: 180),
      );

      expect(find.byType(MusicCardShimmer), findsNWidgets(3));
    });

    testWidgets('rounds artist placeholders', (tester) async {
      await _pump(
        tester,
        const HomeRailSkeleton(itemCount: 2, itemWidth: 100, circular: true),
      );

      expect(find.byType(MusicCardShimmer), findsNothing);
      final circles = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => (c.decoration! as BoxDecoration).shape)
          .where((shape) => shape == BoxShape.circle);
      expect(circles, hasLength(2));
    });

    testWidgets('can drop the title bar when a header is already drawn', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomeRailSkeleton(itemCount: 1, title: false, itemWidth: 90),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, isNot(isNull));
      expect(find.byType(MusicCardShimmer), findsOneWidget);
    });

    testWidgets('placeholders never scroll', (tester) async {
      await _pump(tester, const HomeRailSkeleton(itemCount: 2));

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}
