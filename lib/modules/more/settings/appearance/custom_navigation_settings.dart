import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class CustomNavigationSettings extends ConsumerWidget {
  const CustomNavigationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final navigationOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final mergeHubNavMobile = ref.watch(mergeLibraryNavMobileStateProvider);
    final mergeLibraryDock = ref.watch(mergeLibraryOnDockProvider);
    final showLabels = ref.watch(navShowLabelsProvider);
    final iconSize = ref.watch(navIconSizeProvider);
    final itemSpacing = ref.watch(navItemSpacingProvider);
    final haptic = ref.watch(navHapticProvider);
    final animSpeed = ref.watch(navAnimSpeedProvider);
    final dockStyle = ref.watch(navDockStyleProvider);
    final sidebarPosition = ref.watch(navSidebarPositionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsSubpageScaffold(
      title: l10n.reorder_navigation,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hub toggle ─────────────────────────────────────────────────
            Tooltip(
              message: l10n.nav_hub_tooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                child: SwitchListTile(
                  value: mergeHubNavMobile,
                  title: Text(l10n.nav_hub_title),
                  subtitle: Text(
                    l10n.nav_hub_subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Broken.category_2),
                  onChanged: (value) {
                    ref
                        .read(mergeLibraryNavMobileStateProvider.notifier)
                        .set(value);
                    if (!value) {
                      final hidden = ref.read(hideItemsStateProvider);
                      final updated = hidden.toList()
                        ..remove('/MangaLibrary')
                        ..remove('/AnimeLibrary')
                        ..remove('/NovelLibrary');
                      ref
                          .read(hideItemsStateProvider.notifier)
                          .set(updated);
                    }
                    botToast(
                      value ? l10n.nav_hub_enabled : l10n.nav_hub_disabled,
                    );
                  },
                ),
              ),
            ),

            // ── Library toggle ─────────────────────────────────────────────
            Tooltip(
              message: l10n.nav_merge_library_tooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                child: SwitchListTile(
                  value: mergeLibraryDock,
                  title: Text(l10n.nav_merge_library_title),
                  subtitle: Text(
                    l10n.nav_merge_library_subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Broken.book_saved),
                  onChanged: (value) {
                    ref.read(mergeLibraryOnDockProvider.notifier).set(value);
                    const libs = ['/MangaLibrary', '/AnimeLibrary', '/NovelLibrary', '/MusicLibrary', '/GameLibrary'];
                    final hidden = ref.read(hideItemsStateProvider);
                    if (value) {
                      final updated = hidden.toList();
                      for (final lib in libs) {
                        if (!updated.contains(lib)) updated.add(lib);
                      }
                      ref.read(hideItemsStateProvider.notifier).set(updated);
                    } else {
                      final updated = hidden.toList()..removeWhere(libs.contains);
                      ref.read(hideItemsStateProvider.notifier).set(updated);
                    }
                    botToast(
                      value
                          ? l10n.nav_merge_library_enabled
                          : l10n.nav_merge_library_disabled,
                    );
                  },
                ),
              ),
            ),

            const Divider(height: 16),

            // ── Éléments du dock — grille 3 par ligne ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                l10n.nav_dock_items,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: navigationOrder.length,
                itemBuilder: (context, index) {
                  final navigation = navigationOrder[index];
                  final label = navigationItemLabel(
                    context.l10n,
                    navigation,
                  );
                  final isVisible = !hideItems.contains(navigation);
                  final isFixed =
                      navigation == '/settings' || navigation == '/browse';
                  return GestureDetector(
                    onTap: isFixed
                        ? null
                        : () {
                            final temp = hideItems.toList();
                            if (isVisible) {
                              temp.add(navigation);
                            } else {
                              temp.remove(navigation);
                            }
                            ref
                                .read(hideItemsStateProvider.notifier)
                                .set(temp);
                            botToast(
                              isVisible
                                  ? l10n.nav_item_hidden(label)
                                  : l10n.nav_item_shown(label),
                            );
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isFixed
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4)
                            : isVisible
                                ? colorScheme.primaryContainer
                                    .withValues(alpha: 0.75)
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFixed
                              ? colorScheme.outline.withValues(alpha: 0.2)
                              : isVisible
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.3),
                          width: isVisible && !isFixed ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFixed
                                ? Broken.lock
                                : isVisible
                                    ? Broken.eye
                                    : Broken.eye_slash,
                            size: 13,
                            color: isFixed
                                ? colorScheme.onSurface.withValues(alpha: 0.35)
                                : isVisible
                                    ? colorScheme.primary
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isVisible
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isFixed
                                  ? colorScheme.onSurface.withValues(alpha: 0.45)
                                  : isVisible
                                      ? colorScheme.primary
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.5),
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
            ),

            const Divider(height: 24),

            // ── Dock style picker ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Broken.monitor_mobbile,
                          color: colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.nav_dock_style,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Mobile ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.nav_dock_mobile,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _DockPreviewCard(
                        label: l10n.nav_dock_classic,
                        description: l10n.nav_dock_classic_desc,
                        isSelected: dockStyle == 'classic',
                        child: _ClassicDockPreview(cs: colorScheme),
                        onTap: () {
                          ref.read(navDockStyleProvider.notifier).set('classic');
                          botToast(l10n.nav_dock_classic_set);
                        },
                      ),
                      const SizedBox(width: 10),
                      _DockPreviewCard(
                        label: l10n.nav_dock_immersive,
                        description: l10n.nav_dock_immersive_desc,
                        isSelected: dockStyle == 'immersive',
                        child: _ImmersiveDockPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('immersive');
                          botToast(l10n.nav_dock_immersive_set);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // ── PC / Tablet ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.nav_dock_pc_tablet,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _DockPreviewCard(
                        label: l10n.nav_dock_immersive,
                        description: l10n.nav_dock_immersive_desc,
                        isSelected: dockStyle == 'immersive',
                        child: _ImmersiveDockPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('immersive');
                          botToast(l10n.nav_dock_immersive_set);
                        },
                      ),
                      const SizedBox(width: 10),
                      _DockPreviewCard(
                        label: l10n.nav_dock_pc_sidebar,
                        description: l10n.nav_dock_pc_sidebar_desc,
                        isSelected: dockStyle == 'pc_sidebar',
                        child: _PcSidebarPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('pc_sidebar');
                          botToast(l10n.nav_dock_pc_sidebar_set);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  // ── PC sidebar side (left / right) ────────────────────
                  Row(
                    children: [
                      Tooltip(
                        message: l10n.nav_sidebar_side_tooltip,
                        child: const Icon(Broken.element_3, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.nav_sidebar_side,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment(
                            value: 'left',
                            label: Text(
                              l10n.nav_left,
                              style: const TextStyle(fontSize: 11),
                            ),
                            icon: const Icon(Broken.arrow_left_2, size: 15),
                          ),
                          ButtonSegment(
                            value: 'right',
                            label: Text(
                              l10n.nav_right,
                              style: const TextStyle(fontSize: 11),
                            ),
                            icon: const Icon(Broken.arrow_right_3, size: 15),
                          ),
                        ],
                        selected: {sidebarPosition},
                        onSelectionChanged: (s) {
                          ref
                              .read(navSidebarPositionProvider.notifier)
                              .set(s.first);
                          botToast(
                            s.first == 'right'
                                ? l10n.nav_sidebar_right
                                : l10n.nav_sidebar_left,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 28),

            // ── Advanced customisation (flat, no gray card) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Broken.setting_4, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l10n.nav_advanced_customisation,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Icon size
            _SettingSliderTile(
              icon: Broken.maximize_2,
              label: l10n.nav_icon_size,
              tooltip: l10n.nav_icon_size_tooltip,
              value: iconSize,
              min: 16,
              max: 36,
              displayValue: '${iconSize.toStringAsFixed(0)} px',
              onChanged: (v) {
                if (haptic) HapticFeedback.selectionClick();
                ref.read(navIconSizeProvider.notifier).set(v);
              },
            ),

            // Item spacing
            _SettingSliderTile(
              icon: Broken.slider_horizontal,
              label: l10n.nav_item_spacing,
              tooltip: l10n.nav_item_spacing_tooltip,
              value: itemSpacing,
              min: 0,
              max: 16,
              displayValue: '${itemSpacing.toStringAsFixed(0)} px',
              onChanged: (v) {
                if (haptic) HapticFeedback.selectionClick();
                ref.read(navItemSpacingProvider.notifier).set(v);
              },
            ),

            // Animation speed
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Tooltip(
                    message: l10n.nav_anim_speed_tooltip,
                    child: const Icon(Broken.arrow_swap, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.nav_anim_speed,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                          value: 0,
                          label: Text(l10n.off,
                              style: const TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 1,
                          label: Text(l10n.nav_normal,
                              style: const TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 2,
                          label: Text(l10n.nav_fast,
                              style: const TextStyle(fontSize: 11))),
                    ],
                    selected: {animSpeed},
                    onSelectionChanged: (s) {
                      ref.read(navAnimSpeedProvider.notifier).set(s.first);
                      final labels = [l10n.off, l10n.nav_normal, l10n.nav_fast];
                      botToast(l10n.nav_anim_speed_set(labels[s.first]));
                    },
                  ),
                ],
              ),
            ),

            // Show labels
            Tooltip(
              message: l10n.nav_show_labels_tooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  secondary: const Icon(Broken.tag, size: 18),
                  title: Text(l10n.nav_show_labels,
                      style: const TextStyle(fontSize: 13)),
                  value: showLabels,
                  onChanged: (v) {
                    ref.read(navShowLabelsProvider.notifier).set(v);
                    botToast(
                      v ? l10n.nav_labels_visible : l10n.nav_labels_hidden,
                    );
                  },
                ),
              ),
            ),

            // Haptic feedback
            Tooltip(
              message: l10n.nav_haptic_tooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  secondary: const Icon(Broken.mobile, size: 18),
                  title: Text(l10n.nav_haptic,
                      style: const TextStyle(fontSize: 13)),
                  value: haptic,
                  onChanged: (v) {
                    ref.read(navHapticProvider.notifier).set(v);
                    botToast(
                      v ? l10n.nav_haptic_enabled : l10n.nav_haptic_disabled,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Dock preview cards ────────────────────────────────────────────────────────

class _DockPreviewCard extends StatelessWidget {
  final String label;
  final String description;
  final bool isSelected;
  final Widget child;
  final VoidCallback onTap;

  const _DockPreviewCard({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primaryContainer.withValues(alpha: 0.6)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 54, child: child),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(Broken.tick_circle,
                    size: 14, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassicDockPreview extends StatelessWidget {
  final ColorScheme cs;
  const _ClassicDockPreview({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 38,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: cs.outline.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (i) => Icon(
              _previewIcons[i],
              size: 14,
              color: i == 0
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}


const _previewIcons = [
  Broken.category_2,
  Broken.global_search,
  Broken.clock_1,
  Broken.more_2,
];

// ── Slider tile ───────────────────────────────────────────────────────────────

class _ImmersiveDockPreview extends StatelessWidget {
    final ColorScheme cs;
    const _ImmersiveDockPreview({required this.cs});

    @override
    Widget build(BuildContext context) {
      return Center(
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withValues(alpha: 0.22), width: 0.8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(_previewIcons[i], size: 14,
                color: i == 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.45)),
            )),
          ),
        ),
      );
    }
  }

class _PcSidebarPreview extends StatelessWidget {
  final ColorScheme cs;
  const _PcSidebarPreview({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar strip
        Container(
          width: 24,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => Icon(
              _previewIcons[i],
              size: 10,
              color: i == 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
            )),
          ),
        ),
        const SizedBox(width: 4),
        // Content area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                Broken.grid_2,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

  class _SettingSliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SettingSliderTile({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tooltip(
                message: tooltip,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider.adaptive(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
