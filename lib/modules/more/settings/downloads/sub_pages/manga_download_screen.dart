import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Manga download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class MangaDownloadScreen extends ConsumerWidget {
  const MangaDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mangaConnections = ref.watch(mangaConnectionsStateProvider);
    final mangaSimultaneous = ref.watch(mangaSimultaneousStateProvider);
    final archiveFormat = ref.watch(mangaArchiveFormatStateProvider);
    final mangaOnlyOnWifi = ref.watch(mangaOnlyOnWifiStateProvider);
    final autoDownloadNewChapters =
        ref.watch(autoDownloadNewChaptersStateProvider);
    final deleteAfterMarkedRead = ref.watch(deleteAfterMarkedReadStateProvider);
    final allowDeletingBookmarked =
        ref.watch(allowDeletingBookmarkedChaptersStateProvider);
    final anticipatoryDownloadRead =
        ref.watch(anticipatoryDownloadReadStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements — Manga')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Moteur ──────────────────────────────────────────────────
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
                  Icon(Icons.menu_book_outlined,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le Manga utilise toujours le téléchargeur interne. '
                      'Les pages sont téléchargées en parallèle selon les connexions configurées.',
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
              subtitle: 'Images téléchargées en parallèle par chapitre',
              value: mangaConnections,
              icon: Icons.image_outlined,
              onChanged: (v) =>
                  ref.read(mangaConnectionsStateProvider.notifier).set(v),
              scheme: scheme,
            ),
            _ConnectionsTile(
              label: 'Chapitres simultanés (file)',
              subtitle: 'Nombre de chapitres téléchargés en même temps',
              value: mangaSimultaneous,
              icon: Icons.queue_outlined,
              onChanged: (v) =>
                  ref.read(mangaSimultaneousStateProvider.notifier).set(v),
              scheme: scheme,
            ),

            // ── Format d'archive ────────────────────────────────────────
            _SectionHeader(title: 'Format d\'archive'),
            ListTile(
              leading: Icon(Icons.folder_zip_outlined, color: scheme.primary),
              title: const Text('Archiver les chapitres en…'),
              subtitle: Text(
                archiveFormat.label,
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              trailing: _ArchiveFormatSelector(
                value: archiveFormat,
                onChanged: (f) =>
                    ref.read(mangaArchiveFormatStateProvider.notifier).set(f),
                scheme: scheme,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: MangaArchiveFormat.values.map((f) {
                  final isSelected = f == archiveFormat;
                  return GestureDetector(
                    onTap: () =>
                        ref.read(mangaArchiveFormatStateProvider.notifier).set(f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
              value: mangaOnlyOnWifi,
              onChanged: (v) =>
                  ref.read(mangaOnlyOnWifiStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.new_releases_outlined),
              title: const Text('Télécharger les nouveaux chapitres'),
              subtitle: const Text(
                'Télécharge automatiquement les nouveaux chapitres disponibles',
                style: TextStyle(fontSize: 11),
              ),
              value: autoDownloadNewChapters,
              onChanged: (v) => ref
                  .read(autoDownloadNewChaptersStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.fast_forward_outlined),
              title: const Text('Téléchargement anticipé (lecture)'),
              subtitle: const Text(
                'Pré-télécharge si le chapitre actuel et le suivant sont déjà présents',
                style: TextStyle(fontSize: 10),
              ),
              value: anticipatoryDownloadRead,
              onChanged: (v) => ref
                  .read(anticipatoryDownloadReadStateProvider.notifier)
                  .set(v),
            ),

            // ── Suppression ─────────────────────────────────────────────
            _SectionHeader(title: 'Suppression'),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.auto_delete_outlined),
              title: const Text('Supprimer après lecture'),
              subtitle: const Text(
                'Supprime le chapitre dès qu\'il est marqué comme lu',
                style: TextStyle(fontSize: 11),
              ),
              value: deleteAfterMarkedRead,
              onChanged: (v) =>
                  ref.read(deleteAfterMarkedReadStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.bookmark_outlined),
              title: const Text('Supprimer même les chapitres marqués'),
              subtitle: const Text(
                'La suppression automatique s\'applique aussi aux chapitres avec marque-page',
                style: TextStyle(fontSize: 11),
              ),
              value: allowDeletingBookmarked,
              onChanged: (v) => ref
                  .read(allowDeletingBookmarkedChaptersStateProvider.notifier)
                  .set(v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Archive format selector chip (compact trailing widget)
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveFormatSelector extends StatelessWidget {
  final MangaArchiveFormat value;
  final void Function(MangaArchiveFormat) onChanged;
  final ColorScheme scheme;

  const _ArchiveFormatSelector({
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: scheme.primary, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Format d\'archive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MangaArchiveFormat.values.map((f) {
            return RadioListTile<MangaArchiveFormat>(
              title: Text(f.label),
              value: f,
              groupValue: value,
              onChanged: (v) {
                if (v != null) {
                  onChanged(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
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
                    style: TextStyle(
                        color: context.primaryColor)),
              ),
              TextButton(
                onPressed: () {
                  onChanged(currentValue);
                  Navigator.pop(context);
                },
                child: Text('OK',
                    style: TextStyle(
                        color: context.primaryColor)),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              width: 60,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
