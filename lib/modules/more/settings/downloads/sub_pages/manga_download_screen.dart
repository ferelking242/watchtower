import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Manga download settings sub-page
// ─────────────────────────────────────────────────────────────────────────────

class MangaDownloadScreen extends ConsumerWidget {
  const MangaDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Manga'),
      ),
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
                      'Le Manga utilise toujours le téléchargeur interne : '
                      'les pages d\'un chapitre sont récupérées en parallèle '
                      'automatiquement.',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),

            // ── Format d'archive ────────────────────────────────────────
            _SectionHeader(title: 'Format d\'archive'),
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
            _SectionHeader(title: 'Compression'),
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
                  archiveFormat,
                  ref.watch(mangaArchiveCompressionStateProvider),
                ),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
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
// Archive format cards (two per row, each with its format logo)
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveFormatChoice {
  final MangaArchiveFormat format;
  final String title;
  final String subtitle;
  const _ArchiveFormatChoice(this.format, this.title, this.subtitle);
}

String _compressionDescription(MangaArchiveFormat format, int level) {
  if (format == MangaArchiveFormat.folder) {
    return 'Choisissez un format d\'archive pour activer la compression.';
  }
  if (level <= 0) {
    return 'Aucune recompression : les pages originales sont conservées, '
        'seul le rangement ZIP est appliqué (le plus rapide).';
  }
  return 'Niveau $level/9 · les pages sont ré-encodées en JPEG plus léger '
      'puis rangées dans l\'archive : fichier plus petit, un peu de qualité '
      'en moins.';
}

const _archiveFormatChoices = <_ArchiveFormatChoice>[
  _ArchiveFormatChoice(
    MangaArchiveFormat.cbz,
    'Comic Book ZIP',
    'Le plus compatible · images ZIP',
  ),
  _ArchiveFormatChoice(
    MangaArchiveFormat.cbr,
    'Comic Book RAR',
    'Conteneur CBR · lisible partout',
  ),
  _ArchiveFormatChoice(
    MangaArchiveFormat.cb7,
    'Comic Book 7-Zip',
    'Conteneur CB7 · très compressé',
  ),
  _ArchiveFormatChoice(
    MangaArchiveFormat.zip,
    'ZIP standard',
    'Archive ZIP brute',
  ),
  _ArchiveFormatChoice(
    MangaArchiveFormat.folder,
    'Dossier d\'images',
    'Aucune archive · accès direct',
  ),
];

class _ArchiveFormatCard extends StatelessWidget {
  final _ArchiveFormatChoice choice;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  const _ArchiveFormatCard({
    required this.choice,
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
                      choice.title,
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
                      choice.subtitle,
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

  static const _labels = [
    'Rapide',
    'Léger',
    'Léger +',
    'Standard',
    'Standard +',
    'Fort',
    'Fort +',
    'Intense',
    'Intense +',
    'Maximum',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = value.clamp(0, _labels.length - 1);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.speed_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: effective.toDouble(),
                    min: 0,
                    max: (_labels.length - 1).toDouble(),
                    divisions: _labels.length - 1,
                    label: _labels[effective],
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
                    _labels[effective],
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
                Text('Moins compressé',
                    style: TextStyle(
                        fontSize: 9, color: scheme.onSurfaceVariant)),
                Text('Plus compressé',
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
