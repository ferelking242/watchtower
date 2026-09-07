// Copied from namidaco/namida — lib/ui/widgets/settings/theme_settings.dart
// Adapted for Watchtower: GetX → Riverpod, Namida singletons → Flutter Theme API
// Only ToggleThemeModeContainer extracted; ThemeSetting, NamidaColorPickerDialog removed (Namida-specific).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';

// Adapted: multipliedRadius (Namida ext) → inline constant
// Adapted: e.toIcon() (Namida ext on ThemeMode) → _themeModeIcon()
// Adapted: NamidaInkWell → InkWell
// Adapted: ObxO / Obx (GetX) → ConsumerStatefulWidget / ref.watch
// Adapted: settings.themeMode (GetX Rx) → followSystemThemeStateProvider + themeModeStateProvider
// Adapted: CurrentColor.inst.color → Theme.of(context) colorScheme
// Adapted: AppThemes.inst.getAppTheme(...) → Theme.of(context)
// Adapted: YoutubeMiniplayerUiController.inst.startDimTimer() → removed (Namida-only)
// Adapted: kThemeAnimationDurationMS → 300

class ToggleThemeModeContainer extends ConsumerStatefulWidget {
  final double maxWidth;
  final double blurRadius;
  const ToggleThemeModeContainer({
    super.key,
    required this.maxWidth,
    this.blurRadius = 6.0,
  });

  // Adapted from Namida onThemeChangeTap:
  //   settings.save(themeMode: themeMode) → Riverpod notifiers
  //   CurrentColor.inst.updateColorAfterThemeModeChange() → no-op (auto via Riverpod)
  //   YoutubeMiniplayerUiController.inst.startDimTimer() → removed
  static void onThemeChangeTap(ThemeMode themeMode, WidgetRef ref) async {
    if (themeMode == ThemeMode.system) {
      ref.read(followSystemThemeStateProvider.notifier).set(true);
    } else {
      if (ref.read(followSystemThemeStateProvider)) {
        ref.read(followSystemThemeStateProvider.notifier).set(false);
      }
      if (themeMode == ThemeMode.light) {
        ref.read(themeModeStateProvider.notifier).setLightTheme();
      } else {
        ref.read(themeModeStateProvider.notifier).setDarkTheme();
      }
    }
    await Future.delayed(const Duration(milliseconds: 300)); // kThemeAnimationDurationMS
  }

  @override
  ConsumerState<ToggleThemeModeContainer> createState() =>
      _ToggleThemeModeContainerState();
}

class _ToggleThemeModeContainerState
    extends ConsumerState<ToggleThemeModeContainer> {
  // Namida uses _cachedWidget for perf; kept but invalidated on theme change
  Widget? _cachedWidget;

  @override
  void didUpdateWidget(ToggleThemeModeContainer old) {
    super.didUpdateWidget(old);
    if (old.maxWidth != widget.maxWidth) {
      _cachedWidget = null;
    }
  }

  // Copied verbatim from Namida _themeModeToAlignment
  Alignment _themeModeToAlignment(ThemeMode theme) {
    return theme == ThemeMode.light
        ? Alignment.center
        : theme == ThemeMode.dark
            ? Alignment.centerRight
            : Alignment.centerLeft;
  }

  // Adapted: e.toIcon() Namida extension on ThemeMode
  IconData _themeModeToIcon(ThemeMode e) {
    switch (e) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adapted: ObxO(rx: settings.themeMode, ...) → ref.watch Riverpod
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final isDark = ref.watch(themeModeStateProvider);
    final ThemeMode currentTheme = followSystem
        ? ThemeMode.system
        : (isDark ? ThemeMode.dark : ThemeMode.light);

    // Invalidate cached widget on mode change so animation re-triggers
    _cachedWidget = null;

    const brConst = 8.0;
    const horizontalPaddingConst = 8.0;
    final itemsCount = ThemeMode.values.length;
    final bgSlideWidth = (widget.maxWidth / itemsCount) - horizontalPaddingConst;

    // Adapted: AppThemes.inst.getAppTheme(CurrentColor.inst.color, !context.isDarkMode)
    //          → Theme.of(context)  (FlexColorScheme already handles light/dark)
    final theme = Theme.of(context);

    // Copied from Namida: Color.alphaBlend(theme.listTileTheme.textColor!.withAlpha(200), Colors.white.withAlpha(160))
    final containerBg = Color.alphaBlend(
      (theme.listTileTheme.textColor ?? theme.colorScheme.onSurface)
          .withAlpha(200),
      Colors.white.withAlpha(160),
    );

    return _cachedWidget = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: containerBg,
          // Adapted: 12.0.multipliedRadius → 12.0
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              // Copied from Namida
              color: (theme.listTileTheme.iconColor ??
                      theme.colorScheme.primary)
                  .withAlpha(80),
              spreadRadius: 1.0,
              blurRadius: widget.blurRadius,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        width: widget.maxWidth,
        padding: const EdgeInsets.symmetric(
          vertical: 5.0,
          horizontal: horizontalPaddingConst,
        ),
        child: Stack(
          children: [
            // Copied verbatim from Namida (sliding pill animation)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastLinearToSlowEaseIn,
                alignment: _themeModeToAlignment(currentTheme),
                child: Container(
                  width: bgSlideWidth,
                  decoration: BoxDecoration(
                    // Copied from Namida
                    color: theme.colorScheme.surface.withAlpha(180),
                    // Adapted: brConst.multipliedRadius → brConst
                    borderRadius: BorderRadius.circular(brConst),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Copied from Namida; NamidaInkWell → InkWell + e.toIcon() → _themeModeToIcon
                  ...ThemeMode.values.map(
                    (e) => SizedBox(
                      width: bgSlideWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(brConst),
                        // Adapted: ToggleThemeModeContainer.onThemeChangeTap(e) → pass ref
                        onTap: () =>
                            ToggleThemeModeContainer.onThemeChangeTap(e, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Icon(
                            _themeModeToIcon(e),
                            // Copied from Namida
                            color: currentTheme == e
                                ? (theme.listTileTheme.iconColor ??
                                    theme.colorScheme.primary)
                                : theme.colorScheme.surface.withAlpha(180),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
