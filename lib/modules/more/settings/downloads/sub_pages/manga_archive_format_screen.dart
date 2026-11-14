import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

class MangaArchiveFormatScreen extends ConsumerWidget {
  const MangaArchiveFormatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedFormat = ref.watch(mangaArchiveFormatStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return SettingsSubpageScaffold(
      title: l10n.downloads_storage_format,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: MangaArchiveFormat.values.map((format) {
          final selected = format == selectedFormat;
          return ListTile(
            leading: Icon(
              format == MangaArchiveFormat.cbz ? Broken.archive : Broken.folder,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: Text(format.label(l10n)),
            subtitle: Text(_description(l10n, format)),
            trailing: RadioGroup<MangaArchiveFormat>(
              groupValue: selectedFormat,
              onChanged: (_) => _select(context, ref, format),
              child: Radio<MangaArchiveFormat>(value: format),
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

  String _description(AppLocalizations l10n, MangaArchiveFormat format) =>
      switch (format) {
        MangaArchiveFormat.folder => l10n.downloads_archive_folder_desc,
        MangaArchiveFormat.cbz => l10n.downloads_archive_cbz_desc,
        MangaArchiveFormat.zip => l10n.downloads_archive_zip_desc,
        MangaArchiveFormat.cbr => l10n.downloads_archive_unsupported,
        MangaArchiveFormat.cb7 => l10n.downloads_archive_unsupported,
      };
}
