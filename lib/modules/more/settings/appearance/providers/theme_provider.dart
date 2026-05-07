import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blend_level_state_provider.dart';
import 'flex_scheme_color_state_provider.dart';
import 'pure_black_dark_mode_state_provider.dart';
import 'app_font_family.dart';

/// Provides the light theme for the app, recomputed only when
/// flex scheme colors, blend level, or font family change.
final lightThemeProvider = Provider<ThemeData>((ref) {
  final colors = ref.watch(flexSchemeColorStateProvider);
  final blendLevel = ref.watch(blendLevelStateProvider).toInt();
  final fontFamily = ref.watch(appFontFamilyProvider);

  return FlexThemeData.light(
    colors: colors,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: blendLevel,
    appBarOpacity: 0.00,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      thinBorderWidth: 2.0,
      unselectedToggleIsColored: true,
      inputDecoratorRadius: 24.0,
      chipRadius: 24.0,
    ),
    useMaterial3ErrorColors: true,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: fontFamily,
  );
});

/// Provides the dark theme for the app — cinematic deep dark palette.
final darkThemeProvider = Provider<ThemeData>((ref) {
  final colors = ref.watch(flexSchemeColorStateProvider);
  final blendLevel = ref.watch(blendLevelStateProvider).toInt();
  final fontFamily = ref.watch(appFontFamilyProvider);
  final pureBlack = ref.watch(pureBlackDarkModeStateProvider);

  // Cinematic deep background: near-black with a faint blue-indigo tint
  const cinematicBg = Color(0xFF080A14);

  return FlexThemeData.dark(
    colors: colors,
    surfaceMode: FlexSurfaceMode.highScaffoldLevelSurface,
    blendLevel: blendLevel,
    appBarOpacity: 0.00,
    scaffoldBackground: pureBlack ? Colors.black : cinematicBg,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 14,
      thinBorderWidth: 2.0,
      unselectedToggleIsColored: true,
      inputDecoratorRadius: 24.0,
      chipRadius: 24.0,
    ),
    useMaterial3ErrorColors: true,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    fontFamily: fontFamily,
  );
});
