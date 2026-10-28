import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:watchtower/utils/constant.dart';

/// Horizontal picker of theme colours.
///
/// Each option is a rounded phone-shaped card that mimics the app's mobile
/// interface, so the user previews the actual colours before applying them.
class ThemeSelector extends ConsumerStatefulWidget {
  const ThemeSelector({super.key, this.contentPadding});
  final EdgeInsetsGeometry? contentPadding;

  @override
  ConsumerState<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends ConsumerState<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    int selected =
        (isar.settings.getSync(kSettingsId) ?? Settings()).flexSchemeColorIndex!;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 172,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: ThemeAA.schemes.length,
        itemBuilder: (context, index) {
          final scheme = ThemeAA.schemes[index];
          final flexColors = isLight ? scheme.light : scheme.dark;
          // Full Material scheme (surfaces, on-colors…) for an accurate preview.
          final colors = (isLight
                  ? FlexColorScheme.light(colors: flexColors)
                  : FlexColorScheme.dark(colors: flexColors))
              .toScheme;
          final isSelected = selected == index;

          return GestureDetector(
            onTap: () {
              setState(() => selected = index);
              ref
                  .read(flexSchemeColorStateProvider.notifier)
                  .setTheme(flexColors, index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer.withValues(alpha: 0.55)
                    : (isLight
                          ? cs.surfaceContainerHigh
                          : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? cs.primary
                      : cs.outline.withValues(alpha: isLight ? 0.45 : 0.22),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  // ── Phone preview ──────────────────────────────────────
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          // status bar
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              width: 22,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          // content block
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 7,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 5,
                                  width: 30,
                                  decoration: BoxDecoration(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.25,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _Dot(colors.secondary, 12),
                                    const SizedBox(width: 4),
                                    _Dot(colors.tertiary, 12),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // bottom navigation preview
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Dot(colors.primary, 6),
                                _Dot(
                                  colors.onPrimaryContainer.withValues(
                                    alpha: 0.4,
                                  ),
                                  6,
                                ),
                                _Dot(
                                  colors.onPrimaryContainer.withValues(
                                    alpha: 0.4,
                                  ),
                                  6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheme.name,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.65),
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot(this.color, this.size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
