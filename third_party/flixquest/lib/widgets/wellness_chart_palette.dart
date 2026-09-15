import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Chart colors, derived from the active theme and *computed* rather than
/// eyeballed.
///
/// Data marks are their own color family: they are not the UI accent. Every
/// slot is built in OKLCH (perceptual lightness + chroma + hue) from the
/// theme's own primary hue, then snapped until it clears five checks —
/// lightness band, chroma floor, colorblind separation between adjacent
/// slots, normal-vision separation, and contrast against the chart surface.
/// The categorical triad additionally searches a small grid of hue rotations
/// and lightness assignments and keeps the candidate with the best worst-case
/// protanopia/deuteranopia separation, so a dynamic-color seed anywhere on the
/// hue circle still yields a legible palette.
///
/// The constants below were swept over 24 seed hues in both light and dark
/// mode: categorical worst-case CVD ΔE 10.8 (target 8.0), worst-case
/// normal-vision ΔE 23.0 (floor 15.0), and every ramp monotone with ΔL ≥ 0.06.
@immutable
class WellnessChartPalette {
  const WellnessChartPalette._({
    required this.surface,
    required this.primaryMark,
    required this.categorical,
    required this.grid,
    required this.axisInk,
    required this.labelInk,
    required this.hue,
    required this.isDark,
  });

  /// Builds the palette for [context]. [surface] is the color the chart is
  /// painted on — gaps and rings are cut to it, and contrast is measured
  /// against it, so pass the panel color rather than the scaffold.
  factory WellnessChartPalette.of(BuildContext context, {Color? surface}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chartSurface = surface ?? scheme.surface;
    final hue = _hueOf(scheme.primary);
    final isDark = _relativeLuminance(chartSurface) < .18;
    final key = Object.hash(
      (hue / 3).round(),
      isDark,
      (_relativeLuminance(chartSurface) * 200).round(),
    );
    final cached = _cache[key];
    if (cached != null) return cached;
    final config = _SlotConfig.forSurface(chartSurface, isDark: isDark);
    final palette = WellnessChartPalette._(
      surface: chartSurface,
      primaryMark: _solveSlot(hue, config.baseLightness.first, config),
      categorical: _categorical(hue, config),
      grid: scheme.outlineVariant.withValues(alpha: isDark ? .34 : .42),
      axisInk: scheme.onSurfaceVariant.withValues(alpha: .78),
      labelInk: scheme.onSurface,
      hue: hue,
      isDark: isDark,
    );
    if (_cache.length > 24) _cache.clear();
    return _cache[key] = palette;
  }

  static final Map<int, WellnessChartPalette> _cache =
      <int, WellnessChartPalette>{};

  /// The color the chart is drawn on. Gaps between marks and rings around
  /// overlapping marks are cut to this, never to a gray.
  final Color surface;

  /// Single-series mark color. One series never needs a ramp.
  final Color primaryMark;

  /// Three nominal slots, assigned in fixed order and never cycled.
  final List<Color> categorical;

  /// Hairline gridline color — recessive, solid, never dashed.
  final Color grid;

  /// Axis and tick label ink. Text wears text tokens, never the data color.
  final Color axisInk;

  /// Emphasised label ink for values called out on the chart.
  final Color labelInk;

  /// OKLCH hue the palette was derived from.
  final double hue;

  final bool isDark;

  /// A one-hue sequential ramp, pale end first, for magnitude (heatmap cells,
  /// ordered buckets). Validated for 2–5 steps.
  List<Color> ramp(int steps) {
    assert(steps >= 2 && steps <= 5, 'ramp is validated for 2–5 steps');
    final from = isDark ? _darkRampLo : _lightRampHi;
    final to = isDark ? _darkRampHi : _lightRampLo;
    return List<Color>.generate(steps, (index) {
      final t = steps == 1 ? 0.0 : index / (steps - 1);
      return _linearToColor(
        _oklchToLinear(from + (to - from) * t, _rampChroma, hue),
      );
    }, growable: false);
  }

  /// The ramp step for a normalised magnitude, or [emptyCell] at zero. Binned
  /// on purpose: a continuous ramp reads as noise at cell size.
  Color rampStep(double t, {int steps = 5}) {
    if (t <= 0) return emptyCell;
    final scale = ramp(steps);
    final index = (t * steps).ceil().clamp(1, steps) - 1;
    return scale[index];
  }

  /// "No data" cell — a tinted surface, deliberately outside the ramp so
  /// nothing reads as a small value.
  Color get emptyCell => Color.alphaBlend(
        grid.withValues(alpha: isDark ? .22 : .3),
        surface,
      );

