import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blend_level_state_provider.dart';
import 'flex_scheme_color_state_provider.dart';
import 'pure_black_dark_mode_state_provider.dart';
import 'app_font_family.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Platform-aware font fallback.
//
// Problem: fontFamilyFallback: ['Roboto', 'sans-serif', ...] works on Android
// because 'sans-serif' maps to Noto Sans, which covers Arabic, Devanagari,
// Thai, CJK, etc. On iOS, 'sans-serif' maps to Helvetica Neue / SF Pro, which
// only covers Latin/Greek/Cyrillic. The other fonts in the list (Roboto,
// Noto Color Emoji, Segoe UI Emoji) don't exist on iOS either. When Flutter
// exhausts the fallback list on iOS without finding a glyph, it renders □
// boxes instead of falling through to the OS font cascade.
//
// Fix: on iOS/macOS, pass an *empty* fallback list. This tells the platform
// text engine to use its own internal font cascade, which covers all Unicode
// scripts natively (GeezaPro for Arabic, Kohinoor Devanagari for Hindi, etc.).
// On Android/Web/Desktop, keep 'sans-serif' → Noto Sans for full coverage.
// ─────────────────────────────────────────────────────────────────────────────
List<String> get _platformFontFallback {
  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    // Empty list → let iOS/macOS native cascade handle all scripts.
    return const [];
  }
  // Android: 'sans-serif' → Noto Sans → full Unicode coverage.
  // Web/Desktop: best-effort cross-platform fonts.
  return const ['Roboto', 'sans-serif', 'Apple Color Emoji', 'Noto Color Emoji', 'Segoe UI Emoji'];
}

/// Provides the light theme for the app, recomputed only when
/// flex scheme colors, blend level, or font family change.
final lightThemeProvider = Provider<ThemeData>((ref) {
  final colors = ref.watch(flexSchemeColorStateProvider);
  final blendLevel = ref.watch(blendLevelStateProvider).toInt();
  final fontFamily = ref.watch(appFontFamilyProvider);

  final base = FlexThemeData.light(
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
  final fallback = _platformFontFallback;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
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

  final baseDark = FlexThemeData.dark(
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
  final fallback = _platformFontFallback;
  return baseDark.copyWith(
    textTheme: baseDark.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: baseDark.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
});
