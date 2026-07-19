import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Download cards & gestures settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class DownloadCardsScreen extends ConsumerWidget {
  const DownloadCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cardButtons = ref.watch(cardButtonsStateProvider);
    final swipeLeft = ref.watch(swipeLeftActionStateProvider);
    final swipeRight = ref.watch(swipeRightActionStateProvider);

    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),title: const Text('Cartes & Gestes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Boutons des cartes ───────────────────────────────────────
            _SectionHeader(title: 'Boutons des cartes de téléchargement'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Choisissez les boutons affichés sur chaque carte de téléchargement.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            _CardButtonsGrid(
              enabled: cardButtons,
              scheme: scheme,
              onToggle: (btn) =>
                  ref.read(cardButtonsStateProvider.notifier).toggle(btn),
            ),

            // ── Aperçu ──────────────────────────────────────────────────
            _SectionHeader(title: 'Aperçu de la carte'),
            _CardPreview(enabledButtons: cardButtons, scheme: scheme),

            // ── Actions de balayage ─────────────────────────────────────
            _SectionHeader(title: 'Actions de balayage'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Action déclenchée en balayant une carte à gauche ou à droite.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            _SwipeActionTile(
              label: 'Balayer à gauche',
              icon: Icons.swipe_left_outlined,
              current: swipeLeft,
              scheme: scheme,
              onChanged: (v) =>
                  ref.read(swipeLeftActionStateProvider.notifier).set(v),
            ),
            _SwipeActionTile(
              label: 'Balayer à droite',
              icon: Icons.swipe_right_outlined,
              current: swipeRight,
              scheme: scheme,
              onChanged: (v) =>
                  ref.read(swipeRightActionStateProvider.notifier).set(v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card buttons grid
// ─────────────────────────────────────────────────────────────────────────────

class _CardButtonsGrid extends StatelessWidget {
  final Set<CardButton> enabled;
  final ColorScheme scheme;
  final void Function(CardButton) onToggle;

  const _CardButtonsGrid({
    required this.enabled,
    required this.scheme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: CardButton.values.map((btn) {
        final isEnabled = enabled.contains(btn);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isEnabled
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outline.withValues(alpha: 0.2),
              width: isEnabled ? 1.5 : 1,
            ),
          ),
          child: CheckboxListTile(
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEnabled
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                btn.icon,
                size: 18,
                color:
                    isEnabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              btn.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isEnabled ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            value: isEnabled,
            onChanged: (_) => onToggle(btn),
            activeColor: scheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card preview (visual mockup of what buttons will look like)
// ─────────────────────────────────────────────────────────────────────────────

class _CardPreview extends StatelessWidget {
  final Set<CardButton> enabledButtons;
  final ColorScheme scheme;

  const _CardPreview({
    required this.enabledButtons,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = CardButton.values
        .where((b) => enabledButtons.contains(b))
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.movie_outlined,
                    color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 8,
                      width: 80,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                      color: scheme.primary,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: buttons.map((btn) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(btn.icon,
                            size: 14, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          btn.label.split(' / ').first,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Aucun bouton affiché — balayez pour agir.',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe action tile
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final SwipeAction current;
  final ColorScheme scheme;
  final void Function(SwipeAction) onChanged;

  const _SwipeActionTile({
    required this.label,
    required this.icon,
    required this.current,
    required this.scheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: scheme.secondary, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          current.label,
          style: TextStyle(fontSize: 12, color: scheme.primary),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => _showPicker(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SwipeAction.values.map((action) {
            return RadioListTile<SwipeAction>(
              title: Text(action.label),
              value: action,
              groupValue: current,
              onChanged: (v) {
                if (v != null) {
                  onChanged(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