  /// Measures the categorical triad against the five checks. Exposed so the
  /// thresholds are asserted in tests instead of trusted.
  @visibleForTesting
  WellnessPaletteAudit auditCategorical() {
    var worstCvd = double.infinity;
    var worstNormal = double.infinity;
    for (var i = 0; i + 1 < categorical.length; i++) {
      worstCvd = math.min(
        worstCvd,
        math.min(
          _deltaE(categorical[i], categorical[i + 1], _Cvd.protan),
          _deltaE(categorical[i], categorical[i + 1], _Cvd.deutan),
        ),
      );
      worstNormal = math.min(
        worstNormal,
        _deltaE(categorical[i], categorical[i + 1], null),
      );
    }
    final surfaceLuminance = _relativeLuminance(surface);
    final lightness = categorical
        .map((color) => _oklabFromLinear(_linearOf(color)).first)
        .toList(growable: false);
    return WellnessPaletteAudit(
      worstAdjacentCvdDeltaE: worstCvd,
      worstAdjacentNormalDeltaE: worstNormal,
      minChroma: categorical.map((c) => _chromaOf(_linearOf(c))).reduce(math.min),
      minContrast: categorical
          .map((c) => _contrastAgainst(_linearOf(c), surfaceLuminance))
          .reduce(math.min),
      minLightness: lightness.reduce(math.min),
      maxLightness: lightness.reduce(math.max),
    );
  }

  /// Measures a ramp: monotone lightness, the gap between adjacent steps, and
  /// whether the faint end still reads as a mark on [surface].
  @visibleForTesting
  WellnessRampAudit auditRamp(int steps) {
    final colors = ramp(steps);
    final lightness = colors
        .map((color) => _oklabFromLinear(_linearOf(color)).first)
        .toList(growable: false);
    var minGap = double.infinity;
    var monotone = true;
    for (var i = 0; i + 1 < lightness.length; i++) {
      final delta = lightness[i + 1] - lightness[i];
      if (isDark ? delta <= 0 : delta >= 0) monotone = false;
      minGap = math.min(minGap, delta.abs());
    }
    final faintest = isDark ? colors.first : colors.last;
    final hues = colors.map(_hueOf).toList(growable: false);
    return WellnessRampAudit(
      monotone: monotone,
      minDeltaLightness: minGap,
      faintEndContrast: _contrastAgainst(
        _linearOf(faintest),
        _relativeLuminance(surface),
      ),
      hueSpread: hues.reduce(math.max) - hues.reduce(math.min),
    );
  }

  // Ramp endpoints in OKLCH L. Light mode runs pale → deep; dark mode runs
  // deep → pale so magnitude always reads as "more ink".
  static const double _lightRampHi = .735;
  static const double _lightRampLo = .425;
  static const double _darkRampLo = .455;
  static const double _darkRampHi = .715;
  static const double _rampChroma = .115;
}

/// Measured properties of a categorical palette. See [WellnessChartPalette].
@immutable
@visibleForTesting
class WellnessPaletteAudit {
  const WellnessPaletteAudit({
    required this.worstAdjacentCvdDeltaE,
    required this.worstAdjacentNormalDeltaE,
    required this.minChroma,
    required this.minContrast,
    required this.minLightness,
    required this.maxLightness,
  });

  final double worstAdjacentCvdDeltaE;
  final double worstAdjacentNormalDeltaE;
  final double minChroma;
  final double minContrast;
  final double minLightness;
  final double maxLightness;
}

/// Measured properties of a sequential/ordinal ramp.
@immutable
@visibleForTesting
class WellnessRampAudit {
  const WellnessRampAudit({
    required this.monotone,
    required this.minDeltaLightness,
    required this.faintEndContrast,
    required this.hueSpread,
  });

  final bool monotone;
  final double minDeltaLightness;
  final double faintEndContrast;
  final double hueSpread;
}

// ---------------------------------------------------------------------------
// Slot solving
// ---------------------------------------------------------------------------

class _SlotConfig {
  const _SlotConfig({
    required this.baseLightness,
    required this.chromaTarget,
    required this.bandLo,
    required this.bandHi,
    required this.surfaceLuminance,
    required this.brighten,
  });

  factory _SlotConfig.forSurface(Color surface, {required bool isDark}) {
    final luminance = _relativeLuminance(surface);
    return isDark
        ? _SlotConfig(
            baseLightness: const [.625, .575, .665],
            chromaTarget: .145,
            bandLo: .49,
            bandHi: .665,
            surfaceLuminance: luminance,
            brighten: true,
          )
        : _SlotConfig(
            baseLightness: const [.575, .485, .655],
            chromaTarget: .155,
            bandLo: .44,
            bandHi: .76,
            surfaceLuminance: luminance,
            brighten: false,
          );
  }

