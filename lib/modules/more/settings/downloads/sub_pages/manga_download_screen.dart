import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Manga download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class MangaDownloadScreen extends ConsumerWidget {
  const MangaDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final archiveFormat = ref.watch(mangaArchiveFormatStateProvider);
    final mangaOnlyOnWifi = ref.watch(mangaOnlyOnWifiStateProvider);
    final autoDownloadNewChapters =
        ref.watch(autoDownloadNewChaptersStateProvider);
    final deleteAfterMarkedRead = ref.watch(deleteAfterMarkedReadStateProvider);
    final allowDeletingBookmarked =
        ref.watch(allowDeletingBookmarkedChaptersStateProvider);
    final anticipatoryDownloadRead =
        ref.watch(anticipatoryDownloadReadStateProvider);

    return SettingsSubpageScaffold(
      title: l10n.manga,
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
                  Icon(Broken.book,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.downloads_manga_engine_note,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),

            // ── Format d'archive ────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_archive_section),
            LayoutBuilder(
              builder: (context, constraints) {
                // Two cards per row, exactly: share the available width minus
                // the 8px inner gap. Using MediaQuery here overflowed by the
                // gap and wrapped every card onto its own row.
                const spacing = 8.0;
                final cardWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _archiveFormatChoices.map((choice) {
                    return _ArchiveFormatCard(
                      width: cardWidth,
                      choice: choice,
                      title: _archiveChoiceTitle(l10n, choice.titleKey),
                      subtitle: _archiveChoiceSubtitle(l10n, choice.subtitleKey),
                      selected: choice.format == archiveFormat,
                      onTap: () => ref
                          .read(mangaArchiveFormatStateProvider.notifier)
                          .set(choice.format),
                    );
                  }).toList(),
                );
              },
            ),

            // ── Niveau de compression ───────────────────────────────────
            _SectionHeader(title: l10n.downloads_compression_section),
            _CompressionSlider(
              enabled: archiveFormat != MangaArchiveFormat.folder,
              value: ref.watch(mangaArchiveCompressionStateProvider),
              onChanged: (v) => ref
                  .read(mangaArchiveCompressionStateProvider.notifier)
                  .set(v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                _compressionDescription(
                  l10n,
                  archiveFormat,
                  ref.watch(mangaArchiveCompressionStateProvider),
                ),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
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
              value: mangaOnlyOnWifi,
              onChanged: (v) =>
                  ref.read(mangaOnlyOnWifiStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.magic_star),
              title: Text(l10n.downloads_manga_new_chapters),
              subtitle: Text(
                l10n.downloads_manga_new_chapters_subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              value: autoDownloadNewChapters,
              onChanged: (v) => ref
                  .read(autoDownloadNewChaptersStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.forward),
              title: Text(l10n.downloads_anticipatory_read),
              subtitle: Text(
                l10n.downloads_anticipatory_read_subtitle,
                style: const TextStyle(fontSize: 10),
              ),
              value: anticipatoryDownloadRead,
              onChanged: (v) => ref
                  .read(anticipatoryDownloadReadStateProvider.notifier)
                  .set(v),
            ),

            // ── Suppression ─────────────────────────────────────────────
            _SectionHeader(title: l10n.downloads_section_deletion),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.trash),
              title: Text(l10n.downloads_delete_after_read),
              subtitle: Text(
                l10n.downloads_delete_after_read_subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              value: deleteAfterMarkedRead,
              onChanged: (v) =>
                  ref.read(deleteAfterMarkedReadStateProvider.notifier).set(v),
            ),
            SwitchListTile(
              dense: true,
              secondary: const Icon(Broken.bookmark),
              title: Text(l10n.downloads_delete_marked),
              subtitle: Text(
                l10n.downloads_delete_marked_subtitle,
                style: const TextStyle(fontSize: 11),
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
// Archive format cards (two per row, each with its format logo)
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveFormatChoice {
  final MangaArchiveFormat format;
  final String titleKey;
  final String subtitleKey;
  const _ArchiveFormatChoice(this.format, this.titleKey, this.subtitleKey);
}

String _archiveChoiceTitle(AppLocalizations l10n, String key) {
  return switch (key) {
    'cbz' => l10n.downloads_archive_cbz_title,
    'cbr' => l10n.downloads_archive_cbr_title,
    'cb7' => l10n.downloads_archive_cb7_title,
    'zip' => l10n.downloads_archive_zip_title,
    _ => l10n.downloads_archive_folder_title,
  };
}

String _archiveChoiceSubtitle(AppLocalizations l10n, String key) {
  return switch (key) {
    'cbz' => l10n.downloads_archive_cbz_subtitle,
    'cbr' => l10n.downloads_archive_cbr_subtitle,
    'cb7' => l10n.downloads_archive_cb7_subtitle,
    'zip' => l10n.downloads_archive_zip_subtitle,
    _ => l10n.downloads_archive_folder_subtitle,
  };
}

String _compressionDescription(
  AppLocalizations l10n,
  MangaArchiveFormat format,
  int level,
) {
  if (format == MangaArchiveFormat.folder) {
    return l10n.downloads_compression_disabled;
  }
  if (level <= 0) {
    return l10n.downloads_compression_none;
  }
  return l10n.downloads_compression_level(level);
}

const _archiveFormatChoices = <_ArchiveFormatChoice>[
  _ArchiveFormatChoice(MangaArchiveFormat.cbz, 'cbz', 'cbz'),
  _ArchiveFormatChoice(MangaArchiveFormat.cbr, 'cbr', 'cbr'),
  _ArchiveFormatChoice(MangaArchiveFormat.cb7, 'cb7', 'cb7'),
  _ArchiveFormatChoice(MangaArchiveFormat.zip, 'zip', 'zip'),
  _ArchiveFormatChoice(MangaArchiveFormat.folder, 'folder', 'folder'),
];

class _ArchiveFormatCard extends StatelessWidget {
  final _ArchiveFormatChoice choice;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  const _ArchiveFormatCard({
    required this.choice,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.18)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: SvgPicture.asset(
                  choice.format.logoAsset,
                  colorFilter: ColorFilter.mode(
                    selected ? scheme.primary : scheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.format.shortLabel,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compression level slider
// ─────────────────────────────────────────────────────────────────────────────

class _CompressionSlider extends StatelessWidget {
  final bool enabled;
  final int value;
  final ValueChanged<int> onChanged;

  const _CompressionSlider({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  static List<String> _labels(AppLocalizations l10n) => [
    l10n.downloads_compression_fast,
    l10n.downloads_compression_light,
    l10n.downloads_compression_light_plus,
    l10n.downloads_compression_standard,
    l10n.downloads_compression_standard_plus,
    l10n.downloads_compression_strong,
    l10n.downloads_compression_strong_plus,
    l10n.downloads_compression_intense,
    l10n.downloads_compression_intense_plus,
    l10n.downloads_compression_maximum,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = _labels(context.l10n);
    final effective = value.clamp(0, labels.length - 1);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Broken.timer,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: effective.toDouble(),
                    min: 0,
                    max: (labels.length - 1).toDouble(),
                    divisions: labels.length - 1,
                    label: labels[effective],
                    onChanged:
                        enabled ? (v) => onChanged(v.round()) : null,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[effective],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.downloads_less_compressed,
                    style: TextStyle(
                        fontSize: 9, color: scheme.onSurfaceVariant)),
                Text(context.l10n.downloads_more_compressed,
                    style: TextStyle(
                        fontSize: 9, color: scheme.onSurfaceVariant)),
              ],
            ),
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
