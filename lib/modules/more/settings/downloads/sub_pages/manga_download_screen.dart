import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/sub_pages/manga_archive_format_screen.dart';
import 'package:watchtower/modules/more/settings/settings_subpage_route.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

class MangaDownloadScreen extends ConsumerWidget {
  const MangaDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final archiveFormat = ref.watch(mangaArchiveFormatStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Manga'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          _SectionHeader(title: 'Stockage'),
          ListTile(
            dense: true,
            leading: Icon(Broken.archive, color: scheme.primary),
            title: const Text('Format de stockage'),
            subtitle: Text(archiveFormat.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  archiveFormat.label,
                  style: TextStyle(color: scheme.primary),
                ),
                const SizedBox(width: 8),
                Icon(Broken.arrow_right_3, color: scheme.onSurfaceVariant),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              settingsSubpageRoute(const MangaArchiveFormatScreen()),
            ),
          ),
          _SectionHeader(title: 'Téléchargement'),
          _NumberSettingTile(
            icon: Broken.hierarchy_square_2,
            title: 'Images simultanées par chapitre',
            subtitle: 'Pages téléchargées en parallèle',
            value: ref.watch(mangaConnectionsStateProvider),
            onChanged: (value) =>
                ref.read(mangaConnectionsStateProvider.notifier).set(value),
          ),
          _NumberSettingTile(
            icon: Broken.cpu,
            title: 'Chapitres simultanés',
            subtitle: 'Chapitres téléchargés en parallèle',
            value: ref.watch(mangaSimultaneousStateProvider),
            onChanged: (value) =>
                ref.read(mangaSimultaneousStateProvider.notifier).set(value),
          ),
          _SwitchSettingTile(
            icon: Broken.wifi,
            title: 'Télécharger uniquement en Wi-Fi',
            value: ref.watch(mangaOnlyOnWifiStateProvider),
            onChanged: (value) =>
                ref.read(mangaOnlyOnWifiStateProvider.notifier).set(value),
          ),
          _SwitchSettingTile(
            icon: Broken.document_download,
            title: 'Télécharger les nouveaux chapitres',
            value: ref.watch(autoDownloadNewChaptersStateProvider),
            onChanged: (value) => ref
                .read(autoDownloadNewChaptersStateProvider.notifier)
                .set(value),
          ),
          _SwitchSettingTile(
            icon: Broken.timer,
            title: 'Téléchargement anticipé',
            subtitle: 'Précharger les chapitres à lire ensuite',
            value: ref.watch(anticipatoryDownloadReadStateProvider),
            onChanged: (value) => ref
                .read(anticipatoryDownloadReadStateProvider.notifier)
                .set(value),
          ),
          _SectionHeader(title: 'Après lecture'),
          _SwitchSettingTile(
            icon: Broken.trash,
            title: 'Supprimer après lecture',
            value: ref.watch(deleteAfterMarkedReadStateProvider),
            onChanged: (value) =>
                ref.read(deleteAfterMarkedReadStateProvider.notifier).set(value),
          ),
          _SwitchSettingTile(
            icon: Broken.bookmark,
            title: 'Supprimer aussi les chapitres avec marque-page',
            subtitle: 'Applicable uniquement si la suppression automatique est activée',
            value: ref.watch(allowDeletingBookmarkedChaptersStateProvider),
            onChanged: (value) => ref
                .read(allowDeletingBookmarkedChaptersStateProvider.notifier)
                .set(value),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _NumberSettingTile extends StatelessWidget {
  const _NumberSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: () => _showPicker(context),
        child: Text('$value'),
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    var selected = value < 1 ? 1 : value > 16 ? 16 : value;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          height: 170,
          child: StatefulBuilder(
            builder: (context, setDialogState) => NumberPicker(
              value: selected,
              minValue: 1,
              maxValue: 16,
              onChanged: (value) => setDialogState(() => selected = value),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              onChanged(selected);
              Navigator.pop(dialogContext);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

extension on MangaArchiveFormat {
  String get description => switch (this) {
    MangaArchiveFormat.folder => 'Pages vérifiées dans un dossier.',
    MangaArchiveFormat.cbz =>
      'Archive CBZ créée après validation de toutes les pages.',
  };
}
