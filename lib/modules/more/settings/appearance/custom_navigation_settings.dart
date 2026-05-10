import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reorder_navigation)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ââ Hub toggle âââââââââââââââââââââââââââââââââââââââââââââââââ
            Tooltip(
              message: 'When ON: Manga/Watch/Novel are hidden behind a single Hub button on the dock.',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                child: SwitchListTile(
                  value: mergeHubNavMobile,
                  title: const Text('Hub navigation on mobile'),
                  subtitle: const Text(
                    'Merges Manga Â· Watch Â· Novel under one Hub button',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Icons.apps_rounded),
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
                      value
                          ? 'Hub enabled â Manga, Watch & Novel are now behind the Hub button'
                          : 'Hub disabled â Manga, Watch & Novel appear separately on the dock',
                    );
                  },
                ),
              ),
            ),

            // ââ Library toggle âââââââââââââââââââââââââââââââââââââââââââââ
            Tooltip(
              message: 'When ON: a unified Library tab appears on the dock (all types in one page).',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                child: SwitchListTile(
                  value: mergeLibraryDock,
                  title: const Text('Library navigation on mobile'),
                  subtitle: const Text(
                    'Shows a unified Library page on the dock',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Icons.collections_bookmark_rounded),
                  onChanged: (value) {
                    ref.read(mergeLibraryOnDockProvider.notifier).set(value);
                    botToast(
                      value
                          ? 'Library tab enabled â a unified Library page is now on the dock'
                          : 'Library tab disabled â removed from dock',
                    );
                  },
                ),
              ),
            ),

            const Divider(height: 16),

            // ââ Reorderable navigation items âââââââââââââââââââââââââââââââ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(
                height: navigationOrder.length * 52.0,
                child: ReorderableListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: navigationOrder.length,
                  itemBuilder: (context, index) {
                    final navigation = navigationOrder[index];
                    return Row(
                      key: Key('navigation_$navigation'),
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        Expanded(
                          child: Tooltip(
                            message: 'Long-press to reorder. Toggle to show/hide this item.',
                            child: SwitchListTile(
                              key: Key(navigation),
                              dense: true,
                              value: !hideItems.contains(navigation),
                              onChanged: [
                                "/more",
                                "/browse",
                              ].any((element) => element == navigation)
                                  ? null
                                  : (value) {
                                      final temp = hideItems.toList();
                                      if (!value &&
                                          !hideItems.contains(navigation)) {
                                        temp.add(navigation);
                                      } else if (value) {
                                        temp.remove(navigation);
                                      }
                                      ref
                                          .read(hideItemsStateProvider.notifier)
                                          .set(temp);
                                      final label =
                                          navigationItems[navigation] ??
                                              navigation;
                                      botToast(
                                        value
                                            ? '$label is now visible on the dock'
                                            : '$label is now hidden from the dock',
                                      );
                                    },
                              title: Text(navigationItems[navigation]!),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    final order = navigationOrder.toList();
                    if (oldIndex < newIndex) {
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex - 1, item);
                    } else {
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                    }
                    ref
                        .read(navigationOrderStateProvider.notifier)
                        .set(order);
                  },
                ),
              ),
            ),

            const Divider(height: 24),

            // ââ Dock style picker ââââââââââââââââââââââââââââââââââââââââââ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dock_rounded,
                          color: colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Dock style',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DockPreviewCard(
                        label: 'Floating',
                        description: 'Pill dock',
                        isSelected: dockStyle == 'floating',
                        child: _FloatingDockPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('floating');
                          botToast(
                              'Dock style: Floating pill â the dock hovers above the screen edge');
                        },
                      ),
                      const SizedBox(width: 10),
                      _DockPreviewCard(
                        label: 'Classic',
                        description: 'Full-width bar',
                        isSelected: dockStyle == 'classic',
                        child: _ClassicDockPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('classic');
                          botToast(
                              'Dock style: Classic â standard full-width bottom navigation bar');
                        },
                      ),
                      const SizedBox(width: 10),
                      _DockPreviewCard(
                        label: 'Minimal',
                        description: 'Dot indicators',
                        isSelected: dockStyle == 'minimal',
                        child: _MinimalDockPreview(cs: colorScheme),
                        onTap: () {
                          ref
                              .read(navDockStyleProvider.notifier)
                              .set('minimal');
                          botToast(
                              'Dock style: Minimal â icon-only with subtle dot indicator, no labels');
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _DockPreviewCard(
                            label: 'Rounded',
                            description: 'Wide pill bar',
                            isSelected: dockStyle == 'rounded_full',
                            child: _RoundedFullDockPreview(cs: colorScheme),
                            onTap: () { ref.read(navDockStyleProvider.notifier).set('rounded_full'); botToast('Dock style: Rounded — full-width pill with rounded caps'); },
                          ),
                          const SizedBox(width: 10),
                          _DockPreviewCard(
                            label: 'Compact',
                            description: 'Icons only, slim',
                            isSelected: dockStyle == 'compact',
                            child: _CompactDockPreview(cs: colorScheme),
                            onTap: () { ref.read(navDockStyleProvider.notifier).set('compact'); botToast('Dock style: Compact — slim icon-only bar'); },
                          ),
                          const SizedBox(width: 10),
                          _DockPreviewCard(
                            label: 'Immersive',
                            description: 'Glass overlay',
                            isSelected: dockStyle == 'immersive',
                            child: _ImmersiveDockPreview(cs: colorScheme),
                            onTap: () { ref.read(navDockStyleProvider.notifier).set('immersive'); botToast('Dock style: Immersive — translucent glass dock'); },
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 28),

            // ââ Advanced customisation (flat, no gray card) ââââââââââââââââ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Customisation',
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
              icon: Icons.photo_size_select_small_rounded,
              label: 'Icon size',
              tooltip: 'Changes the size of dock icons. Affects all dock items.',
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
              icon: Icons.space_bar_rounded,
              label: 'Item spacing',
              tooltip:
                  'Controls horizontal gap between each dock item. 0 = no gap, 16 = wide gap.',
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
                    message:
                        'Controls the speed of dock transitions and selection animations.',
                    child: const Icon(Icons.animation_rounded, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Animation speed',
                        style: TextStyle(fontSize: 13)),
                  ),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                          value: 0,
                          label: Text('Off', style: TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 1,
                          label:
                              Text('Normal', style: TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 2,
                          label: Text('Fast', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {animSpeed},
                    onSelectionChanged: (s) {
                      ref.read(navAnimSpeedProvider.notifier).set(s.first);
                      const labels = ['Off', 'Normal', 'Fast'];
                      botToast(
                          'Animation speed set to ${labels[s.first]}');
                    },
                  ),
                ],
              ),
            ),

            // Show labels
            Tooltip(
              message:
                  'When ON, text labels appear below each dock icon. When OFF, icons only.',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  secondary: const Icon(Icons.label_rounded, size: 18),
                  title: const Text('Show labels',
                      style: TextStyle(fontSize: 13)),
                  value: showLabels,
                  onChanged: (v) {
                    ref.read(navShowLabelsProvider.notifier).set(v);
                    botToast(v
                        ? 'Labels visible â text shown below each dock icon'
                        : 'Labels hidden â icon only mode');
                  },
                ),
              ),
            ),

            // Haptic feedback
            Tooltip(
              message:
                  'When ON, the phone vibrates slightly when you switch dock tabs.',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  secondary: const Icon(Icons.vibration_rounded, size: 18),
                  title: const Text('Haptic feedback',
                      style: TextStyle(fontSize: 13)),
                  value: haptic,
                  onChanged: (v) {
                    ref.read(navHapticProvider.notifier).set(v);
                    botToast(v
                        ? 'Haptic feedback enabled â subtle vibration on tab change'
                        : 'Haptic feedback disabled');
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

// ââ Dock preview cards ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

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
                Icon(Icons.check_circle_rounded,
                    size: 14, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingDockPreview extends StatelessWidget {
  final ColorScheme cs;
  const _FloatingDockPreview({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                _previewIcons[i],
                size: 14,
                color: i == 0
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
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

class _MinimalDockPreview extends StatelessWidget {
  final ColorScheme cs;
  const _MinimalDockPreview({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    _previewIcons[i],
                    size: 13,
                    color: i == 0
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    width: i == 0 ? 10 : 4,
                    height: 3,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? cs.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _previewIcons = [
  Icons.apps_rounded,
  Icons.explore_outlined,
  Icons.history_outlined,
  Icons.more_horiz_outlined,
];

// ââ Slider tile âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _RoundedFullDockPreview extends StatelessWidget {
    final ColorScheme cs;
    const _RoundedFullDockPreview({required this.cs});

    @override
    Widget build(BuildContext context) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 36,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => Icon(_previewIcons[i], size: 14,
              color: i == 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.4))),
          ),
        ),
      );
    }
  }

  class _CompactDockPreview extends StatelessWidget {
    final ColorScheme cs;
    const _CompactDockPreview({required this.cs});

    @override
    Widget build(BuildContext context) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 26,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 2),
          color: cs.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => Icon(_previewIcons[i], size: 12,
              color: i == 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.35))),
          ),
        ),
      );
    }
  }

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
