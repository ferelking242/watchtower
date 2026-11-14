import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Novel download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class NovelDownloadScreen extends ConsumerWidget {
  const NovelDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final novelConnections = ref.watch(novelConnectionsStateProvider);
    final novelSimultaneous = ref.watch(novelSimultaneousStateProvider);
    final novelOnlyOnWifi = ref.watch(novelOnlyOnWifiStateProvider);

    return SettingsSubpageScaffold(
      title: l10n.downloads_novel_title,
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
                  Icon(Broken.book,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.downloads_novel_note,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),

            // ── Connexions ──────────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_connections_section),
            _ConnectionsTile(
              label: l10n.downloads_connections_simultaneous,
              subtitle: l10n.downloads_connections_per_chapter,
              value: novelConnections,
              icon: Broken.document_download,
              onChanged: (v) =>
                  ref.read(novelConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: l10n.downloads_chapters_queue,
              subtitle: l10n.downloads_chapters_queue_subtitle,
              value: novelSimultaneous,
              icon: Broken.note_2,
              onChanged: (v) =>
                  ref.read(novelSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            // ── Comportement ────────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_behavior_section),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.wifi),
              title: Text(l10n.downloads_wifi_only),
              subtitle: Text(
                l10n.downloads_wifi_only_subtitle,
                style: const TextStyle(fontSize: 11),
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
                child: Text(context.l10n.cancel,
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
          icon: const Icon(Broken.minus_cirlce),
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
          icon: const Icon(Broken.add_circle),
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
