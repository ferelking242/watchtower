import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    DownloadSettingsService.instance.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final scheme = Theme.of(context).colorScheme;
    final localFolders = ref.watch(localFoldersStateProvider);
    final swipeLeft = ref.watch(swipeLeftActionStateProvider);
    final swipeRight = ref.watch(swipeRightActionStateProvider);
    final concurrentDownloads = ref.watch(concurrentDownloadsStateProvider);

    // Watch tab state
    final downloadMode = ref.watch(downloadModeStateProvider);
    final animeConnections = ref.watch(animeConnectionsStateProvider);
    final watchOnlyOnWifi = ref.watch(watchOnlyOnWifiStateProvider);
    final autoDownloadNewEpisodes =
        ref.watch(autoDownloadNewEpisodesStateProvider);
    final downloadFillerEpisodes =
        ref.watch(downloadFillerEpisodesStateProvider);
    final anticipatoryDownloadWatch =
        ref.watch(anticipatoryDownloadWatchStateProvider);
    final alwaysUseExternalDownloader =
        ref.watch(alwaysUseExternalDownloaderStateProvider);
    final preferredExternalDownloader =
        ref.watch(preferredExternalDownloaderStateProvider);

    // Manga tab state
    final mangaConnections = ref.watch(mangaConnectionsStateProvider);
    final archiveFormat = ref.watch(mangaArchiveFormatStateProvider);
    final mangaOnlyOnWifi = ref.watch(mangaOnlyOnWifiStateProvider);
    final autoDownloadNewChapters =
        ref.watch(autoDownloadNewChaptersStateProvider);
    final deleteAfterMarkedRead = ref.watch(deleteAfterMarkedReadStateProvider);
    final allowDeletingBookmarked =
        ref.watch(allowDeletingBookmarkedChaptersStateProvider);
    final anticipatoryDownloadRead =
        ref.watch(anticipatoryDownloadReadStateProvider);

    // Novel tab state
    final novelConnections = ref.watch(novelConnectionsStateProvider);
    final novelOnlyOnWifi = ref.watch(novelOnlyOnWifiStateProvider);

    // Shared state
    final speedLimit = ref.watch(speedLimitKBsStateProvider);

    // Per-type simultaneous downloads
    final watchSimultaneous = ref.watch(watchSimultaneousStateProvider);
    final mangaSimultaneous = ref.watch(mangaSimultaneousStateProvider);
    final novelSimultaneous = ref.watch(novelSimultaneousStateProvider);

    // Card buttons
    final cardButtons = ref.watch(cardButtonsStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Téléchargeur par média — 3 onglets ───────────────────────
            _SectionHeader(title: 'Téléchargeur par média'),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.play_circle_outline), text: 'Watch'),
                      Tab(
                          icon: Icon(Icons.menu_book_outlined), text: 'Manga'),
                      Tab(
                          icon: Icon(Icons.auto_stories_outlined),
                          text: 'Novel'),
                    ],
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    indicatorColor: scheme.primary,
                    dividerColor: Colors.transparent,
                  ),
                  SizedBox(
                    height: 580,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Watch tab ──────────────────────────────────────
                        _WatchTab(
                          downloadMode: downloadMode,
                          animeConnections: animeConnections,
                          watchSimultaneous: watchSimultaneous,
                          watchOnlyOnWifi: watchOnlyOnWifi,
                          autoDownloadNewEpisodes: autoDownloadNewEpisodes,
                          downloadFillerEpisodes: downloadFillerEpisodes,
                          anticipatoryDownload: anticipatoryDownloadWatch,
                          alwaysUseExternal: alwaysUseExternalDownloader,
                          preferredExternal: preferredExternalDownloader,
                          onModeChanged: (m) =>
                              ref
                                  .read(downloadModeStateProvider.notifier)
                                  .set(m),
                          onConnectionsChanged: (v) =>
                              ref
                                  .read(animeConnectionsStateProvider.notifier)
                                  .set(v),
                          onSimultaneousChanged: (v) =>
                              ref
                                  .read(watchSimultaneousStateProvider.notifier)
                                  .set(v),
                          onWifiChanged: (v) =>
                              ref
                                  .read(watchOnlyOnWifiStateProvider.notifier)
                                  .set(v),
                          onAutoEpisodesChanged: (v) =>
                              ref
                                  .read(
                                    autoDownloadNewEpisodesStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                          onFillerChanged: (v) =>
                              ref
                                  .read(
                                    downloadFillerEpisodesStateProvider.notifier,
                                  )
                                  .set(v),
                          onAnticipatoryChanged: (v) =>
                              ref
                                  .read(
                                    anticipatoryDownloadWatchStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                          onAlwaysExternalChanged: (v) =>
                              ref
                                  .read(
                                    alwaysUseExternalDownloaderStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                          onPreferredExternalChanged: (v) =>
                              ref
                                  .read(
                                    preferredExternalDownloaderStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                        ),
                        // ── Manga tab ──────────────────────────────────────
                        _MangaTab(
                          mangaConnections: mangaConnections,
                          mangaSimultaneous: mangaSimultaneous,
                          archiveFormat: archiveFormat,
                          mangaOnlyOnWifi: mangaOnlyOnWifi,
                          autoDownloadNewChapters: autoDownloadNewChapters,
                          deleteAfterMarkedRead: deleteAfterMarkedRead,
                          allowDeletingBookmarked: allowDeletingBookmarked,
                          anticipatoryDownloadRead: anticipatoryDownloadRead,
                          onConnectionsChanged: (v) =>
                              ref
                                  .read(mangaConnectionsStateProvider.notifier)
                                  .set(v),
                          onSimultaneousChanged: (v) =>
                              ref
                                  .read(mangaSimultaneousStateProvider.notifier)
                                  .set(v),
                          onArchiveFormatChanged: (f) =>
                              ref
                                  .read(mangaArchiveFormatStateProvider.notifier)
                                  .set(f),
                          onWifiChanged: (v) =>
                              ref
                                  .read(mangaOnlyOnWifiStateProvider.notifier)
                                  .set(v),
                          onAutoChaptersChanged: (v) =>
                              ref
                                  .read(
                                    autoDownloadNewChaptersStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                          onDeleteAfterReadChanged: (v) =>
                              ref
                                  .read(
                                    deleteAfterMarkedReadStateProvider.notifier,
                                  )
                                  .set(v),
                          onAllowDeletingBookmarkedChanged: (v) =>
                              ref
                                  .read(
                                    allowDeletingBookmarkedChaptersStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                          onAnticipatoryReadChanged: (v) =>
                              ref
                                  .read(
                                    anticipatoryDownloadReadStateProvider
                                        .notifier,
                                  )
                                  .set(v),
                        ),
                        // ── Novel tab ──────────────────────────────────────
                        _NovelTab(
                          novelConnections: novelConnections,
                          novelSimultaneous: novelSimultaneous,
                          novelOnlyOnWifi: novelOnlyOnWifi,
                          onConnectionsChanged: (v) =>
                              ref
                                  .read(novelConnectionsStateProvider.notifier)
                                  .set(v),
                          onSimultaneousChanged: (v) =>
                              ref
                                  .read(novelSimultaneousStateProvider.notifier)
                                  .set(v),
                          onWifiChanged: (v) =>
                              ref
                                  .read(novelOnlyOnWifiStateProvider.notifier)
                                  .set(v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Téléchargements (options globales) ───────────────────────
            _SectionHeader(title: 'Téléchargements'),

            // Concurrent downloads
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Nombre max. de téléchargements'),
              subtitle: Text(
                '$concurrentDownloads téléchargement(s) simultané(s)',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: const Icon(Icons.chevron_right),
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

            // Speed limit
            ListTile(
              leading: const Icon(Icons.speed_outlined),
              title: const Text('Limite de vitesse'),
              subtitle: Text(
                speedLimit == 0
                    ? 'Désactivée'
                    : '${speedLimit} KB/s',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSpeedLimitDialog(context, speedLimit),
            ),

            // ─── Suppression des chapitres ────────────────────────────────
            _SectionHeader(title: 'Suppression des chapitres'),
            ListTile(
              leading: const Icon(Icons.auto_delete_outlined),
              title: const Text('Suppression automatique après lecture'),
              subtitle: Text(
                ref.watch(deleteDownloadAfterReadingStateProvider)
                    ? 'Activée'
                    : 'Désactivée',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: Switch(
                value: ref.watch(deleteDownloadAfterReadingStateProvider),
                onChanged: (v) =>
                    ref
                        .read(deleteDownloadAfterReadingStateProvider.notifier)
                        .set(v),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bookmark_outlined),
              title: const Text('Autoriser la suppression des chapitres marqués'),
              subtitle: const Text(
                'Permet de supprimer les chapitres avec un marque-page',
                style: TextStyle(fontSize: 11),
              ),
              value: ref.watch(allowDeletingBookmarkedChaptersStateProvider),
              onChanged: (v) =>
                  ref
                      .read(
                        allowDeletingBookmarkedChaptersStateProvider.notifier,
                      )
                      .set(v),
            ),

            // ─── Design des cartes de téléchargement ──────────────────────
            _SectionHeader(title: 'Design des cartes de téléchargement'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Boutons affichés sur chaque carte de téléchargement',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...CardButton.values.map((btn) {
              final enabled = cardButtons.contains(btn);
              return CheckboxListTile(
                dense: true,
                secondary: Icon(btn.icon, size: 20),
                title: Text(btn.label),
                value: enabled,
                onChanged: (_) => ref
                    .read(cardButtonsStateProvider.notifier)
                    .toggle(btn),
              );
            }),

            // ─── Actions de balayage ──────────────────────────────────────
            _SectionHeader(
                title: 'Actions de balayage (file de téléchargement)'),
            _SwipeActionTile(
              label: 'Balayer à gauche',
              icon: Icons.swipe_left_outlined,
              current: swipeLeft,
              onChanged: (v) =>
                  ref.read(swipeLeftActionStateProvider.notifier).set(v),
            ),
            _SwipeActionTile(
              label: 'Balayer à droite',
              icon: Icons.swipe_right_outlined,
              current: swipeRight,
              onChanged: (v) =>
                  ref.read(swipeRightActionStateProvider.notifier).set(v),
            ),

            // ─── Dossiers locaux ──────────────────────────────────────────
            _SectionHeader(title: context.l10n.local_folder),
            ListTile(
              onTap: () async => ref.read(scanLocalLibraryProvider.future),
              title: Text(context.l10n.rescan_local_folder),
              leading: const Icon(Icons.refresh_outlined),
            ),
            ListTile(
              onTap: () async {
                final result = await FilePicker.getDirectoryPath();
                if (result != null) {
                  final temp = localFolders.toList();
                  temp.add(result);
                  ref.read(localFoldersStateProvider.notifier).set(temp);
                }
              },
              title: Text(context.l10n.add_local_folder),
              leading: const Icon(Icons.add_outlined),
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
      "LocalFolder",
      [
        (
          "MangaName",
          [
            ("cover.jpg", Icons.image_outlined),
            (
              "Chapter1",
              [
                ("Page1.jpg", Icons.image_outlined),
                ("Page2.jpeg", Icons.image_outlined),
              ],
            ),
            ("Chapter2.cbz", Icons.folder_zip_outlined),
          ],
        ),
        (
          "AnimeName",
          [
            ("cover.jpg", Icons.image_outlined),
            ("Episode1.mp4", Icons.video_file_outlined),
            (
              "Episode1_subtitles",
              [("en.srt", Icons.subtitles_outlined)],
            ),
          ],
        ),
        (
          "NovelName",
          [
            ("cover.jpg", Icons.image_outlined),
            ("NovelName.epub", Icons.book_outlined),
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
                      child: Icon(Icons.subdirectory_arrow_right),
                    ),
                  const WidgetSpan(child: Icon(Icons.folder)),
                  const WidgetSpan(child: SizedBox(width: 5)),
                  TextSpan(text: data.$1),
                ],
              ),
            ),
            ...(data.$2 as List<(String, dynamic)>).map(
              (e) => buildSubFolder(e, level + 1),
            ),
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
            child: SingleChildScrollView(child: buildSubFolder(data, 0)),
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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.primaryColor,
                        ),
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

// ══════════════════════════════════════════════════════════════════════════════
// Watch Tab
// ══════════════════════════════════════════════════════════════════════════════

class _WatchTab extends StatelessWidget {
  final DownloadMode downloadMode;
  final int animeConnections;
  final int watchSimultaneous;
  final bool watchOnlyOnWifi;
  final bool autoDownloadNewEpisodes;
  final bool downloadFillerEpisodes;
  final bool anticipatoryDownload;
  final bool alwaysUseExternal;
  final String? preferredExternal;
  final void Function(DownloadMode) onModeChanged;
  final void Function(int) onConnectionsChanged;
  final void Function(int) onSimultaneousChanged;
  final void Function(bool) onWifiChanged;
  final void Function(bool) onAutoEpisodesChanged;
  final void Function(bool) onFillerChanged;
  final void Function(bool) onAnticipatoryChanged;
  final void Function(bool) onAlwaysExternalChanged;
  final void Function(String?) onPreferredExternalChanged;

  const _WatchTab({
    required this.downloadMode,
    required this.animeConnections,
    required this.watchSimultaneous,
    required this.watchOnlyOnWifi,
    required this.autoDownloadNewEpisodes,
    required this.downloadFillerEpisodes,
    required this.anticipatoryDownload,
    required this.alwaysUseExternal,
    required this.preferredExternal,
    required this.onModeChanged,
    required this.onConnectionsChanged,
    required this.onSimultaneousChanged,
    required this.onWifiChanged,
    required this.onAutoEpisodesChanged,
    required this.onFillerChanged,
    required this.onAnticipatoryChanged,
    required this.onAlwaysExternalChanged,
    required this.onPreferredExternalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engine selector
          ...DownloadMode.values.map(
            (mode) => _EngineCard(
              mode: mode,
              selected: downloadMode == mode,
              onTap: () => onModeChanged(mode),
            ),
          ),
          const SizedBox(height: 6),
          _ConnectionsTile(
            label: 'Connexions HLS simultanées',
            subtitle: 'Segments téléchargés en parallèle par épisode',
            value: animeConnections,
            icon: Icons.cable_outlined,
            onChanged: onConnectionsChanged,
            scheme: scheme,
          ),
          _ConnectionsTile(
            label: 'Épisodes simultanés (file)',
            subtitle: 'Nombre d\'épisodes téléchargés en même temps',
            value: watchSimultaneous,
            icon: Icons.queue_outlined,
            onChanged: onSimultaneousChanged,
            scheme: scheme,
          ),
          const Divider(height: 16),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.wifi_outlined),
            title: const Text('Wi-Fi uniquement'),
            subtitle: const Text(
              'Télécharger uniquement via Wi-Fi',
              style: TextStyle(fontSize: 11),
            ),
            value: watchOnlyOnWifi,
            onChanged: onWifiChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.new_releases_outlined),
            title: const Text('Télécharger les nouveaux épisodes'),
            value: autoDownloadNewEpisodes,
            onChanged: onAutoEpisodesChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.filter_list_outlined),
            title: const Text('Autoriser les épisodes filler'),
            value: downloadFillerEpisodes,
            onChanged: onFillerChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.fast_forward_outlined),
            title: const Text('Téléchargement anticipé (visionnage)'),
            subtitle: const Text(
              'Pré-télécharge pendant le visionnage si les 2 eps suivants sont dispo',
              style: TextStyle(fontSize: 10),
            ),
            value: anticipatoryDownload,
            onChanged: onAnticipatoryChanged,
          ),
          const Divider(height: 16),
          // External downloader section
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.open_in_new_outlined),
            title: const Text('Toujours utiliser un téléchargeur externe'),
            value: alwaysUseExternal,
            onChanged: onAlwaysExternalChanged,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.apps_outlined),
            title: const Text('App de téléchargement préférée'),
            subtitle: Text(
              preferredExternal ?? 'Aucune',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExternalDownloaderPicker(context),
          ),
        ],
      ),
    );
  }

  void _showExternalDownloaderPicker(BuildContext context) {
    final apps = _ExternalDownloaderRegistry.all;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App de téléchargement préférée'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioListTile<String?>(
                title: const Text('Aucune'),
                value: null,
                groupValue: preferredExternal,
                onChanged: (v) {
                  onPreferredExternalChanged(null);
                  Navigator.pop(ctx);
                },
              ),
              ...apps.map((app) => _ExternalAppTile(
                    app: app,
                    selected: preferredExternal == app.id,
                    onSelect: () {
                      onPreferredExternalChanged(app.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Manga Tab
// ══════════════════════════════════════════════════════════════════════════════

class _MangaTab extends StatelessWidget {
  final int mangaConnections;
  final int mangaSimultaneous;
  final MangaArchiveFormat archiveFormat;
  final bool mangaOnlyOnWifi;
  final bool autoDownloadNewChapters;
  final bool deleteAfterMarkedRead;
  final bool allowDeletingBookmarked;
  final bool anticipatoryDownloadRead;
  final void Function(int) onConnectionsChanged;
  final void Function(int) onSimultaneousChanged;
  final void Function(MangaArchiveFormat) onArchiveFormatChanged;
  final void Function(bool) onWifiChanged;
  final void Function(bool) onAutoChaptersChanged;
  final void Function(bool) onDeleteAfterReadChanged;
  final void Function(bool) onAllowDeletingBookmarkedChanged;
  final void Function(bool) onAnticipatoryReadChanged;

  const _MangaTab({
    required this.mangaConnections,
    required this.mangaSimultaneous,
    required this.archiveFormat,
    required this.mangaOnlyOnWifi,
    required this.autoDownloadNewChapters,
    required this.deleteAfterMarkedRead,
    required this.allowDeletingBookmarked,
    required this.anticipatoryDownloadRead,
    required this.onConnectionsChanged,
    required this.onSimultaneousChanged,
    required this.onArchiveFormatChanged,
    required this.onWifiChanged,
    required this.onAutoChaptersChanged,
    required this.onDeleteAfterReadChanged,
    required this.onAllowDeletingBookmarkedChanged,
    required this.onAnticipatoryReadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConnectionsTile(
            label: 'Connexions simultanées',
            subtitle: 'Images téléchargées en parallèle par chapitre',
            value: mangaConnections,
            icon: Icons.image_outlined,
            onChanged: onConnectionsChanged,
            scheme: scheme,
          ),
          _ConnectionsTile(
            label: 'Chapitres simultanés (file)',
            subtitle: 'Nombre de chapitres téléchargés en même temps',
            value: mangaSimultaneous,
            icon: Icons.queue_outlined,
            onChanged: onSimultaneousChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 4),
          // Archive format row
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_zip_outlined),
            title: const Text('Archiver en…'),
            trailing: _ArchiveFormatSelector(
              value: archiveFormat,
              onChanged: onArchiveFormatChanged,
            ),
          ),
          const Divider(height: 16),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.wifi_outlined),
            title: const Text('Wi-Fi uniquement'),
            subtitle: const Text(
              'Télécharger uniquement via Wi-Fi',
              style: TextStyle(fontSize: 11),
            ),
            value: mangaOnlyOnWifi,
            onChanged: onWifiChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.new_releases_outlined),
            title: const Text('Télécharger les nouveaux chapitres'),
            value: autoDownloadNewChapters,
            onChanged: onAutoChaptersChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.auto_delete_outlined),
            title: const Text('Supprimer après lecture'),
            subtitle: const Text(
              'Supprime le chapitre une fois lu',
              style: TextStyle(fontSize: 11),
            ),
            value: deleteAfterMarkedRead,
            onChanged: onDeleteAfterReadChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.bookmark_outlined),
            title: const Text('Supprimer même les chapitres marqués'),
            value: allowDeletingBookmarked,
            onChanged: onAllowDeletingBookmarkedChanged,
          ),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.fast_forward_outlined),
            title: const Text('Téléchargement anticipé (lecture)'),
            subtitle: const Text(
              'Fonctionne si le chapitre actuel et suivant sont déjà téléchargés',
              style: TextStyle(fontSize: 10),
            ),
            value: anticipatoryDownloadRead,
            onChanged: onAnticipatoryReadChanged,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Novel Tab
// ══════════════════════════════════════════════════════════════════════════════

class _NovelTab extends StatelessWidget {
  final int novelConnections;
  final int novelSimultaneous;
  final bool novelOnlyOnWifi;
  final void Function(int) onConnectionsChanged;
  final void Function(int) onSimultaneousChanged;
  final void Function(bool) onWifiChanged;

  const _NovelTab({
    required this.novelConnections,
    required this.novelSimultaneous,
    required this.novelOnlyOnWifi,
    required this.onConnectionsChanged,
    required this.onSimultaneousChanged,
    required this.onWifiChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_stories_outlined,
                    color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Téléchargement interne via l\'extension source. Chapitres sauvegardés en HTML.',
                    style: TextStyle(
                        fontSize: 11, color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          _ConnectionsTile(
            label: 'Connexions simultanées',
            subtitle: 'Connexions parallèles par chapitre',
            value: novelConnections,
            icon: Icons.download_outlined,
            onChanged: onConnectionsChanged,
            scheme: scheme,
          ),
          _ConnectionsTile(
            label: 'Chapitres simultanés (file)',
            subtitle: 'Nombre de chapitres téléchargés en même temps',
            value: novelSimultaneous,
            icon: Icons.queue_outlined,
            onChanged: onSimultaneousChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            dense: true,
            secondary: const Icon(Icons.wifi_outlined),
            title: const Text('Wi-Fi uniquement'),
            subtitle: const Text(
              'Télécharger uniquement via Wi-Fi',
              style: TextStyle(fontSize: 11),
            ),
            value: novelOnlyOnWifi,
            onChanged: onWifiChanged,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// External Downloader Registry
// ══════════════════════════════════════════════════════════════════════════════

class _ExternalDownloaderApp {
  final String id;
  final String name;
  final String? androidPackage;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? altStoreUrl;
  final String? pcUrl;
  final String description;

  const _ExternalDownloaderApp({
    required this.id,
    required this.name,
    required this.description,
    this.androidPackage,
    this.playStoreUrl,
    this.appStoreUrl,
    this.altStoreUrl,
    this.pcUrl,
  });
}

class _ExternalDownloaderRegistry {
  static const all = [
    _ExternalDownloaderApp(
      id: 'adm',
      name: 'ADM — Advanced Download Manager',
      description: 'Gestionnaire de téléchargement multi-thread pour Android.',
      androidPackage: 'com.dv.adm',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.dv.adm',
      appStoreUrl: null,
    ),
    _ExternalDownloaderApp(
      id: '1dm',
      name: '1DM — 1Downloader',
      description: 'Téléchargeur rapide avec support HLS et DASH pour Android.',
      androidPackage: 'idm.internet.download.manager',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=idm.internet.download.manager',
      appStoreUrl:
          'https://apps.apple.com/app/1downloader-download-manager/id1451985776',
    ),
    _ExternalDownloaderApp(
      id: 'fdm',
      name: 'FDM — Free Download Manager',
      description: 'Téléchargeur multiplateforme gratuit et open-source.',
      androidPackage: 'org.freedownloadmanager.fdm',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=org.freedownloadmanager.fdm',
      appStoreUrl: null,
      pcUrl: 'https://www.freedownloadmanager.org/',
    ),
    _ExternalDownloaderApp(
      id: 'idm',
      name: 'IDM — Internet Download Manager',
      description: 'Téléchargeur haute vitesse avec reprise (Windows).',
      pcUrl: 'https://www.internetdownloadmanager.com/',
    ),
    _ExternalDownloaderApp(
      id: 'jdownloader',
      name: 'JDownloader',
      description: 'Téléchargeur open-source multiplateforme très populaire.',
      pcUrl: 'https://jdownloader.org/',
    ),
    _ExternalDownloaderApp(
      id: 'motrix',
      name: 'Motrix',
      description: 'Téléchargeur Aria2 open-source avec interface moderne.',
      pcUrl: 'https://motrix.app/',
    ),
  ];
}

class _ExternalAppTile extends StatelessWidget {
  final _ExternalDownloaderApp app;
  final bool selected;
  final VoidCallback onSelect;

  const _ExternalAppTile({
    required this.app,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Radio<bool>(
        value: true,
        groupValue: selected,
        onChanged: (_) => onSelect(),
      ),
      title: Text(app.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(app.description, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Platform.isAndroid &&
              ExternalDownloaderLauncher.packageMap.containsKey(app.id))
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              tooltip: 'Tester (lance ${app.name})',
              onPressed: () async {
                final ok = await ExternalDownloaderLauncher.launch(
                  url: 'https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4',
                  appId: app.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(ok
                          ? '${app.name} lancé via intent'
                          : 'Échec du lancement de ${app.name} (app installée ?)'),
                    ),
                  );
                }
              },
            ),
          if (app.playStoreUrl != null)
            IconButton(
              icon: const Icon(Icons.android_outlined, size: 18),
              tooltip: 'Google Play',
              onPressed: () =>
                  launchUrl(Uri.parse(app.playStoreUrl!)),
            ),
          if (app.appStoreUrl != null)
            IconButton(
              icon: const Icon(Icons.apple_outlined, size: 18),
              tooltip: 'App Store',
              onPressed: () =>
                  launchUrl(Uri.parse(app.appStoreUrl!)),
            ),
          if (app.pcUrl != null)
            IconButton(
              icon: const Icon(Icons.computer_outlined, size: 18),
              tooltip: 'Site officiel',
              onPressed: () => launchUrl(Uri.parse(app.pcUrl!)),
            ),
        ],
      ),
      onTap: onSelect,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Archive Format Selector
// ══════════════════════════════════════════════════════════════════════════════

class _ArchiveFormatSelector extends StatelessWidget {
  final MangaArchiveFormat value;
  final void Function(MangaArchiveFormat) onChanged;

  const _ArchiveFormatSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.12),
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

// ══════════════════════════════════════════════════════════════════════════════
// Helper widgets
// ══════════════════════════════════════════════════════════════════════════════

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

class _EngineCard extends StatelessWidget {
  final DownloadMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _EngineCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (mode) {
      case DownloadMode.internalDownloader:
        return Icons.download_outlined;
      case DownloadMode.zeusDl:
        return Icons.bolt_outlined;
      case DownloadMode.aria2:
        return Icons.account_tree_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 2 : 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline.withOpacity(0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withOpacity(0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mode.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color:
                                selected ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        if (mode.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Défaut',
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
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
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NumberPicker(
                  value: currentValue,
                  minValue: 1,
                  maxValue: 16,
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
                  onChanged(currentValue);
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
}

class _SwipeActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final SwipeAction current;
  final void Function(SwipeAction) onChanged;

  const _SwipeActionTile({
    required this.label,
    required this.icon,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        current.label,
        style: TextStyle(fontSize: 12, color: context.secondaryColor),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
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
          ),
        );
      },
    );
  }
}