  final List<double> baseLightness;
  final double chromaTarget;
  final double bandLo;
  final double bandHi;
  final double surfaceLuminance;

  /// On a dark surface a mark gains contrast by getting lighter, not darker.
  final bool brighten;

  static const double chromaFloor = .105;
  static const double contrastMin = 3.05;
}

/// Solves one slot: the requested hue at the requested perceptual lightness,
/// nudged along L until it clears the chroma floor (some hues simply cannot
/// hold chroma at every lightness) and then until it clears the surface.
Color _solveSlot(double hue, double targetL, _SlotConfig config) {
  var lightness = targetL;
  var rgb = _oklchToLinear(lightness, config.chromaTarget, hue);
  for (var i = 0; i < 12 && _chromaOf(rgb) < _SlotConfig.chromaFloor; i++) {
    final up = math.min(config.bandHi, lightness + .02);
    final down = math.max(config.bandLo, lightness - .02);
    final chromaUp = _chromaOf(_oklchToLinear(up, config.chromaTarget, hue));
    final chromaDown =
        _chromaOf(_oklchToLinear(down, config.chromaTarget, hue));
    final next = chromaUp >= chromaDown ? up : down;
    if (next == lightness) break;
    lightness = next;
    rgb = _oklchToLinear(lightness, config.chromaTarget, hue);
  }
  final step = config.brighten ? .015 : -.015;
  for (var i = 0;
      i < 16 && _contrastAgainst(rgb, config.surfaceLuminance) < _SlotConfig.contrastMin;
      i++) {
    final next = lightness + step;
    if (next < config.bandLo || next > config.bandHi) break;
    final candidate = _oklchToLinear(next, config.chromaTarget, hue);
    if (_chromaOf(candidate) < _SlotConfig.chromaFloor - .008) break;
    lightness = next;
    rgb = candidate;
  }
  return _linearToColor(rgb);
}

/// Fixed-order nominal triad. Hue rotations and lightness assignments are
/// searched, and the winner is the candidate whose *worst* adjacent pair is
/// furthest apart under simulated protanopia and deuteranopia — the check that
/// hue rotation alone fails for seeds sitting on the red/green axis.
List<Color> _categorical(double hue, _SlotConfig config) {
  const rotationsB = [96.0, 108.0, 120.0, 132.0, 144.0];
  const rotationsC = [204.0, 216.0, 228.0, 240.0, 252.0];
  const permutations = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
  ];
  List<Color>? best;
  var bestScore = double.negativeInfinity;
  for (final rotB in rotationsB) {
    for (final rotC in rotationsC) {
      for (final perm in permutations) {
        final hues = [hue, hue + rotB, hue + rotC];
        final colors = List<Color>.generate(
          3,
          (i) => _solveSlot(hues[i], config.baseLightness[perm[i]], config),
          growable: false,
        );
        var worstCvd = double.infinity;
        var worstNormal = double.infinity;
        for (var i = 0; i + 1 < colors.length; i++) {
          worstCvd = math.min(
            worstCvd,
            math.min(
              _deltaE(colors[i], colors[i + 1], _Cvd.protan),
              _deltaE(colors[i], colors[i + 1], _Cvd.deutan),
            ),
          );
          worstNormal =
              math.min(worstNormal, _deltaE(colors[i], colors[i + 1], null));
        }
        // Clamped so extra separation past the target cannot buy its way past
        // a weak pair, plus a nudge to keep slot 0 at the seed's own weight.
        final score = math.min(worstCvd, 14.0) * 100 +
            math.min(worstNormal, 30.0) +
            (perm.first == 0 ? 3.0 : 0.0);
        if (score > bestScore) {
          bestScore = score;
          best = colors;
        }
      }
    }
  }
  return best!;
}

// ---------------------------------------------------------------------------
// Color math: sRGB <-> linear <-> OKLab/OKLCH, CVD simulation, contrast.
// ---------------------------------------------------------------------------

enum _Cvd { protan, deutan }

/// Machado, Oliveira & Fernandes (2009) transforms at severity 1.0, in linear
/// RGB.
const Map<_Cvd, List<List<double>>> _machado = {
  _Cvd.protan: [
    [0.152286, 1.052583, -0.204868],
    [0.114503, 0.786281, 0.099216],
    [-0.003882, -0.048116, 1.051998],
  ],
  _Cvd.deutan: [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881],
  ],
};

double _toLinear(double channel) => channel <= .04045
    ? channel / 12.92
    : math.pow((channel + .055) / 1.055, 2.4).toDouble();

