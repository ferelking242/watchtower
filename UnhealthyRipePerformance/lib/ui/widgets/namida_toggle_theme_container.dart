// Source: github.com/namidaco/namida — lib/ui/widgets/settings/theme_settings.dart (GPL-3.0)
// Watchtower adaptation: replaced Obx/ObxO + settings.themeMode with Riverpod
//   Consumer + themeModeStateProvider / followSystemThemeStateProvider.
//   Replaced NamidaInkWell → InkWell, multipliedRadius → plain double,
//   AppThemes.inst.getAppTheme → Theme.of(context).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';

// ── ToggleThemeModeContainer ───────────────────────────────────────────────────
// Direct copy of Namida ToggleThemeModeContainer, adapted for Watchtower's
// Riverpod theme state.  The 3 modes map to:
//   index 0 = Light   (themeModeState=false, followSystem=false)
//   index 1 = System  (followSystem=true)
//   index 2 = Dark    (themeModeState=true,  followSystem=false)

class ToggleThemeModeContainer extends ConsumerStatefulWidget {
  final double maxWidth;
  final double blurRadius;
  const ToggleThemeModeContainer({
    super.key,
    required this.maxWidth,
    this.blurRadius = 6.0,
  });

  static void onThemeChangeTap(int modeIndex, WidgetRef ref) {
    if (modeIndex == 1) {
      ref.read(followSystemThemeStateProvider.notifier).set(true);
    } else {
      final followSystem = ref.read(followSystemThemeStateProvider);
      if (followSystem) {
        ref.read(followSystemThemeStateProvider.notifier).set(false);
      }
      if (modeIndex == 0) {
        ref.read(themeModeStateProvider.notifier).setLightTheme();
      } else {
        ref.read(themeModeStateProvider.notifier).setDarkTheme();
      }
    }
  }

  @override
  ConsumerState<ToggleThemeModeContainer> createState() =>
      _ToggleThemeModeContainerState();
}

class _ToggleThemeModeContainerState
    extends ConsumerState<ToggleThemeModeContainer> {
  Widget? _cachedWidget;
  double? _cachedMaxWidth;

  Alignment _modeToAlignment(int mode) {
    return mode == 0
        ? Alignment.centerLeft
        : mode == 1
        ? Alignment.center
        : Alignment.centerRight;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeStateProvider);
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final int currentMode = followSystem ? 1 : (isDark ? 2 : 0);

    if (_cachedWidget != null && _cachedMaxWidth == widget.maxWidth) {
      return _cachedWidget!;
    }
    _cachedMaxWidth = widget.maxWidth;

    const brConst = 8.0;
    const horizontalPaddingConst = 8.0;
    const itemsCount = 3;
    final bgSlideWidth = (widget.maxWidth / itemsCount) - horizontalPaddingConst;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final modeIcons = [
      Broken.sun_1,
      Broken.lamp_1,
      Broken.moon,
    ];

    return _cachedWidget = RepaintBoundary(
      child: Builder(
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? cs.surfaceContainerHighest
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.12),
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
                Positioned.fill(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.fastLinearToSlowEaseIn,
                    alignment: _modeToAlignment(currentMode),
                    child: Container(
                      width: bgSlideWidth,
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(brConst),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(itemsCount, (i) {
                      return SizedBox(
                        width: bgSlideWidth,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(brConst),
                          onTap: () => ToggleThemeModeContainer.onThemeChangeTap(
                            i,
                            ref,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Icon(
                              modeIcons[i],
                              size: 18,
                              color: currentMode == i
                                  ? cs.primary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
