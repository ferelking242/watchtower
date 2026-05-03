import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/sub_pages/watch_download_screen.dart';
import 'package:watchtower/modules/more/settings/downloads/sub_pages/manga_download_screen.dart';
import 'package:watchtower/modules/more/settings/downloads/sub_pages/novel_download_screen.dart';
import 'package:watchtower/modules/more/settings/downloads/sub_pages/download_cards_screen.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hub screen
// ─────────────────────────────────────────────────────────────────────────────

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    DownloadSettingsService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final scheme = Theme.of(context).colorScheme;
    final localFolders = ref.watch(localFoldersStateProvider);
    final speedLimit = ref.watch(speedLimitKBsStateProvider);
    final concurrentDownloads = ref.watch(concurrentDownloadsStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Par média ─────────────────────────────────────────────────
            _SectionHeader(title: 'Par média'),
            _NavTile(
              icon: Icons.play_circle_outline,
              label: 'Watch',
              subtitle: 'Moteur, connexions, épisodes, fillers',
              iconColor: scheme.primary,
              onTap: () => _push(context, const WatchDownloadScreen()),
            ),
            _NavTile(
              icon: Icons.menu_book_outlined,
              label: 'Manga',
              subtitle: 'Connexions, format d\'archive, chapitres',
              iconColor: scheme.secondary,
              onTap: () => _push(context, const MangaDownloadScreen()),
            ),
            _NavTile(
              icon: Icons.auto_stories_outlined,
              label: 'Roman',
              subtitle: 'Connexions, téléchargements Wi-Fi',
              iconColor: scheme.tertiary,
              onTap: () => _push(context, const NovelDownloadScreen()),
            ),

            // ── Général ───────────────────────────────────────────────────
            _SectionHeader(title: 'Général'),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Téléchargements simultanés (max)'),
              subtitle: Text(
                '$concurrentDownloads téléchargement(s) en parallèle',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: _BadgeChip(label: '$concurrentDownloads', scheme: scheme),
              onTap: () => _showNumberPickerDialog(
                context,
                title: 'Téléchargements simultanés',
                current: concurrentDownloads,
                min: 1,
                max: 10,
                onSave: (v) =>
                    ref.read(concurrentDownloadsStateProvider.notifier).set(v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.speed_outlined),
              title: const Text('Limite de vitesse'),
              subtitle: Text(
                speedLimit == 0
                    ? 'Désactivée'
                    : speedLimit < 1024
                        ? '$speedLimit KB/s'
                        : '${(speedLimit / 1024).toStringAsFixed(0)} MB/s',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: _BadgeChip(
                label: speedLimit == 0 ? '∞' : '${speedLimit}K',
                scheme: scheme,
              ),
              onTap: () => _showSpeedLimitDialog(context, speedLimit),
            ),

            // ── Cartes & Gestes ───────────────────────────────────────────
            _SectionHeader(title: 'Cartes & Gestes'),
            _NavTile(
              icon: Icons.credit_card_outlined,
              label: 'Cartes de téléchargement',
              subtitle: 'Boutons affichés et actions de balayage',
              iconColor: scheme.primary,
              onTap: () => _push(context, const DownloadCardsScreen()),
            ),

            // ── Suppression ───────────────────────────────────────────────
            _SectionHeader(title: 'Suppression'),
            SwitchListTile(
              secondary: const Icon(Icons.auto_delete_outlined),
              title: const Text('Suppression automatique après lecture'),
              subtitle: const Text(
                'Supprime le fichier une fois le contenu lu/visionné',
                style: TextStyle(fontSize: 11),
              ),
              value: ref.watch(deleteDownloadAfterReadingStateProvider),
              onChanged: (v) => ref
                  .read(deleteDownloadAfterReadingStateProvider.notifier)
                  .set(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bookmark_outlined),
              title: const Text('Autoriser la suppression des chapitres marqués'),
              subtitle: const Text(
                'Permet de supprimer les chapitres avec un marque-page',
                style: TextStyle(fontSize: 11),
              ),
              value: ref.watch(allowDeletingBookmarkedChaptersStateProvider),
              onChanged: (v) => ref
                  .read(allowDeletingBookmarkedChaptersStateProvider.notifier)
                  .set(v),
            ),

            // ── Navigation rapide (dock) ───────────────────────────────────
            _SectionHeader(title: 'Navigation rapide (dock)'),
            Builder(builder: (context) {
              final hideItems = ref.watch(hideItemsStateProvider);
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.history_rounded),
                    title: const Text('Historique dans le dock'),
                    subtitle: const Text(
                      'Affiche l\'onglet Historique dans la barre de navigation',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: !hideItems.contains('/history'),
                    onChanged: (v) {
                      final temp = hideItems.toList();
                      if (!v) {
                        if (!temp.contains('/history')) temp.add('/history');
                      } else {
                        temp.remove('/history');
                      }
                      ref.read(hideItemsStateProvider.notifier).set(temp);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.new_releases_outlined),
                    title: const Text('Mises à jour dans le dock'),
                    subtitle: const Text(
                      'Affiche l\'onglet Mises à jour dans la barre de navigation',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: !hideItems.contains('/updates'),
                    onChanged: (v) {
                      final temp = hideItems.toList();
                      if (!v) {
                        if (!temp.contains('/updates')) temp.add('/updates');
                      } else {
                        temp.remove('/updates');
                      }
                      ref.read(hideItemsStateProvider.notifier).set(temp);
                    },
                  ),
                ],
              );
            }),

            // ── Dossiers locaux ───────────────────────────────────────────
            _SectionHeader(title: l10n.local_folder),
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: Text(l10n.rescan_local_folder),
              onTap: () async => ref.read(scanLocalLibraryProvider.future),
            ),
            ListTile(
              leading: const Icon(Icons.add_outlined),
              title: Text(l10n.add_local_folder),
              onTap: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) {
                  final temp = localFolders.toList();
                  temp.add(result);
                  ref.read(localFoldersStateProvider.notifier).set(temp);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _showHelpDialog(context),
                      label: const Icon(Icons.question_mark),
                      icon: const Text('Folder Structure'),
                    ),
                  ),
                  FutureBuilder(
                    future: getLocalLibrary(),
                    builder: (context, snapshot) =>
                        snapshot.data?.path != null
                            ? _buildLocalFolder(
                                l10n,
                                localFolders,
                                snapshot.data!.path,
                                isDefault: true,
                              )
                            : Container(),
                  ),
                  ...localFolders.map(
                    (e) => _buildLocalFolder(l10n, localFolders, e),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      Platform.isIOS || Platform.isMacOS
          ? _cupertinoRoute(page)
          : MaterialPageRoute(builder: (_) => page),
    );
  }

  Route _cupertinoRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (c, a1, a2) => page,
      transitionsBuilder: (c, a1, a2, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: a1.drive(tween), child: child);
      },
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showNumberPickerDialog(
    BuildContext context, {
    required String title,
    required int current,
    required int min,
    required int max,
    required void Function(int) onSave,
  }) {
    int currentValue = current;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NumberPicker(
                  value: currentValue,
                  minValue: min,
                  maxValue: max,
                  step: 1,
                  haptics: true,
                  textMapper: (n) => n,
                  onChanged: (v) => setState(() => currentValue = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.l10n.cancel,
                  style: TextStyle(color: context.primaryColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  onSave(currentValue);
                  Navigator.pop(context);
                },
                child: Text(
                  context.l10n.ok,
                  style: TextStyle(color: context.primaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSpeedLimitDialog(BuildContext context, int current) {
    final options = [0, 128, 256, 512, 1024, 2048, 5120, 10240];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limite de vitesse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((kb) {
            final label = kb == 0
                ? 'Désactivée'
                : kb < 1024
                    ? '$kb KB/s'
                    : '${(kb / 1024).toStringAsFixed(0)} MB/s';
            return RadioListTile<int>(
              title: Text(label),
              value: kb,
              groupValue: current,
              onChanged: (v) {
                if (v != null) {
                  ref.read(speedLimitKBsStateProvider.notifier).set(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final data = (
      'LocalFolder',
      [
        (
          'MangaName',
          [
            ('cover.jpg', Icons.image_outlined),
            (
              'Chapter1',
              [
                ('Page1.jpg', Icons.image_outlined),
                ('Page2.jpeg', Icons.image_outlined),
              ],
            ),
            ('Chapter2.cbz', Icons.folder_zip_outlined),
          ],
        ),
        (
          'AnimeName',
          [
            ('cover.jpg', Icons.image_outlined),
            ('Episode1.mp4', Icons.video_file_outlined),
            (
              'Episode1_subtitles',
              [('en.srt', Icons.subtitles_outlined)],
            ),
          ],
        ),
        (
          'NovelName',
          [
            ('cover.jpg', Icons.image_outlined),
            ('NovelName.epub', Icons.book_outlined),
          ],
        ),
      ],
    );

    Widget buildSubFolder((String, dynamic) data, int level) {
      if (data.$2 is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  for (int i = 1; i < level; i++)
                    const WidgetSpan(child: SizedBox(width: 20)),
                  if (level > 0)
                    const WidgetSpan(
                        child: Icon(Icons.subdirectory_arrow_right)),
                  const WidgetSpan(child: Icon(Icons.folder)),
                  const WidgetSpan(child: SizedBox(width: 5)),
                  TextSpan(text: data.$1),
                ],
              ),
            ),
            ...(data.$2 as List<(String, dynamic)>)
                .map((e) => buildSubFolder(e, level + 1)),
          ],
        );
      }
      return Text.rich(
        TextSpan(
          children: [
            for (int i = 1; i < level; i++)
              const WidgetSpan(child: SizedBox(width: 20)),
            if (level > 0)
              const WidgetSpan(child: Icon(Icons.subdirectory_arrow_right)),
            WidgetSpan(child: Icon(data.$2 as IconData)),
            const WidgetSpan(child: SizedBox(width: 5)),
            TextSpan(text: data.$1),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.local_folder_structure),
        content: SizedBox(
          width: context.width(0.6),
          height: context.height(0.8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                SingleChildScrollView(child: buildSubFolder(data, 0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFolder(
    AppLocalizations l10n,
    List<String> localFolders,
    String folder, {
    bool isDefault = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('folder_${folder.hashCode}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                    topRight: Radius.circular(10),
                    topLeft: Radius.circular(10),
                  ),
                ),
              ),
              onPressed: null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.label_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: Text(folder)),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                            fontSize: 10, color: scheme.primary),
                      ),
                    ),
                ],
              ),
            ),
            if (!isDefault)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.delete),
                          content: Text('${l10n.delete} $folder'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () {
                                final temp = localFolders.toList();
                                temp.removeAt(temp.indexOf(folder));
                                ref
                                    .read(localFoldersStateProvider.notifier)
                                    .set(temp);
                                Navigator.pop(context);
                              },
                              child: Text(l10n.ok),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outlined),
                    tooltip: 'Supprimer le dossier',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets (private to this library)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style:
            TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final ColorScheme scheme;

  const _BadgeChip({required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.primary,
          fontSize: 13,
        ),
      ),
    );
  }
}
