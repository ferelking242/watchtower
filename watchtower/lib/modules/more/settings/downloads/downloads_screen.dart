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

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure download settings are loaded on screen open
    DownloadSettingsService.instance.load();
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
    final swipeLeft = ref.watch(swipeLeftActionStateProvider);
    final swipeRight = ref.watch(swipeRightActionStateProvider);
    final l10n = l10nLocalizations(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n!.downloads)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────
            // DOWNLOAD MODE
            // ─────────────────────────────────────────
            _SectionHeader(title: 'Download Mode'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: DownloadMode.values.map((mode) {
                  final selected = downloadMode == mode;
                  return _DownloadModeCard(
                    mode: mode,
                    selected: selected,
                    onTap: () {
                      ref.read(downloadModeStateProvider.notifier).set(mode);
                    },
                  );
                }).toList(),
              ),
            ),

            // ─────────────────────────────────────────
            // GENERAL SETTINGS
            // ─────────────────────────────────────────
            _SectionHeader(title: 'General'),
            SwitchListTile(
              value: onlyOnWifiState,
              title: Text(l10n.only_on_wifi),
              onChanged: (value) {
                ref.read(onlyOnWifiStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: saveAsCBZArchiveState,
              title: Text(l10n.save_as_cbz_archive),
              onChanged: (value) {
                ref.read(saveAsCBZArchiveStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: deleteDownloadAfterReading,
              title: Text(l10n.delete_download_after_reading),
              onChanged: (value) {
                ref
                    .read(deleteDownloadAfterReadingStateProvider.notifier)
                    .set(value);
              },
            ),
            ListTile(
              onTap: () {
                int currentIntValue = concurrentDownloads;
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.l10n.concurrent_downloads),
                      content: StatefulBuilder(
                        builder: (context, setState) => SizedBox(
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              NumberPicker(
                                value: currentIntValue,
                                minValue: 1,
                                maxValue: 10,
                                step: 1,
                                haptics: true,
                                textMapper: (numberText) => numberText,
                                onChanged: (value) =>
                                    setState(() => currentIntValue = value),
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
                              onPressed: () async {
                                ref
                                    .read(concurrentDownloadsStateProvider.notifier)
                                    .set(currentIntValue);
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
                    );
                  },
                );
              },
              title: Text(context.l10n.concurrent_downloads),
              subtitle: Text(
                '$concurrentDownloads',
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
              ),
            ),

            // ─────────────────────────────────────────
            // SWIPE ACTIONS
            // ─────────────────────────────────────────
            _SectionHeader(title: 'Swipe Actions (Download Queue)'),
            _SwipeActionTile(
              label: 'Swipe Left',
              icon: Icons.swipe_left_outlined,
              current: swipeLeft,
              onChanged: (v) =>
                  ref.read(swipeLeftActionStateProvider.notifier).set(v),
            ),
            _SwipeActionTile(
              label: 'Swipe Right',
              icon: Icons.swipe_right_outlined,
              current: swipeRight,
              onChanged: (v) =>
                  ref.read(swipeRightActionStateProvider.notifier).set(v),
            ),

            // ─────────────────────────────────────────
            // LOCAL FOLDERS
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
            const SizedBox(height: 24),
          ],
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
              [
                ("en.srt", Icons.subtitles_outlined),
              ],
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
                    WidgetSpan(child: Icon(Icons.subdirectory_arrow_right)),
                  WidgetSpan(child: Icon(Icons.folder)),
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
              WidgetSpan(child: Icon(Icons.subdirectory_arrow_right)),
            WidgetSpan(child: Icon(data.$2 as IconData)),
            const WidgetSpan(child: SizedBox(width: 5)),
            TextSpan(text: data.$1),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
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
                        builder: (context) {
                          return AlertDialog(
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
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.delete_outlined),
                    tooltip: 'Remove folder',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────────────────────

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

class _DownloadModeCard extends StatelessWidget {
  final DownloadMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _DownloadModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (mode) {
      case DownloadMode.internalDownloader:
        return Icons.download_outlined;
      case DownloadMode.fkFallbackZeus:
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline.withOpacity(0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withOpacity(0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                            color: selected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (mode == DownloadMode.fkFallbackZeus) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 22),
            ],
          ),
        ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }
}