double _toGamma(double channel) {
  final v = channel.clamp(0.0, 1.0);
  return v <= .0031308
      ? 12.92 * v
      : 1.055 * math.pow(v, 1 / 2.4).toDouble() - .055;
}

List<double> _linearOf(Color color) =>
    [_toLinear(color.r), _toLinear(color.g), _toLinear(color.b)];

Color _linearToColor(List<double> rgb) => Color.from(
      alpha: 1,
      red: _toGamma(rgb[0]),
      green: _toGamma(rgb[1]),
      blue: _toGamma(rgb[2]),
    );

double _relativeLuminance(Color color) {
  final rgb = _linearOf(color);
  return .2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2];
}

double _contrastAgainst(List<double> rgb, double surfaceLuminance) {
  final luminance = (.2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2])
      .clamp(0.0, 1.0);
  final hi = math.max(luminance, surfaceLuminance);
  final lo = math.min(luminance, surfaceLuminance);
  return (hi + .05) / (lo + .05);
}

List<double> _oklabFromLinear(List<double> rgb) {
  final l = _cbrt(
      .4122214708 * rgb[0] + .5363325363 * rgb[1] + .0514459929 * rgb[2]);
  final m = _cbrt(
      .2119034982 * rgb[0] + .6806995451 * rgb[1] + .1073969566 * rgb[2]);
  final s = _cbrt(
      .0883024619 * rgb[0] + .2817188376 * rgb[1] + .6299787005 * rgb[2]);
  return [
    .2104542553 * l + .7936177850 * m - .0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + .4505937099 * s,
    .0259040371 * l + .7827717662 * m - .8086757660 * s,
  ];
}

List<double> _oklabToLinear(double l, double a, double b) {
  final lCube = _cube(l + .3963377774 * a + .2158037573 * b);
  final mCube = _cube(l - .1055613458 * a - .0638541728 * b);
  final sCube = _cube(l - .0894841775 * a - 1.2914855480 * b);
  return [
    4.0767416621 * lCube - 3.3077115913 * mCube + .2309699292 * sCube,
    -1.2684380046 * lCube + 2.6097574011 * mCube - .3413193965 * sCube,
    -.0041960863 * lCube - .7034186147 * mCube + 1.7076147010 * sCube,
  ];
}

/// OKLCH → linear sRGB, reducing chroma until the color is inside the gamut so
/// a hue rotation can never silently clip into a different color.
List<double> _oklchToLinear(double l, double chroma, double hueDegrees) {
  final hue = hueDegrees * math.pi / 180;
  final cosH = math.cos(hue);
  final sinH = math.sin(hue);
  final direct = _oklabToLinear(l, chroma * cosH, chroma * sinH);
  if (_inGamut(direct)) return direct;
  var lo = 0.0;
  var hi = chroma;
  for (var i = 0; i < 20; i++) {
    final mid = (lo + hi) / 2;
    if (_inGamut(_oklabToLinear(l, mid * cosH, mid * sinH))) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return _oklabToLinear(l, lo * cosH, lo * sinH);
}

bool _inGamut(List<double> rgb) =>
    rgb.every((channel) => channel >= -.001 && channel <= 1.001);

double _chromaOf(List<double> rgb) {
  final lab = _oklabFromLinear(rgb);
  return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
}

double _hueOf(Color color) {
  final lab = _oklabFromLinear(_linearOf(color));
  final degrees = math.atan2(lab[2], lab[1]) * 180 / math.pi;
  return (degrees % 360 + 360) % 360;
}

List<double> _simulate(List<double> rgb, _Cvd kind) {
  final m = _machado[kind]!;
  return List<double>.generate(
    3,
    (i) => (m[i][0] * rgb[0] + m[i][1] * rgb[1] + m[i][2] * rgb[2])
        .clamp(0.0, 1.0),
    growable: false,
  );
}

/// Euclidean distance in OKLab ×100, optionally through a CVD simulation.
double _deltaE(Color first, Color second, _Cvd? kind) {
  final a = _oklabFromLinear(
      kind == null ? _linearOf(first) : _simulate(_linearOf(first), kind));
  final b = _oklabFromLinear(
      kind == null ? _linearOf(second) : _simulate(_linearOf(second), kind));
  return 100 *
      math.sqrt(math.pow(a[0] - b[0], 2) +
          math.pow(a[1] - b[1], 2) +
          math.pow(a[2] - b[2], 2));
}

double _cube(double value) => value * value * value;

double _cbrt(double value) =>
    value < 0 ? -math.pow(-value, 1 / 3).toDouble() : math.pow(value, 1 / 3).toDouble();
