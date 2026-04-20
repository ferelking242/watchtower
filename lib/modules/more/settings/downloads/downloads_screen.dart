import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:numberpicker/numberpicker.dart';

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
    final saveAsCBZArchiveState = ref.watch(saveAsCBZArchiveStateProvider);
    final deleteDownloadAfterReading =
        ref.watch(deleteDownloadAfterReadingStateProvider);
    final onlyOnWifiState = ref.watch(onlyOnWifiStateProvider);
    final concurrentDownloads = ref.watch(concurrentDownloadsStateProvider);
    final localFolders = ref.watch(localFoldersStateProvider);
    final downloadMode = ref.watch(downloadModeStateProvider);
    final mangaConnections = ref.watch(mangaConnectionsStateProvider);
    final animeConnections = ref.watch(animeConnectionsStateProvider);
    final swipeLeft = ref.watch(swipeLeftActionStateProvider);
    final swipeRight = ref.watch(swipeRightActionStateProvider);
    final l10n = l10nLocalizations(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloads)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────
            // TÉLÉCHARGEUR PAR MÉDIA — 3 ONGLETS
            // ─────────────────────────────────────────
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
                      Tab(
                        icon: Icon(Icons.play_circle_outline),
                        text: 'Watch',
                      ),
                      Tab(icon: Icon(Icons.menu_book_outlined), text: 'Manga'),
                      Tab(icon: Icon(Icons.auto_stories_outlined), text: 'Novel'),
                    ],
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    indicatorColor: scheme.primary,
                    dividerColor: Colors.transparent,
                  ),
                  SizedBox(
                    height: 340,
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // ── Watch (Anime) tab ───────────────────────────
                        _AnimeTab(
                          downloadMode: downloadMode,
                          animeConnections: animeConnections,
                          onModeChanged: (mode) =>
                              ref.read(downloadModeStateProvider.notifier).set(mode),
                          onConnectionsChanged: (v) =>
                              ref.read(animeConnectionsStateProvider.notifier).set(v),
                        ),
                        // ── Manga tab ───────────────────────────────────
                        _MangaTab(
                          mangaConnections: mangaConnections,
                          saveAsCBZ: saveAsCBZArchiveState,
                          deleteAfterReading: deleteDownloadAfterReading,
                          onConnectionsChanged: (v) =>
                              ref.read(mangaConnectionsStateProvider.notifier).set(v),
                          onCBZChanged: (v) =>
                              ref.read(saveAsCBZArchiveStateProvider.notifier).set(v),
                          onDeleteChanged: (v) =>
                              ref
                                  .read(
                                    deleteDownloadAfterReadingStateProvider.notifier,
                                  )
                                  .set(v),
                        ),
                        // ── Novel tab ───────────────────────────────────
                        const _NovelTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────
            // GÉNÉRAL
            // ─────────────────────────────────────────
            _SectionHeader(title: 'Général'),
            SwitchListTile(
              value: onlyOnWifiState,
              title: Text(l10n.only_on_wifi),
              onChanged: (value) {
                ref.read(onlyOnWifiStateProvider.notifier).set(value);
              },
            ),
            ListTile(
              onTap: () => _showNumberPickerDialog(
                context,
                title: context.l10n.concurrent_downloads,
                current: concurrentDownloads,
                min: 1,
                max: 10,
                onSave: (v) =>
                    ref.read(concurrentDownloadsStateProvider.notifier).set(v),
              ),
              title: Text(context.l10n.concurrent_downloads),
              subtitle: Text(
                '$concurrentDownloads chapitre(s) en parallèle',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),

            // ─────────────────────────────────────────
            // ACTIONS DE BALAYAGE
            // ─────────────────────────────────────────
            _SectionHeader(title: 'Actions de balayage (file de téléchargement)'),
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

            // ─────────────────────────────────────────
            // DOSSIERS LOCAUX
            // ─────────────────────────────────────────
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
                    builder: (context, snapshot) => snapshot.data?.path != null
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
// Anime tab
// ══════════════════════════════════════════════════════════════════════════════

class _AnimeTab extends StatelessWidget {
  final DownloadMode downloadMode;
  final int animeConnections;
  final void Function(DownloadMode) onModeChanged;
  final void Function(int) onConnectionsChanged;

  const _AnimeTab({
    required this.downloadMode,
    required this.animeConnections,
    required this.onModeChanged,
    required this.onConnectionsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...DownloadMode.values.map(
            (mode) => _EngineCard(
              mode: mode,
              selected: downloadMode == mode,
              onTap: () => onModeChanged(mode),
            ),
          ),
          const SizedBox(height: 8),
          _ConnectionsTile(
            label: 'Connexions HLS simultanées',
            subtitle: 'Segments M3U8 téléchargés en parallèle par épisode',
            value: animeConnections,
            icon: Icons.cable_outlined,
            onChanged: onConnectionsChanged,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Manga tab
// ══════════════════════════════════════════════════════════════════════════════

class _MangaTab extends StatelessWidget {
  final int mangaConnections;
  final bool saveAsCBZ;
  final bool deleteAfterReading;
  final void Function(int) onConnectionsChanged;
  final void Function(bool) onCBZChanged;
  final void Function(bool) onDeleteChanged;

  const _MangaTab({
    required this.mangaConnections,
    required this.saveAsCBZ,
    required this.deleteAfterReading,
    required this.onConnectionsChanged,
    required this.onCBZChanged,
    required this.onDeleteChanged,
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
          const SizedBox(height: 4),
          SwitchListTile(
            value: saveAsCBZ,
            title: const Text('Sauvegarder en CBZ'),
            subtitle: const Text(
              'Archive les chapitres au format CBZ après téléchargement',
              style: TextStyle(fontSize: 11),
            ),
            onChanged: onCBZChanged,
          ),
          SwitchListTile(
            value: deleteAfterReading,
            title: const Text('Supprimer après lecture'),
            subtitle: const Text(
              'Supprime le chapitre une fois lu',
              style: TextStyle(fontSize: 11),
            ),
            onChanged: onDeleteChanged,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Novel tab
// ══════════════════════════════════════════════════════════════════════════════

class _NovelTab extends StatelessWidget {
  const _NovelTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: scheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Téléchargeur interne',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les chapitres de novel sont téléchargés via l\'extension source '
            'et sauvegardés en HTML. Aucun choix de moteur requis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
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
      case DownloadMode.internalFallback:
        return Icons.auto_fix_high_outlined;
      case DownloadMode.zeusDl:
        return Icons.bolt_outlined;
      case DownloadMode.auto:
        return Icons.smart_toy_outlined;
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
                      maxLines: 1,
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
                  maxValue: 10,
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
