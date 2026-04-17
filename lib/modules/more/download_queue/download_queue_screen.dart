import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/global_style.dart';

class DownloadQueueScreen extends ConsumerWidget {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        final orphanIds = <int>[];
        final entries = <Download>[];
        for (final d in allEntries) {
          if (d.chapter.value == null || d.chapter.value?.manga.value == null) {
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

        if (entries.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n!.download_queue)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_outlined, size: 64,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(l10n.no_downloads,
                      style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
                ],
              ),
            ),
          );
        }

        final allQueueLength = entries.length;
        final hasAnyPaused = queueState.pausedIds.isNotEmpty;
        final allPaused = entries.every((e) => queueState.pausedIds.contains(e.id ?? -1));

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(l10n!.download_queue),
                const SizedBox(width: 8),
                Badge(
                  backgroundColor: Theme.of(context).focusColor,
                  label: Text(allQueueLength.toString(),
                      style: TextStyle(fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                ),
              ],
            ),
            actions: [
              _PopupMenuAnchor(
                entries: entries,
                ref: ref,
                context: context,
              ),
            ],
          ),
          body: GroupedListView<Download, String>(
            elements: entries,
            groupBy: (element) => element.chapter.value?.manga.value?.source ?? "",
            groupSeparatorBuilder: (String groupByValue) {
              final sourceQueueLength = entries
                  .where((e) => (e.chapter.value?.manga.value?.source ?? "") == groupByValue)
                  .length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Text('$groupByValue ($sourceQueueLength)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              );
            },
            itemBuilder: (context, Download element) {
              final isPaused = queueState.pausedIds.contains(element.id ?? -1);
              final engine = queueState.engineMap[element.id ?? -1] ?? 'FK';
              final retryCount = queueState.retryCounts[element.id ?? -1] ?? 0;
              final hasFailed = (element.failed ?? 0) > 0;
              final progress = element.total != null && element.total! > 0
                  ? (element.succeeded ?? 0) / element.total!
                  : 0.0;

              return _DownloadCard(
                download: element,
                isPaused: isPaused,
                engine: engine,
                retryCount: retryCount,
                hasFailed: hasFailed,
                progress: progress,
                swipeLeftAction: swipeLeft,
                swipeRightAction: swipeRight,
                onPauseResume: () => ref
                    .read(downloadQueueStateProvider.notifier)
                    .togglePause(element.id ?? -1),
                onCancel: () => _cancelDownload(element, context),
                onRetry: () => _retryDownload(element, ref, context),
                entries: entries,
              );
            },
            itemComparator: (item1, item2) =>
                (item1.chapter.value?.manga.value?.source ?? "")
                    .compareTo(item2.chapter.value?.manga.value?.source ?? ""),
            order: GroupedListOrder.DESC,
          ),
          // FAB: pause all / resume all toggle
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (allPaused || !hasAnyPaused) {
                if (allPaused) {
                  ref.read(downloadQueueStateProvider.notifier).resumeAll();
                } else {
                  final ids = entries.map((e) => e.id ?? -1).toList();
                  ref.read(downloadQueueStateProvider.notifier).pauseAll(ids);
                }
              } else {
                // Some paused, some running → resume all
                ref.read(downloadQueueStateProvider.notifier).resumeAll();
              }
            },
            icon: Icon(allPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(allPaused ? 'Resume All' : 'Pause All'),
            backgroundColor: allPaused
                ? Theme.of(context).colorScheme.primary
                : Colors.orange.shade700,
          ),
        );
      },
    );
  }

  void _cancelDownload(Download element, BuildContext context) {
    if (element.chapter.value != null) {
      element.chapter.value!.cancelDownloads(element.id!);
    } else {
      isar.writeTxnSync(() => isar.downloads.deleteSync(element.id!));
    }
  }

  void _retryDownload(Download element, WidgetRef ref, BuildContext context) {
    if (element.chapter.value != null) {
      ref.read(downloadQueueStateProvider.notifier).incrementRetry(element.id ?? -1);
      isar.writeTxnSync(() {
        if (element.id != null) isar.downloads.deleteSync(element.id!);
      });
      ref.read(addDownloadToQueueProvider(chapter: element.chapter.value!));
      ref.read(processDownloadsProvider());
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Popup menu anchored below the 3-dot icon with triangle indicator
// ──────────────────────────────────────────────────────────────

class _PopupMenuAnchor extends StatefulWidget {
  final List<Download> entries;
  final WidgetRef ref;
  final BuildContext context;

  const _PopupMenuAnchor({
    required this.entries,
    required this.ref,
    required this.context,
  });

  @override
  State<_PopupMenuAnchor> createState() => _PopupMenuAnchorState();
}

class _PopupMenuAnchorState extends State<_PopupMenuAnchor> {
  final GlobalKey _key = GlobalKey();

  void _showMenu() {
    final RenderBox button = _key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonPos = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    showMenu<_GlobalAction>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      position: RelativeRect.fromLTRB(
        buttonPos.dx - 180,
        buttonPos.dy + buttonSize.height + 4,
        buttonPos.dx + buttonSize.width,
        0,
      ),
      items: [
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
    ).then((action) {
      if (action != null) _handleAction(action);
    });
  }

  void _handleAction(_GlobalAction action) {
    switch (action) {
      case _GlobalAction.pauseAll:
        final ids = widget.entries.map((e) => e.id ?? -1).toList();
        widget.ref.read(downloadQueueStateProvider.notifier).pauseAll(ids);
        break;
      case _GlobalAction.resumeAll:
        widget.ref.read(downloadQueueStateProvider.notifier).resumeAll();
        break;
      case _GlobalAction.stopAll:
        for (final e in widget.entries) {
          if (e.chapter.value != null) e.chapter.value!.cancelDownloads(e.id!);
        }
        break;
      case _GlobalAction.deleteCompleted:
        isar.writeTxnSync(() {
          final completed = isar.downloads.filter().isDownloadEqualTo(true).findAllSync();
          for (final d in completed) {
            if (d.id != null) isar.downloads.deleteSync(d.id!);
          }
        });
        break;
      case _GlobalAction.retryFailed:
        for (final e in widget.entries) {
          if ((e.failed ?? 0) > 0 && e.chapter.value != null) {
            widget.ref.read(downloadQueueStateProvider.notifier).incrementRetry(e.id ?? -1);
            widget.ref.read(downloadChapterProvider(chapter: e.chapter.value!));
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _key,
      icon: const Icon(Icons.more_vert),
      tooltip: 'More options',
      onPressed: _showMenu,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Download Card
// ──────────────────────────────────────────────────────────────

class _DownloadCard extends StatelessWidget {
  final Download download;
  final bool isPaused;
  final String engine;
  final int retryCount;
  final bool hasFailed;
  final double progress;
  final SwipeAction swipeLeftAction;
  final SwipeAction swipeRightAction;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final List<Download> entries;

  const _DownloadCard({
    required this.download,
    required this.isPaused,
    required this.engine,
    required this.retryCount,
    required this.hasFailed,
    required this.progress,
    required this.swipeLeftAction,
    required this.swipeRightAction,
    required this.onPauseResume,
    required this.onCancel,
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
        onCancel();
        break;
      case SwipeAction.retry:
        onRetry();
        break;
      case SwipeAction.none:
        break;
    }
  }

  Widget _buildSwipeBackground(SwipeAction action, Alignment alignment, BuildContext context) {
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
          Text(action.label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _actionColor(SwipeAction action, BuildContext context) {
    switch (action) {
      case SwipeAction.pauseResume:
        return Colors.orange.shade700;
      case SwipeAction.cancel:
      case SwipeAction.delete:
        return Colors.red.shade700;
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
  Widget build(BuildContext context) {
    final manga = download.chapter.value?.manga.value;
    final chapter = download.chapter.value;
    final scheme = Theme.of(context).colorScheme;

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3))),
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
                      child: Text(manga?.name ?? "",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    // Engine badge
                    _Badge(
                      label: engine,
                      color: engine == 'ZDL' ? Colors.purple : scheme.primary,
                    ),
                    if (isPaused) ...[
                      const SizedBox(width: 6),
                      const _Badge(label: 'PAUSED', color: Colors.orange),
                    ],
                    if (hasFailed) ...[
                      const SizedBox(width: 6),
                      const _Badge(label: 'FAILED', color: Colors.red),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(chapter?.name ?? "",
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (retryCount > 0) ...[
                  const SizedBox(height: 2),
                  Text('Retry #$retryCount',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade400)),
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
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: scheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons: only pause/resume + retry (conditional)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                tooltip: isPaused ? 'Resume' : 'Pause',
                color: Colors.orange,
                onTap: onPauseResume,
              ),
              if (hasFailed)
                _IconBtn(
                  icon: Icons.replay_rounded,
                  tooltip: 'Retry',
                  color: scheme.primary,
                  onTap: onRetry,
                ),
            ],
          ),
        ],
      ),
    );

    if (swipeLeftAction != SwipeAction.none || swipeRightAction != SwipeAction.none) {
      card = _Swipeable(
        key: Key('dl_swipe_${download.id}'),
        onSwipeLeft: swipeLeftAction != SwipeAction.none ? () => _executeAction(swipeLeftAction) : null,
        onSwipeRight: swipeRightAction != SwipeAction.none ? () => _executeAction(swipeRightAction) : null,
        leftBackground: _buildSwipeBackground(swipeLeftAction, Alignment.centerLeft, context),
        rightBackground: _buildSwipeBackground(swipeRightAction, Alignment.centerRight, context),
        child: card,
      );
    }

    return card;
  }
}

// ──────────────────────────────────────────────────────────────
// Small badge chip
// ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
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
// Swipeable wrapper
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

class _SwipeableState extends State<_Swipeable> {
  double _dragOffset = 0;
  static const double _threshold = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset < -_threshold && widget.onSwipeLeft != null) {
          widget.onSwipeLeft!();
        } else if (_dragOffset > _threshold && widget.onSwipeRight != null) {
          widget.onSwipeRight!();
        }
        setState(() => _dragOffset = 0);
      },
      child: Stack(
        children: [
          if (_dragOffset < 0) Positioned.fill(child: widget.leftBackground),
          if (_dragOffset > 0) Positioned.fill(child: widget.rightBackground),
          Transform.translate(
            offset: Offset(_dragOffset.clamp(-160, 160), 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Enum
// ──────────────────────────────────────────────────────────────

enum _GlobalAction { pauseAll, resumeAll, stopAll, deleteCompleted, retryFailed }
