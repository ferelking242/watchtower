import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/providers/algorithm_weights_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  int _genre = 0;
  int _setting = 0;
  int _synopsis = 0;
  int _theme = 0;

  static const _algorithmOptions = [
    _AlgoOption(
      id: 0,
      icon: Icons.psychology_rounded,
      title: 'Content-Based Filtering',
      subtitle:
          'Compares genre, themes and synopsis directly. Fast and offline.',
      color: Colors.blue,
    ),
    _AlgoOption(
      id: 1,
      icon: Icons.people_rounded,
      title: 'Collaborative Filtering',
      subtitle:
          'Recommends based on what similar users enjoyed. Requires network.',
      color: Colors.purple,
    ),
    _AlgoOption(
      id: 2,
      icon: Icons.auto_awesome_rounded,
      title: 'Hybrid',
      subtitle: 'Combines content-based and collaborative for best accuracy.',
      color: Colors.orange,
    ),
  ];

  int _selectedAlgo = 0;

  @override
  void initState() {
    super.initState();
    final w = ref.read(algorithmWeightsStateProvider);
    _genre = w.genre!;
    _setting = w.setting!;
    _synopsis = w.synopsis!;
    _theme = w.theme!;
  }

  void _reset() {
    final defaults = AlgorithmWeights();
    setState(() {
      _genre = defaults.genre!;
      _setting = defaults.setting!;
      _synopsis = defaults.synopsis!;
      _theme = defaults.theme!;
    });
    ref.read(algorithmWeightsStateProvider.notifier).set(defaults);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Algorithm ─────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.memory_rounded,
              label: 'Algorithm',
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            ...List.generate(_algorithmOptions.length, (i) {
              final opt = _algorithmOptions[i];
              final selected = _selectedAlgo == opt.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAlgo = opt.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? opt.color
                            : colorScheme.outline.withOpacity(0.25),
                        width: selected ? 1.5 : 1,
                      ),
                      color: selected
                          ? opt.color.withOpacity(0.08)
                          : colorScheme.surfaceContainerHighest.withOpacity(
                              0.4,
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: opt.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt.icon, color: opt.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? opt.color
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: opt.color,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // ── Similarity weights ─────────────────────────────────────────
            _SectionHeader(
              icon: Icons.tune_rounded,
              label: 'Similarity weights',
              color: colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Adjust how much each factor influences recommendations.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _WeightTile(
              icon: Icons.category_rounded,
              label: context.l10n.recommendations_weights_genre,
              color: Colors.blue,
              value: _genre,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _genre = v);
              },
              onChangeEnd: (_) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(genre: _genre),
            ),
            _WeightTile(
              icon: Icons.settings_rounded,
              label: context.l10n.recommendations_weights_setting,
              color: Colors.purple,
              value: _setting,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _setting = v);
              },
              onChangeEnd: (_) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(setting: _setting),
            ),
            _WeightTile(
              icon: Icons.article_rounded,
              label: context.l10n.recommendations_weights_synopsis,
              color: Colors.teal,
              value: _synopsis,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _synopsis = v);
              },
              onChangeEnd: (_) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(synopsis: _synopsis),
            ),
            _WeightTile(
              icon: Icons.palette_rounded,
              label: context.l10n.recommendations_weights_theme,
              color: Colors.orange,
              value: _theme,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _theme = v);
              },
              onChangeEnd: (_) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(theme: _theme),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WeightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _WeightTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '$value%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: color,
              inactiveColor: color.withOpacity(0.2),
              onChanged: (v) => onChanged(v.round()),
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlgoOption {
  final int id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _AlgoOption({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
