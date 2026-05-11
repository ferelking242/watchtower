import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart' show botToast;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';

class DownloadQueueScreen extends ConsumerStatefulWidget {
  const DownloadQueueScreen({super.key});

  @override
  ConsumerState<DownloadQueueScreen> createState() =>
      _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends ConsumerState<DownloadQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context);
    final queueState = ref.watch(downloadQueueStateProvider);
    final swipeLeft = ref.watch(swipeLeftActionStateProvider);
    final swipeRight = ref.watch(swipeRightActionStateProvider);

    return StreamBuilder(
      stream: isar.downloads
          .filter()
          .idIsNotNull()
          .isDownloadEqualTo(false)
          .isStartDownloadEqualTo(true)
          .sortBySucceededDesc()
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        final allEntries = snapshot.data ?? [];

        // Clean orphaned downloads (no chapter/manga linked)
        final orphanIds = <int>[];
        final entries = <Download>[];
        for (final d in allEntries) {
          if (d.chapter.value == null ||
              d.chapter.value?.manga.value == null) {
            if (d.id != null) orphanIds.add(d.id!);
          } else {
            entries.add(d);
          }
        }
        if (orphanIds.isNotEmpty) {
          isar.writeTxnSync(() {
            for (final id in orphanIds) {
              isar.downloads.deleteSync(id);
            }
          });
        }

        // Split into 3 tabs by ItemType
        final watchEntries = entries
            .where((d) => d.chapter.value?.manga.value?.itemType == ItemType.anime)
            .toList();
        final mangaEntries = entries
            .where((d) => d.chapter.value?.manga.value?.itemType == ItemType.manga)
            .toList();
        final novelEntries = entries
            .where((d) => d.chapter.value?.manga.value?.itemType == ItemType.novel)
            .toList();

        final allQueueLength = entries.length;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(l10n!.download_queue),
                const SizedBox(width: 8),
                Badge(
                  backgroundColor: Theme.of(context).focusColor,
                  label: Text(
                    allQueueLength.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall!.color,
                    ),
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline, size: 16),
                      const SizedBox(width: 4),
                      const Text('Watch'),
                      if (watchEntries.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _TabBadge(count: watchEntries.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 16),
                      const SizedBox(width: 4),
                      const Text('Manga'),
                      if (mangaEntries.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _TabBadge(count: mangaEntries.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_stories_outlined, size: 16),
                      const SizedBox(width: 4),
                      const Text('Novel'),
                      if (novelEntries.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _TabBadge(count: novelEntries.length),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ArrowPopupMenuButton<_GlobalAction>(
                popUpAnimationStyle: popupAnimationStyle,
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => _handleGlobalAction(
                  action,
                  entries,
                  ref,
                  context,
                ),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: _GlobalAction.pauseAll,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.pause_circle_outline),
                      title: Text('Pause All'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _GlobalAction.resumeAll,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.play_circle_outline),
                      title: Text('Resume All'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _GlobalAction.stopAll,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.stop_circle_outlined),
                      title: Text('Stop All'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _GlobalAction.deleteCompleted,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('Delete Completed'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _GlobalAction.retryFailed,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.replay_outlined),
                      title: Text('Retry Failed'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _DownloadTabList(
                entries: watchEntries,
                allEntries: entries,
                emptyIcon: Icons.play_circle_outline,
                emptyLabel: 'Aucun téléchargement Watch',
                queueState: queueState,
                swipeLeft: swipeLeft,
                swipeRight: swipeRight,
                onPauseResume: (e) => _togglePause(e, ref),
                onCancel: (e) => _cancelDownload(e, ref),
                onDelete: (e) => _deleteDownload(e),
                onRetry: (e) => _retryDownload(e, ref, context),
                onOpen: (e) => _openDownload(e, context),
              ),
              _DownloadTabList(
                entries: mangaEntries,
                allEntries: entries,
                emptyIcon: Icons.menu_book_outlined,
                emptyLabel: 'Aucun téléchargement Manga',
                queueState: queueState,
                swipeLeft: swipeLeft,
                swipeRight: swipeRight,
                onPauseResume: (e) => _togglePause(e, ref),
                onCancel: (e) => _cancelDownload(e, ref),
                onDelete: (e) => _deleteDownload(e),
                onRetry: (e) => _retryDownload(e, ref, context),
                onOpen: (e) => _openDownload(e, context),
              ),
              _DownloadTabList(
                entries: novelEntries,
                allEntries: entries,
                emptyIcon: Icons.auto_stories_outlined,
                emptyLabel: 'Aucun téléchargement Novel',
                queueState: queueState,
                swipeLeft: swipeLeft,
                swipeRight: swipeRight,
                onPauseResume: (e) => _togglePause(e, ref),
                onCancel: (e) => _cancelDownload(e, ref),
                onDelete: (e) => _deleteDownload(e),
                onRetry: (e) => _retryDownload(e, ref, context),
                onOpen: (e) => _openDownload(e, context),
              ),
            ],
          ),
          floatingActionButton: _PauseResumeAllFab(
            entries: entries,
            queueState: queueState,
          ),
        );
      },
    );
  }

  void _togglePause(Download element, WidgetRef ref) {
    final id = element.id ?? -1;
    if (id == -1) return;
    final wasPaused = ref.read(downloadQueueStateProvider).pausedIds.contains(id);
    ref.read(downloadQueueStateProvider.notifier).togglePause(id);
    if (wasPaused) {
      // Resuming: re-trigger the scheduler for internal engines
      ref.invalidate(processDownloadsProvider);
      ref.read(processDownloadsProvider());
    }
  }

  void _handleGlobalAction(
    _GlobalAction action,
    List<Download> entries,
    WidgetRef ref,
    BuildContext context,
  ) {
    switch (action) {
      case _GlobalAction.pauseAll:
        final ids = entries.map((e) => e.id ?? -1).toList();
        ref.read(downloadQueueStateProvider.notifier).pauseAll(ids);
        break;
      case _GlobalAction.resumeAll:
        ref.read(downloadQueueStateProvider.notifier).resumeAll();
        ref.read(processDownloadsProvider());
        break;
      case _GlobalAction.stopAll:
        for (final e in entries) {
          if (e.id != null) {
            ActiveDownloadRegistry.cancel(e.id!);
          }
        }
        break;
      case _GlobalAction.deleteCompleted:
        isar.writeTxnSync(() {
          final completed = isar.downloads
              .filter()
              .isDownloadEqualTo(true)
              .findAllSync();
          for (final d in completed) {
            if (d.id != null) isar.downloads.deleteSync(d.id!);
          }
        });
        break;
      case _GlobalAction.retryFailed:
        for (final e in entries) {
          if ((e.failed ?? 0) > 0 && e.chapter.value != null) {
            ref.read(downloadQueueStateProvider.notifier).incrementRetry(e.id ?? -1);
            ref.read(downloadChapterProvider(chapter: e.chapter.value!));
          }
        }
        break;
    }
  }

  /// Cancel: stop the download engine but KEEP the Isar record in queue
  void _cancelDownload(Download element, WidgetRef ref) {
    final id = element.id;
    if (id == null) return;
    // Cancel the engine but don't delete from DB — entry stays in queue as paused
    ActiveDownloadRegistry.cancel(id);
    DownloadIsolatePool.instance.cancelTask('$id');
    DownloadIsolatePool.instance.cancelTask('m3u8_$id');
    // Mark as paused in the UI state so user can resume later
    ref.read(downloadQueueStateProvider.notifier).setPaused(id, true);
    botToast('Téléchargement annulé. Appuyez sur ▶ pour reprendre.');
  }

  /// Delete: fully remove from Isar (no recovery)
  void _deleteDownload(Download element) {
    final id = element.id;
    if (id == null) return;
    // First cancel any running engine
    ActiveDownloadRegistry.cancel(id);
    DownloadIsolatePool.instance.cancelTask('$id');
    DownloadIsolatePool.instance.cancelTask('m3u8_$id');
    // Then remove from DB
    isar.writeTxnSync(() {
      isar.downloads.deleteSync(id);
    });
  }

  /// Open: navigate to the manga/anime detail page
  void _openDownload(Download element, BuildContext context) {
    final manga = element.chapter.value?.manga.value;
    if (manga?.id == null) return;
    Navigator.of(context).pushNamed(
      '/manga-detail',
      arguments: manga,
    );
  }

  void _retryDownload(
    Download element,
    WidgetRef ref,
    BuildContext context,
  ) {
    if (element.chapter.value != null) {
      final id = element.id ?? -1;
      ref.read(downloadQueueStateProvider.notifier).incrementRetry(id);
      // Remove paused state if set
      ref.read(downloadQueueStateProvider.notifier).setPaused(id, false);
      // Cancel old engine/task
      ActiveDownloadRegistry.cancel(id);
      DownloadIsolatePool.instance.cancelTask('$id');
      DownloadIsolatePool.instance.cancelTask('m3u8_$id');
      // Reset progress in Isar
      isar.writeTxnSync(() {
        final dl = isar.downloads.getSync(id);
        if (dl != null) {
          isar.downloads.putSync(dl
            ..succeeded = 0
            ..failed = 0
            ..total = 100
            ..isDownload = false);
        }
      });
      ref.read(processDownloadsProvider());
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Tab Badge
// ──────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Download Tab List
// ──────────────────────────────────────────────────────────────

class _DownloadTabList extends StatelessWidget {
  final List<Download> entries;
  final List<Download> allEntries;
  final IconData emptyIcon;
  final String emptyLabel;
  final DownloadQueueStateData queueState;
  final SwipeAction swipeLeft;
  final SwipeAction swipeRight;
  final void Function(Download) onPauseResume;
  final void Function(Download) onCancel;
  final void Function(Download) onDelete;
  final void Function(Download) onRetry;
  final void Function(Download) onOpen;

  const _DownloadTabList({
    required this.entries,
    required this.allEntries,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.queueState,
    required this.swipeLeft,
    required this.swipeRight,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outlineVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GroupedListView<Download, String>(
      elements: entries,
      groupBy: (element) => element.chapter.value?.manga.value?.source ?? "",
      groupSeparatorBuilder: (String groupByValue) {
        final sourceQueueLength = entries
            .where((element) =>
                (element.chapter.value?.manga.value?.source ?? "") ==
                groupByValue)
            .length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(
            '$groupByValue ($sourceQueueLength)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
      itemBuilder: (context, Download element) {
        final isPaused = queueState.pausedIds.contains(element.id ?? -1);
        final itemType = element.chapter.value?.manga.value?.itemType;
        final defaultEngineBadge = itemType == ItemType.manga
            ? 'ATLAS'
            : itemType == ItemType.novel
                ? 'HERMES'
                : 'HYDRA';
        final engine = queueState.engineMap[element.id ?? -1] ?? defaultEngineBadge;
        final retryCount = queueState.retryCounts[element.id ?? -1] ?? 0;

        return _DownloadCard(
          download: element,
          isPaused: isPaused,
          engine: engine,
          retryCount: retryCount,
          swipeLeftAction: swipeLeft,
          swipeRightAction: swipeRight,
          onPauseResume: () => onPauseResume(element),
          onCancel: () => onCancel(element),
          onDelete: () => onDelete(element),
          onRetry: () => onRetry(element),
          onOpen: () => onOpen(element),
          entries: allEntries,
        );
      },
      itemComparator: (item1, item2) =>
          (item1.chapter.value?.manga.value?.source ?? "").compareTo(
        item2.chapter.value?.manga.value?.source ?? "",
      ),
      order: GroupedListOrder.DESC,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Download Card — with cover + progressive swipe
// ──────────────────────────────────────────────────────────────

class _DownloadCard extends ConsumerWidget {
  final Download download;
  final bool isPaused;
  final String engine;
  final int retryCount;
  final SwipeAction swipeLeftAction;
  final SwipeAction swipeRightAction;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final List<Download> entries;

  const _DownloadCard({
    required this.download,
    required this.isPaused,
    required this.engine,
    required this.retryCount,
    required this.swipeLeftAction,
    required this.swipeRightAction,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onRetry,
    required this.onOpen,
    required this.entries,
  });

  void _executeAction(SwipeAction action) {
    switch (action) {
      case SwipeAction.pauseResume:
        onPauseResume();
        break;
      case SwipeAction.cancel:
        onCancel();
        break;
      case SwipeAction.delete:
        onDelete();
        break;
      case SwipeAction.retry:
        onRetry();
        break;
      case SwipeAction.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manga = download.chapter.value?.manga.value;
    final chapter = download.chapter.value;
    final scheme = Theme.of(context).colorScheme;
    final cardButtons = ref.watch(cardButtonsStateProvider);
    final itemType = manga?.itemType ?? ItemType.manga;

    // Progress calculation
    final succeeded = download.succeeded ?? 0;
    final total = download.total ?? 100;
    final failed = download.failed ?? 0;
    final progress = total > 0 ? succeeded / total : 0.0;

    // Progress label — varies by type
    final String progressLabel = _buildProgressLabel(itemType, succeeded, total, failed);

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // ── Cover image (left) ──
          _CoverThumbnail(
            imageUrl: manga?.imageUrl,
            customBytes: manga?.customCoverImage?.cast<int>(),
            itemType: itemType,
          ),
          const SizedBox(width: 10),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + badges
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        manga?.name ?? "",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _EngineBadge(engine: engine, scheme: scheme),
                    if (isPaused) ...[
                      const SizedBox(width: 4),
                      _PausedBadge(),
                    ],
                    if (failed > 0) ...[
                      const SizedBox(width: 4),
                      _FailedBadge(count: failed),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chapter?.name ?? "",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (retryCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Retry #$retryCount',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade400),
                  ),
                ],
                const SizedBox(height: 6),
                // Progress bar + label
                _ProgressRow(
                  progress: progress.clamp(0.0, 1.0),
                  label: progressLabel,
                  isPaused: isPaused,
                  scheme: scheme,
                ),
              ],
            ),
          ),

          // ── Action buttons ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cardButtons.contains(CardButton.pauseResume))
                _IconBtn(
                  icon: isPaused ? Icons.play_arrow : Icons.pause,
                  tooltip: isPaused ? 'Reprendre' : 'Pause',
                  color: Colors.orange,
                  onTap: onPauseResume,
                ),
              if (cardButtons.contains(CardButton.retry))
                _IconBtn(
                  icon: Icons.replay,
                  tooltip: 'Réessayer',
                  color: scheme.primary,
                  onTap: onRetry,
                ),
              if (cardButtons.contains(CardButton.cancel))
                _IconBtn(
                  icon: Icons.close,
                  tooltip: 'Annuler',
                  color: scheme.error,
                  onTap: onCancel,
                ),
              if (cardButtons.contains(CardButton.delete))
                _IconBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Supprimer',
                  color: scheme.error,
                  onTap: onDelete,
                ),
            ],
          ),
        ],
      ),
    );

    // Wrap in progressive swipe
    card = _ProgressiveSwipeable(
      key: Key('dl_swipe_${download.id}'),
      isPaused: isPaused,
      onPauseResume: onPauseResume,
      onCancel: onCancel,
      onDelete: onDelete,
      onOpen: onOpen,
      child: card,
    );

    return card;
  }

  String _buildProgressLabel(ItemType itemType, int succeeded, int total, int failed) {
    switch (itemType) {
      case ItemType.manga:
        // Show X/Y images
        if (total > 1 && total != 100) {
          return '$succeeded / $total images';
        }
        return '${(succeeded.toDouble() / math.max(total, 1) * 100).toStringAsFixed(0)}%';
      case ItemType.anime:
        // Show MB/GB file size based progress if we have real size info
        // succeeded = downloaded bytes in KB, total = total bytes in KB when > 1000
        if (total > 1000) {
          return '${_formatSize(succeeded)} / ${_formatSize(total)}';
        }
        return '${(succeeded.toDouble() / math.max(total, 1) * 100).toStringAsFixed(0)}%';
      case ItemType.novel:
      case ItemType.music:
      case ItemType.game:
        return '${(succeeded.toDouble() / math.max(total, 1) * 100).toStringAsFixed(0)}%';
    }
  }

  String _formatSize(int kb) {
    if (kb >= 1024 * 1024) {
      return '${(kb / (1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '$kb KB';
  }
}

// ──────────────────────────────────────────────────────────────
// Cover Thumbnail widget
// ──────────────────────────────────────────────────────────────

class _CoverThumbnail extends StatelessWidget {
  final String? imageUrl;
  final List<dynamic>? customBytes;
  final ItemType itemType;

  const _CoverThumbnail({
    required this.imageUrl,
    required this.customBytes,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        itemType == ItemType.anime
            ? Icons.play_circle_outline
            : itemType == ItemType.novel
                ? Icons.auto_stories_outlined
                : Icons.menu_book_outlined,
        color: scheme.onSurfaceVariant.withOpacity(0.4),
        size: 22,
      ),
    );

    if (customBytes != null && customBytes!.isNotEmpty) {
      try {
        final bytes = Uint8List.fromList(customBytes!.cast<int>());
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: 46,
            height: 62,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      } catch (_) {}
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: cachedNetworkImage(
          imageUrl: imageUrl!,
          width: 46,
          height: 62,
          fit: BoxFit.cover,
          errorWidget: placeholder,
        ),
      );
    }

    return placeholder;
  }
}

