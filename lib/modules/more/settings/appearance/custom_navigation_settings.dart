import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class CustomNavigationSettings extends ConsumerStatefulWidget {
  const CustomNavigationSettings({super.key});

  @override
  ConsumerState<CustomNavigationSettings> createState() =>
      _CustomNavigationSettingsState();
}

class _CustomNavigationSettingsState
    extends ConsumerState<CustomNavigationSettings> {
  double _iconSize = 24;
  double _spacing = 8;
  int _animationSpeed = 1;
  bool _hapticEnabled = true;
  bool _labelsVisible = true;

  static const List<String> _animationSpeeds = ['Off', 'Normal', 'Fast'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navigationOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final mergeLibraryNavMobile = ref.watch(mergeLibraryNavMobileStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reorder_navigation)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Merge library toggle ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: SwitchListTile(
                value: mergeLibraryNavMobile,
                title: Text(context.l10n.merge_library_nav_mobile),
                onChanged: (value) {
                  ref
                      .read(mergeLibraryNavMobileStateProvider.notifier)
                      .set(value);
                },
              ),
            ),

            // ── Reorderable navigation items ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(
                height: navigationOrder.length * 60.0,
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
                          child: SwitchListTile(
                            key: Key(navigation),
                            dense: true,
                            value: !hideItems.contains(navigation),
                            onChanged:
                                [
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
                                  },
                            title: Text(navigationItems[navigation]!),
                          ),
                        ),
                      ],
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      final draggedItem = navigationOrder[oldIndex];
                      for (var i = oldIndex; i < newIndex - 1; i++) {
                        navigationOrder[i] = navigationOrder[i + 1];
                      }
                      navigationOrder[newIndex - 1] = draggedItem;
                    } else {
                      final draggedItem = navigationOrder[oldIndex];
                      for (var i = oldIndex; i > newIndex; i--) {
                        navigationOrder[i] = navigationOrder[i - 1];
                      }
                      navigationOrder[newIndex] = draggedItem;
                    }
                    ref
                        .read(navigationOrderStateProvider.notifier)
                        .set(navigationOrder);
                  },
                ),
              ),
            ),

            const Divider(height: 24),

            // ── Advanced customization section ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Advanced Customization',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Icon size
                      _SliderRow(
                        icon: Icons.photo_size_select_small_rounded,
                        label: 'Icon size',
                        value: _iconSize,
                        min: 18,
                        max: 32,
                        displayValue:
                            '${_iconSize.toStringAsFixed(0)}px',
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _iconSize = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Spacing
                      _SliderRow(
                        icon: Icons.space_bar_rounded,
                        label: 'Item spacing',
                        value: _spacing,
                        min: 0,
                        max: 24,
                        displayValue:
                            '${_spacing.toStringAsFixed(0)}px',
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _spacing = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Animation speed
                      Row(
                        children: [
                          const Icon(Icons.animation_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Animation speed',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: List.generate(
                              _animationSpeeds.length,
                              (i) => ButtonSegment(
                                value: i,
                                label: Text(
                                  _animationSpeeds[i],
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            selected: {_animationSpeed},
                            onSelectionChanged: (s) {
                              setState(() => _animationSpeed = s.first);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Haptic feedback toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        secondary: const Icon(
                          Icons.vibration_rounded,
                          size: 18,
                        ),
                        title: const Text(
                          'Haptic feedback',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _hapticEnabled,
                        onChanged: (v) => setState(() => _hapticEnabled = v),
                      ),

                      // Labels visibility toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        secondary: const Icon(Icons.label_rounded, size: 18),
                        title: const Text(
                          'Show labels',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _labelsVisible,
                        onChanged: (v) => setState(() => _labelsVisible = v),
                      ),
                    ],
                  ),
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

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
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
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider.adaptive(
            min: min,
            max: max,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
