import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

class MangaArchiveFormatScreen extends ConsumerWidget {
  const MangaArchiveFormatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFormat = ref.watch(mangaArchiveFormatStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Format de stockage'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: MangaArchiveFormat.values.map((format) {
          final selected = format == selectedFormat;
          return ListTile(
            leading: Icon(
              format == MangaArchiveFormat.cbz ? Broken.archive : Broken.folder,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: Text(format.label),
            subtitle: Text(_description(format)),
            trailing: Radio<MangaArchiveFormat>(
              value: format,
              groupValue: selectedFormat,
              onChanged: (_) => _select(context, ref, format),
            ),
            onTap: () => _select(context, ref, format),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    MangaArchiveFormat format,
  ) async {
    await ref.read(mangaArchiveFormatStateProvider.notifier).set(format);
    if (context.mounted) Navigator.maybePop(context);
  }

  String _description(MangaArchiveFormat format) => switch (format) {
    MangaArchiveFormat.folder => 'Pages vérifiées, conservées dans un dossier.',
    MangaArchiveFormat.cbz => 'Archive créée après validation de toutes les pages.',
  };
}
