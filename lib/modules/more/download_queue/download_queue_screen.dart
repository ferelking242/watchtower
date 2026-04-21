import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/global_style.dart';

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

        // Clean orphaned downloads
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
            .where(
              (d) =>
                  d.chapter.value?.manga.value?.itemType == ItemType.anime,
            )
            .toList();
        final mangaEntries = entries
            .where(
              (d) =>
                  d.chapter.value?.manga.value?.itemType == ItemType.manga,
            )
            .toList();
        final novelEntries = entries
            .where(
              (d) =>
                  d.chapter.value?.manga.value?.itemType == ItemType.novel,
            )
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
              PopupMenuButton<_GlobalAction>(
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
                onPauseResume: (e) {
                  final wasPaused = queueState.pausedIds.contains(e.id ?? -1);
                  ref
                      .read(downloadQueueStateProvider.notifier)
                      .togglePause(e.id ?? -1);
                  // If was paused → now resuming: re-trigger internal engines
                  if (wasPaused) { ref.invalidate(processDownloadsProvider); ref.read(processDownloadsProvider()); }
                },
                onCancel: (e) => _cancelDownload(e, context),
                onDelete: (e) => _deleteDownload(e, context),
                onRetry: (e) => _retryDownload(e, ref, context),
              ),
              _DownloadTabList(
                entries: mangaEntries,
                allEntries: entries,
                emptyIcon: Icons.menu_book_outlined,
                emptyLabel: 'Aucun téléchargement Manga',
                queueState: queueState,
                swipeLeft: swipeLeft,
                swipeRight: swipeRight,
                onPauseResume: (e) {
                  final wasPaused = queueState.pausedIds.contains(e.id ?? -1);
                  ref
                      .read(downloadQueueStateProvider.notifier)
                      .togglePause(e.id ?? -1);
                  if (wasPaused) { ref.invalidate(processDownloadsProvider); ref.read(processDownloadsProvider()); }
                },
                onCancel: (e) => _cancelDownload(e, context),
                onDelete: (e) => _deleteDownload(e, context),
                onRetry: (e) => _retryDownload(e, ref, context),
              ),
              _DownloadTabList(
                entries: novelEntries,
                allEntries: entries,
                emptyIcon: Icons.auto_stories_outlined,
                emptyLabel: 'Aucun téléchargement Novel',
                queueState: queueState,
                swipeLeft: swipeLeft,
                swipeRight: swipeRight,
                onPauseResume: (e) {
                  final wasPaused = queueState.pausedIds.contains(e.id ?? -1);
                  ref
                      .read(downloadQueueStateProvider.notifier)
                      .togglePause(e.id ?? -1);
                  if (wasPaused) { ref.invalidate(processDownloadsProvider); ref.read(processDownloadsProvider()); }
                },
                onCancel: (e) => _cancelDownload(e, context),
                onDelete: (e) => _deleteDownload(e, context),
                onRetry: (e) => _retryDownload(e, ref, context),
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
        // Re-trigger for internal engines (ZeusDL uses SIGCONT, internal needs re-queue)
        ref.read(processDownloadsProvider());
        break;
      case _GlobalAction.stopAll:
        for (final e in entries) {
          if (e.chapter.value != null) {
            e.chapter.value!.cancelDownloads(e.id!);
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
            ref
                .read(downloadQueueStateProvider.notifier)
                .incrementRetry(e.id ?? -1);
            ref.read(
              downloadChapterProvider(chapter: e.chapter.value!),
            );
          }
        }
        break;
    }
  }

  void _cancelDownload(Download element, BuildContext context) {
    if (element.chapter.value != null) {
      element.chapter.value!.cancelDownloads(element.id!);
    } else {
      isar.writeTxnSync(() => isar.downloads.deleteSync(element.id!));
    }
  }

  void _deleteDownload(Download element, BuildContext context) {
    isar.writeTxnSync(() {
      if (element.id != null) isar.downloads.deleteSync(element.id!);
    });
  }

  void _retryDownload(
    Download element,
    WidgetRef ref,
    BuildContext context,
  ) {
    if (element.chapter.value != null) {
      ref
          .read(downloadQueueStateProvider.notifier)
          .incrementRetry(element.id ?? -1);
      // Delete old record and re-queue
      isar.writeTxnSync(() {
        if (element.id != null) isar.downloads.deleteSync(element.id!);
      });
      ref.read(
        addDownloadToQueueProvider(chapter: element.chapter.value!),
      );
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
            .where(
              (element) =>
                  (element.chapter.value?.manga.value?.source ?? "") ==
                  groupByValue,
            )
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
            ? 'IMG'
            : itemType == ItemType.novel
                ? 'HTML'
                : 'HLS';
        final engine =
            queueState.engineMap[element.id ?? -1] ?? defaultEngineBadge;
        final retryCount = queueState.retryCounts[element.id ?? -1] ?? 0;
        final progress = element.total != null && element.total! > 0
            ? (element.succeeded ?? 0) / element.total!
            : 0.0;

        return _DownloadCard(
          download: element,
          isPaused: isPaused,
          engine: engine,
          retryCount: retryCount,
          progress: progress,
          swipeLeftAction: swipeLeft,
          swipeRightAction: swipeRight,
          onPauseResume: () => onPauseResume(element),
          onCancel: () => onCancel(element),
          onDelete: () => onDelete(element),
          onRetry: () => onRetry(element),
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
// Download Card with swipe actions
// ──────────────────────────────────────────────────────────────

class _DownloadCard extends ConsumerWidget {
  final Download download;
  final bool isPaused;
  final String engine;
  final int retryCount;
  final double progress;
  final SwipeAction swipeLeftAction;
  final SwipeAction swipeRightAction;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onRetry;
  final List<Download> entries;

  const _DownloadCard({
    required this.download,
    required this.isPaused,
    required this.engine,
    required this.retryCount,
    required this.progress,
    required this.swipeLeftAction,
    required this.swipeRightAction,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onRetry,
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

  Widget _buildSwipeBackground(
    SwipeAction action,
    Alignment alignment,
    BuildContext context,
  ) {
    if (action == SwipeAction.none) return const SizedBox.shrink();
    final color = _actionColor(action, context);
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_actionIcon(action), color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            action.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(SwipeAction action, BuildContext context) {
    switch (action) {
      case SwipeAction.pauseResume:
        return Colors.orange.shade700;
      case SwipeAction.cancel:
        return Colors.red.shade700;
      case SwipeAction.delete:
        return Colors.red.shade900;
      case SwipeAction.retry:
        return Theme.of(context).colorScheme.primary;
      case SwipeAction.none:
        return Colors.transparent;
    }
  }

  IconData _actionIcon(SwipeAction action) {
    switch (action) {
      case SwipeAction.pauseResume:
        return isPaused ? Icons.play_arrow : Icons.pause;
      case SwipeAction.cancel:
        return Icons.close;
      case SwipeAction.delete:
        return Icons.delete_outline;
      case SwipeAction.retry:
        return Icons.replay;
      case SwipeAction.none:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manga = download.chapter.value?.manga.value;
    final chapter = download.chapter.value;
    final scheme = Theme.of(context).colorScheme;
    final cardButtons = ref.watch(cardButtonsStateProvider);

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    const SizedBox(width: 8),
                    // Engine badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: engine == 'ZDL'
                            ? Colors.purple.withOpacity(0.15)
                            : scheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        engine,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: engine == 'ZDL'
                              ? Colors.purple.shade300
                              : scheme.primary,
                        ),
                      ),
                    ),
                    if (isPaused) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chapter?.name ?? "",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (retryCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Retry #$retryCount',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade400,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(begin: 0, end: progress),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor:
                                scheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons (dynamically shown based on settings)
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

    // Wrap in swipe actions (Dismissible handles left/right)
    if (swipeLeftAction != SwipeAction.none ||
        swipeRightAction != SwipeAction.none) {
      card = _Swipeable(
        key: Key('dl_swipe_${download.id}'),
        onSwipeLeft: swipeLeftAction != SwipeAction.none
            ? () => _executeAction(swipeLeftAction)
            : null,
        onSwipeRight: swipeRightAction != SwipeAction.none
            ? () => _executeAction(swipeRightAction)
            : null,
        leftBackground: _buildSwipeBackground(
          swipeLeftAction,
          Alignment.centerLeft,
          context,
        ),
        rightBackground: _buildSwipeBackground(
          swipeRightAction,
          Alignment.centerRight,
          context,
        ),
        child: card,
      );
    }

    return card;
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
// Swipeable wrapper — handles left/right gesture detection
// ──────────────────────────────────────────────────────────────

class _Swipeable extends StatefulWidget {
  final Widget child;
  final Widget leftBackground;
  final Widget rightBackground;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const _Swipeable({
    super.key,
    required this.child,
    required this.leftBackground,
    required this.rightBackground,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<_Swipeable> createState() => _SwipeableState();
}

class _SwipeableState extends State<_Swipeable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  double _dragStart = 0;
  double _currentDx = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _dragStart = d.globalPosition.dx;
    _currentDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.globalPosition.dx - _dragStart;
    setState(() => _currentDx = dx);
  }

  void _onDragEnd(DragEndDetails d) {
    final threshold = 100.0;
    if (_currentDx > threshold && widget.onSwipeRight != null) {
      widget.onSwipeRight!();
    } else if (_currentDx < -threshold && widget.onSwipeLeft != null) {
      widget.onSwipeLeft!();
    }
    setState(() => _currentDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final dx = _currentDx.clamp(-120.0, 120.0);
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          if (dx > 0)
            Positioned.fill(child: widget.leftBackground),
          if (dx < 0)
            Positioned.fill(child: widget.rightBackground),
          Transform.translate(
            offset: Offset(dx, 0),
            child: widget.child,
          ),
        ],
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
      // Show Resume All — invalidate provider first so internal HLS
      // downloads (which were cancelled at pause) actually re-spin up.
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
      // Show Pause All
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
