import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/ui/responsive/breakpoints.dart';

void main() {
  group('windowSizeClassFor', () {
    test('maps the width bands to the expected class', () {
      expect(windowSizeClassFor(360), WindowSizeClass.compact);
      expect(windowSizeClassFor(599), WindowSizeClass.compact);
      expect(windowSizeClassFor(600), WindowSizeClass.medium);
      expect(windowSizeClassFor(839), WindowSizeClass.medium);
      expect(windowSizeClassFor(840), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1199), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1200), WindowSizeClass.large);
      expect(windowSizeClassFor(1599), WindowSizeClass.large);
      expect(windowSizeClassFor(1600), WindowSizeClass.extraLarge);
      expect(windowSizeClassFor(2560), WindowSizeClass.extraLarge);
    });

    test('only the desktop classes use the sidebar', () {
      expect(WindowSizeClass.compact.usesSidebar, isFalse);
      expect(WindowSizeClass.medium.usesSidebar, isFalse);
      expect(WindowSizeClass.expanded.usesSidebar, isTrue);
      expect(WindowSizeClass.large.usesSidebar, isTrue);
      expect(WindowSizeClass.extraLarge.usesSidebar, isTrue);
    });

    test('two columns only on the widest desktop classes', () {
      expect(WindowSizeClass.expanded.supportsTwoColumns, isFalse);
      expect(WindowSizeClass.large.supportsTwoColumns, isTrue);
      expect(WindowSizeClass.extraLarge.supportsTwoColumns, isTrue);
    });

    test('content is capped once the window is wide', () {
      expect(WindowSizeClass.compact.contentMaxWidth, isNull);
      expect(WindowSizeClass.medium.contentMaxWidth, isNull);
      expect(WindowSizeClass.expanded.contentMaxWidth, isNotNull);
      expect(WindowSizeClass.large.contentMaxWidth, isNotNull);
      expect(WindowSizeClass.extraLarge.contentMaxWidth, isNotNull);
    });

    test('page padding grows with the window', () {
      final paddings = WindowSizeClass.values.map((c) => c.pagePadding).toList();
      for (var i = 1; i < paddings.length; i++) {
        expect(paddings[i], greaterThanOrEqualTo(paddings[i - 1]));
      }
    });
  });

  group('AdaptiveGridSpec.resolve', () {
    test('a phone-width strip yields a small column count', () {
      final spec = AdaptiveGridSpec.resolve(300);
      expect(spec.columns, 2);
      expect(spec.tileExtent, closeTo(144, 0.01));
    });

    test('a very narrow strip collapses to one column', () {
      final spec = AdaptiveGridSpec.resolve(120);
      expect(spec.columns, 1);
    });

    test('columns grow with the available width', () {
      final narrow = AdaptiveGridSpec.resolve(600);
      final wide = AdaptiveGridSpec.resolve(1400);
      expect(wide.columns, greaterThan(narrow.columns));
    });

    test('tiles stay at least as wide as the minimum target', () {
      final spec = AdaptiveGridSpec.resolve(1400, minTileWidth: 132);
      expect(spec.tileExtent, greaterThanOrEqualTo(132));
    });

    test('columns are capped at maxColumns', () {
      final spec = AdaptiveGridSpec.resolve(4000, maxColumns: 8);
      expect(spec.columns, 8);
    });

    test('a degenerate width still returns one usable column', () {
      final spec = AdaptiveGridSpec.resolve(0);
      expect(spec.columns, 1);
      expect(spec.tileExtent, greaterThan(0));
    });

    test('tile extent plus gaps fills the available width', () {
      const width = 1234.0;
      final spec = AdaptiveGridSpec.resolve(width);
      final filled = spec.tileExtent * spec.columns +
          spec.spacing * (spec.columns - 1);
      expect(filled, closeTo(width, 0.5));
    });
  });
}