// ──────────────────────────────────────────────────────────────
// Progress Row
// ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final double progress;
  final String label;
  final bool isPaused;
  final ColorScheme scheme;

  const _ProgressRow({
    required this.progress,
    required this.label,
    required this.isPaused,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: scheme.outlineVariant.withOpacity(0.3),
                color: isPaused ? Colors.orange : scheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isPaused ? Colors.orange : scheme.onSurfaceVariant,
            fontWeight: isPaused ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Engine Badge
// ──────────────────────────────────────────────────────────────

class _EngineBadge extends StatelessWidget {
  final String engine;
  final ColorScheme scheme;

  const _EngineBadge({required this.engine, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final color = engine == 'ZEUS' || engine == 'ZDL'
        ? Colors.purple
        : engine == 'ARES'
            ? Colors.teal
            : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        engine,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: engine == 'ZEUS' || engine == 'ZDL'
              ? Colors.purple.shade300
              : engine == 'ARES'
                  ? Colors.teal.shade300
                  : scheme.primary,
        ),
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PAUSED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.orange,
        ),
      ),
    );
  }
}

class _FailedBadge extends StatelessWidget {
  final int count;
  const _FailedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '✗ $count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.red,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Small icon button helper
// ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color.withOpacity(0.8)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _ProgressiveSwipeable — rewrote to fix:
//   • Both sides appearing simultaneously (was a hit-test conflict)
//   • Actions not triggering (GestureDetector inside drag GestureDetector)
//   • Overflow beyond card bounds
//
// Design:
//   Swipe RIGHT  →  reveals LEFT actions: [Pause/Resume] [Annuler]
//   Swipe LEFT   →  reveals RIGHT actions: [Ouvrir] [Supprimer]
//
// The card snaps to fully-open (max reveal) or closed on drag end.
// Each action button is an independent InkWell — no nested
// GestureDetector competing with the drag recognizer.
// ──────────────────────────────────────────────────────────────

class _ProgressiveSwipeable extends StatefulWidget {
  final Widget child;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _ProgressiveSwipeable({
    super.key,
    required this.child,
    required this.isPaused,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  State<_ProgressiveSwipeable> createState() => _ProgressiveSwipeableState();
}

class _ProgressiveSwipeableState extends State<_ProgressiveSwipeable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late Animation<double> _slide;

  // +1 = left panel open, -1 = right panel open, 0 = closed
  int _direction = 0;

  // Width of a single action button
  static const double _btnW = 72.0;
  // Total width revealed for each side
  static const double _leftMax = _btnW * 2;  // pause + cancel
  static const double _rightMax = _btnW * 2; // open + delete
  // Drag distance needed to snap open
  static const double _snapThreshold = 48.0;

  double _rawDelta = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _rawDelta = 0;
    _anim.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _rawDelta += d.delta.dx;
    // Only allow dragging in one direction per gesture
    if (_direction == 0) {
      if (_rawDelta > 6) _direction = 1;
      if (_rawDelta < -6) _direction = -1;
    }
    if (_direction == 0) return;

    final max = _direction == 1 ? _leftMax : _rightMax;
    final clamped = (_rawDelta * _direction).clamp(0.0, max + 16);
    _slide = AlwaysStoppedAnimation(clamped * _direction);
    if (mounted) setState(() {});
  }

