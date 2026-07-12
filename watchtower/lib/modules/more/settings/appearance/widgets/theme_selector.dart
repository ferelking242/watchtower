import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:watchtower/utils/constant.dart';

class ThemeSelector extends ConsumerStatefulWidget {
  const ThemeSelector({super.key, this.contentPadding});
  final EdgeInsetsGeometry? contentPadding;

  @override
  ConsumerState<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends ConsumerState<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    int selected = (isar.settings.getSync(kSettingsId) ?? Settings()).flexSchemeColorIndex!;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: ThemeAA.schemes.length,
        itemBuilder: (context, index) {
          final scheme = ThemeAA.schemes[index];
          final colors = isLight ? scheme.light : scheme.dark;
          final isSelected = selected == index;

          return GestureDetector(
            onTap: () {
              setState(() => selected = index);
              ref
                  .read(flexSchemeColorStateProvider.notifier)
                  .setTheme(colors, index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 78,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer.withValues(alpha: 0.55)
                    : (isLight ? cs.surfaceContainerHigh : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(16),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ColorDot(color: colors.primary, size: 22),
                      const SizedBox(width: 3),
                      _ColorDot(color: colors.secondary, size: 16),
                      const SizedBox(width: 3),
                      _ColorDot(color: colors.tertiary, size: 11),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      scheme.name,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.65),
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_rounded,
                          size: 12, color: cs.primary),
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

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
}
