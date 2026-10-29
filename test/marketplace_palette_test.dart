import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';

/// Pumps a widget under a theme of the requested brightness and returns the
/// palette the Marketplace resolves for that theme.
Future<MarketplacePalette> _paletteFor(
  WidgetTester tester,
  Brightness brightness,
) async {
  late MarketplacePalette palette;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: Builder(
        builder: (context) {
          palette = MarketplacePalette.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return palette;
}

void main() {
  group('MarketplacePalette', () {
    testWidgets('dark theme keeps the Marketplace identity', (tester) async {
      final palette = await _paletteFor(tester, Brightness.dark);
      expect(palette.isDark, isTrue);
      expect(palette.accent, const Color(0xFF8ED081));
      expect(palette.surface, const Color(0xFF1B1B1D));
      expect(palette.surfaceHigh, const Color(0xFF252527));
      expect(palette.border, const Color(0xFF353539));
    });

    testWidgets('light theme derives surfaces from the ColorScheme', (
      tester,
    ) async {
      final palette = await _paletteFor(tester, Brightness.light);
      expect(palette.isDark, isFalse);
      // The point of the refactor: the light theme must no longer paint the
      // Marketplace with the dark constants.
      expect(palette.surface, isNot(const Color(0xFF1B1B1D)));
      expect(palette.surfaceHigh, isNot(const Color(0xFF252527)));
      expect(palette.border, isNot(const Color(0xFF353539)));
      expect(palette.muted, isNot(const Color(0xFFB9B8BE)));
    });

    testWidgets('both themes expose a distinct accent per content type', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final palette = await _paletteFor(tester, brightness);
        expect(palette.typeAccents, hasLength(5));
        expect(palette.typeAccents.toSet(), hasLength(5));
        for (final type in ItemType.values) {
          expect(palette.typeAccents, contains(palette.typeColor(type)));
        }
      }
    });

    testWidgets('the alternate banner gradient differs from the first', (
      tester,
    ) async {
      final palette = await _paletteFor(tester, Brightness.dark);
      expect(palette.heroAlt, isNot((palette.heroStart, palette.heroEnd)));
    });
  });
}