  void _onDragEnd(DragEndDetails d) {
    final absVal = _rawDelta.abs();
    final snapTo = absVal > _snapThreshold
        ? (_direction == 1 ? _leftMax : -_rightMax)
        : 0.0;

    final from = _slide.value;
    _slide = Tween<double>(begin: from, end: snapTo).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0).then((_) {
      if (snapTo == 0) _direction = 0;
    });
  }

  void _close() {
    final from = _slide.value;
    _slide = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0).then((_) => _direction = 0);
  }

  void _tap(VoidCallback cb) {
    _close();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final offset = _slide.value;
        final leftReveal = offset > 0 ? offset.clamp(0.0, _leftMax) : 0.0;
        final rightReveal = offset < 0 ? (-offset).clamp(0.0, _rightMax) : 0.0;

        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: ClipRect(
            child: Stack(
              children: [
                // ── Left action panel (swipe right) ─────────────────
                if (leftReveal > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: leftReveal,
                        child: Row(
                          children: [
                            // Pause / Resume
                            Expanded(
                              child: _SwipeActionItem(
                                icon: widget.isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                label: widget.isPaused ? 'Reprendre' : 'Pause',
                                color: Colors.orange.shade700,
                                onTap: () => _tap(widget.onPauseResume),
                              ),
                            ),
                            // Cancel — only shown once first button fully visible
                            if (leftReveal >= _btnW * 0.85)
                              Expanded(
                                child: _SwipeActionItem(
                                  icon: Icons.close_rounded,
                                  label: 'Annuler',
                                  color: Colors.red.shade700,
                                  onTap: () => _tap(widget.onCancel),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Right action panel (swipe left) ──────────────────
                if (rightReveal > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: rightReveal,
                        child: Row(
                          children: [
                            // Open — only shown once delete button fully visible
                            if (rightReveal >= _btnW * 0.85)
                              Expanded(
                                child: _SwipeActionItem(
                                  icon: Icons.folder_open_outlined,
                                  label: 'Ouvrir',
                                  color: scheme.primary,
                                  onTap: () => _tap(widget.onOpen),
                                ),
                              ),
                            // Delete
                            Expanded(
                              child: _SwipeActionItem(
                                icon: Icons.delete_outline_rounded,
                                label: 'Supprimer',
                                color: Colors.red.shade900,
                                onTap: () => _tap(widget.onDelete),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Main card — slides with drag ──────────────────────
                Transform.translate(
                  offset: Offset(offset.clamp(-_rightMax, _leftMax), 0),
                  child: widget.child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwipeActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SwipeActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Pause / Resume All FAB
// ──────────────────────────────────────────────────────────────

class _PauseResumeAllFab extends ConsumerWidget {
  final List<Download> entries;
  final DownloadQueueStateData queueState;

  const _PauseResumeAllFab({
    required this.entries,
    required this.queueState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIds =
        entries.map((e) => e.id ?? -1).where((id) => id != -1).toList();
    final allPaused = activeIds.isNotEmpty &&
        activeIds.every((id) => queueState.pausedIds.contains(id));
    final anyActive = activeIds.any((id) => !queueState.pausedIds.contains(id));

    if (entries.isEmpty) return const SizedBox.shrink();

    if (allPaused) {
      return FloatingActionButton(
        tooltip: 'Reprendre tout',
        onPressed: () {
          ref.read(downloadQueueStateProvider.notifier).resumeAll();
          ref.invalidate(processDownloadsProvider);
          ref.read(processDownloadsProvider());
        },
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.play_arrow_rounded),
      );
    } else if (anyActive) {
      return FloatingActionButton(
        tooltip: 'Tout mettre en pause',
        onPressed: () {
          ref
              .read(downloadQueueStateProvider.notifier)
              .pauseAll(activeIds);
        },
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.pause_rounded),
      );
    }

    return const SizedBox.shrink();
  }
}

enum _GlobalAction {
  pauseAll,
  resumeAll,
  stopAll,
  deleteCompleted,
  retryFailed,
}
