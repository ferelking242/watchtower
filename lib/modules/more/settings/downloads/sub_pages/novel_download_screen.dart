import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Novel download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class NovelDownloadScreen extends ConsumerWidget {
  const NovelDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final novelConnections = ref.watch(novelConnectionsStateProvider);
    final novelSimultaneous = ref.watch(novelSimultaneousStateProvider);
    final novelOnlyOnWifi = ref.watch(novelOnlyOnWifiStateProvider);

    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),title: const Text('Téléchargements — Roman')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_outlined,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le Roman utilise le téléchargeur interne via l\'extension source. '
                      'Les chapitres sont sauvegardés en HTML et regroupés par titre.',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),

            // ── Connexions ──────────────────────────────────────────────
            _SectionHeader(title: 'Connexions'),
            _ConnectionsTile(
              label: 'Connexions simultanées',
              subtitle: 'Connexions parallèles par chapitre',
              value: novelConnections,
              icon: Icons.download_outlined,
              onChanged: (v) =>
                  ref.read(novelConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: 'Chapitres simultanés (file)',
              subtitle: 'Nombre de chapitres téléchargés en même temps',
              value: novelSimultaneous,
              icon: Icons.queue_outlined,
              onChanged: (v) =>
                  ref.read(novelSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            // ── Comportement ────────────────────────────────────────────
            _SectionHeader(title: 'Comportement'),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.wifi_outlined),
              title: const Text('Wi-Fi uniquement'),
              subtitle: const Text(
                'Télécharger uniquement via Wi-Fi',
                style: TextStyle(fontSize: 11),
              ),
              value: novelOnlyOnWifi,
              onChanged: (v) =>
                  ref.read(novelOnlyOnWifiStateProvider.notifier).set(v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections tile
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionsTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final int value;
  final IconData icon;
  final void Function(int) onChanged;
  final ColorScheme scheme;

  const _ConnectionsTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
      trailing: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scheme.primary),
          ),
        ),
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    int currentValue = value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: 120,
            child: _InlineNumberPicker(
              value: currentValue,
              min: 1,
              max: 16,
              onChanged: (v) => setState(() => currentValue = v),
              scheme: scheme,
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler',
                    style: TextStyle(color: context.primaryColor)),
              ),
              TextButton(
                onPressed: () {
                  onChanged(currentValue);
                  Navigator.pop(context);
                },
                child: Text('OK',
                    style: TextStyle(color: context.primaryColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineNumberPicker extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;
  final ColorScheme scheme;

  const _InlineNumberPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
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
