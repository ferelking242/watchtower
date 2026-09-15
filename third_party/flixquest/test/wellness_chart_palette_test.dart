import 'dart:math' as math;

import 'package:flixquest/widgets/wellness_chart_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette is computed rather than eyeballed, so the thresholds it claims
/// to hold are asserted here instead of trusted: a lightness band, a chroma
/// floor, colourblind and normal-vision separation between adjacent slots, and
/// contrast against the surface the chart is painted on.
void main() {
  // 24 seeds around the hue circle — a dynamic-colour seed can land anywhere.
  final seeds = List<Color>.generate(
    24,
    (index) => HSVColor.fromAHSV(1, index * 15.0, .78, .82).toColor(),
    growable: false,
  );

  group('categorical triad', () {
    for (final brightness in Brightness.values) {
      testWidgets('clears every check in ${brightness.name} mode',
          (tester) async {
        for (final seed in seeds) {
          final palette = await _paletteFor(
            tester,
            seed: seed,
            brightness: brightness,
          );
          final audit = palette.auditCategorical();
          final reason = 'seed ${seed.toARGB32().toRadixString(16)} '
              '(${brightness.name})';

          expect(palette.categorical, hasLength(3), reason: reason);
          expect(audit.worstAdjacentCvdDeltaE, greaterThanOrEqualTo(8.0),
              reason: 'protan/deutan separation, $reason');
          expect(audit.worstAdjacentNormalDeltaE, greaterThanOrEqualTo(15.0),
              reason: 'normal-vision separation, $reason');
          expect(audit.minChroma, greaterThanOrEqualTo(.10), reason: reason);
          expect(audit.minContrast, greaterThanOrEqualTo(3.0),
              reason: 'contrast against the chart surface, $reason');
          if (palette.isDark) {
            expect(audit.minLightness, greaterThanOrEqualTo(.48),
                reason: reason);
            expect(audit.maxLightness, lessThanOrEqualTo(.67), reason: reason);
          } else {
            expect(audit.minLightness, greaterThanOrEqualTo(.43),
                reason: reason);
            expect(audit.maxLightness, lessThanOrEqualTo(.77), reason: reason);
          }
        }
      });
    }

    testWidgets('holds up on a lights-out surface', (tester) async {
      for (final seed in seeds) {
        final palette = await _paletteFor(
          tester,
          seed: seed,
          brightness: Brightness.dark,
          surface: Colors.black,
        );
        expect(palette.isDark, isTrue);
        final audit = palette.auditCategorical();
        expect(audit.worstAdjacentCvdDeltaE, greaterThanOrEqualTo(8.0));
        expect(audit.minContrast, greaterThanOrEqualTo(3.0));
      }
    });

    testWidgets('slot order follows the entity, not the value', (tester) async {
      final first = await _paletteFor(
        tester,
        seed: const Color(0xFF3F51B5),
        brightness: Brightness.light,
      );
      final second = await _paletteFor(
        tester,
        seed: const Color(0xFF3F51B5),
        brightness: Brightness.light,
      );
      expect(second.categorical, equals(first.categorical));
    });
  });

  group('sequential ramp', () {
    for (final brightness in Brightness.values) {
      testWidgets('is monotone and separable in ${brightness.name} mode',
          (tester) async {
        for (final seed in seeds) {
          final palette = await _paletteFor(
            tester,
            seed: seed,
            brightness: brightness,
          );
          for (var steps = 2; steps <= 5; steps++) {
            final audit = palette.auditRamp(steps);
            final reason = '$steps steps, seed '
                '${seed.toARGB32().toRadixString(16)} (${brightness.name})';
            expect(audit.monotone, isTrue,
                reason: 'lightness must climb in one direction, $reason');
            expect(audit.minDeltaLightness, greaterThanOrEqualTo(.06),
                reason: 'adjacent steps must be tellable apart, $reason');
            expect(audit.faintEndContrast, greaterThanOrEqualTo(2.0),
                reason: 'the faint end still has to read as a mark, $reason');
            expect(audit.hueSpread, lessThan(4.0),
                reason: 'a sequential ramp is one hue, $reason');
          }
        }
      });
    }

    testWidgets('bins magnitude and keeps zero outside the ramp',
        (tester) async {
      final palette = await _paletteFor(
        tester,
        seed: const Color(0xFF00695C),
        brightness: Brightness.light,
      );
      final scale = palette.ramp(5);
      expect(palette.rampStep(0), equals(palette.emptyCell));
      expect(palette.rampStep(-1), equals(palette.emptyCell));
      expect(palette.rampStep(.01), equals(scale.first));
      expect(palette.rampStep(1), equals(scale.last));
      expect(palette.rampStep(2), equals(scale.last));
      // Binned on purpose: two nearby magnitudes share a step.
      expect(palette.rampStep(.62), equals(palette.rampStep(.78)));
      expect(scale.toSet(), hasLength(5));
    });

    testWidgets('runs pale to deep in light mode and the reverse in dark',
        (tester) async {
      final light = await _paletteFor(
        tester,
        seed: const Color(0xFF6750A4),
        brightness: Brightness.light,
      );
      final dark = await _paletteFor(
        tester,
        seed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      );
      final lightRamp = light.ramp(5);
      final darkRamp = dark.ramp(5);
      expect(
        lightRamp.first.computeLuminance(),
        greaterThan(lightRamp.last.computeLuminance()),
      );
      expect(
        darkRamp.first.computeLuminance(),
        lessThan(darkRamp.last.computeLuminance()),
      );
    });
  });

  testWidgets('grid and label ink stay recessive against the marks',
      (tester) async {
    final palette = await _paletteFor(
      tester,
      seed: const Color(0xFFB3261E),
      brightness: Brightness.light,
    );
    expect(palette.grid.a, lessThan(1.0));
    expect(
      _contrast(palette.labelInk, palette.surface),
      greaterThan(_contrast(palette.grid, palette.surface)),
    );
  });
}

Future<WellnessChartPalette> _paletteFor(
  WidgetTester tester, {
  required Color seed,
  required Brightness brightness,
  Color? surface,
}) async {
  WellnessChartPalette? captured;
  await tester.pumpWidget(
    MaterialApp(
      // MaterialApp lerps its theme, so a fresh key is what makes each pump
      // read the seed under test rather than the previous one.
      key: ValueKey('${seed.toARGB32()}-${brightness.name}-${surface?.toARGB32()}'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        ),
      ),
      home: Builder(
        builder: (context) {
          captured = WellnessChartPalette.of(context, surface: surface);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured!;
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}
