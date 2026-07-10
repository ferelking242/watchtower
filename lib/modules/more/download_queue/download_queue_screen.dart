import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:watchtower/utils/extensions/chapter.dart';
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
    // Kick off any pending downloads that were left in queue
    // when the app was closed or the screen was dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(processDownloadsProvider());
    });
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

        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
            titleSpacing: 16,
            title: const Text(
              'Téléchargements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              // ── Gérer button ───────────────────────────────────────────
              GestureDetector(
                onTap: () => _showGererSheet(context, entries, ref),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.construction, color: scheme.onSecondaryContainer, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Gérer',
                        style: TextStyle(
                          color: scheme.onSecondaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/transfer'),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          color: scheme.primary, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Transfert',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: _buildChipTabBar(
                        watchCount: watchEntries.length,
                        mangaCount: mangaEntries.length,
                        novelCount: novelEntries.length,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: TabBarView(
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
              ),
            ],
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

  /// Open: directly launch the reader/player for the downloaded chapter
  void _openDownload(Download element, BuildContext context) {
    final chapter = element.chapter.value;
    if (chapter == null) return;
    chapter.pushToReaderView(context, ignoreIsRead: true);
  }

  void _retryDownload(
    Download element,
    WidgetRef ref,
    BuildContext context,
  ) {
    if (element.chapter.value != null) {
      final id = element.id ?? -1;
      ref.read(downloadQueueStateProvider.notifier).incrementRetry(id);
      ref.read(downloadQueueStateProvider.notifier).setPaused(id, false);
      ActiveDownloadRegistry.cancel(id);
      DownloadIsolatePool.instance.cancelTask('$id');
      DownloadIsolatePool.instance.cancelTask('m3u8_$id');
      isar.writeTxnSync(() {
        final dl = isar.downloads.getSync(id);
        if (dl != null) {
          isar.downloads.putSync(dl
            ..succeeded = 0
            ..failed = 0
            ..total = 1
            ..isDownload = false);
        }
      });
      ref.read(processDownloadsProvider());
    }
  }

  Widget _buildChipTabBar({
    required int watchCount,
    required int mangaCount,
    required int novelCount,
  }) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipTab(0, Icons.play_circle_outline, 'Watch', watchCount),
              const SizedBox(width: 8),
              _chipTab(1, Icons.menu_book_outlined, 'Manga', mangaCount),
              const SizedBox(width: 8),
              _chipTab(2, Icons.auto_stories_outlined, 'Novel', novelCount),
            ],
          ),
        );
      },
    );
  }

  Widget _chipTab(int index, IconData icon, String label, int count) {
    return Builder(builder: (context) {
      final anim = _tabController.animation;
      final selected = anim != null
          ? anim.value.round() == index
          : _tabController.index == index;
      final scheme = Theme.of(context).colorScheme;
      return GestureDetector(
        onTap: () => setState(() => _tabController.animateTo(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.onSurface.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? scheme.onSurface.withValues(alpha: 0.54)
                  : scheme.onSurface.withValues(alpha: 0.24),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.38)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  void _showGererSheet(
      BuildContext context, List<Download> entries, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GererSheet(entries: entries, parentRef: ref),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Gérer Sheet — rich settings bottom sheet
// ──────────────────────────────────────────────────────────────

class _GererSheet extends ConsumerStatefulWidget {
  final List<Download> entries;
  final WidgetRef parentRef;
  const _GererSheet({required this.entries, required this.parentRef});

  @override
  ConsumerState<_GererSheet> createState() => _GererSheetState();
}

class _GererSheetState extends ConsumerState<_GererSheet> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.entries;

    final watchTotal = ref.watch(watchSimultaneousStateProvider);
    final mangaTotal = ref.watch(mangaSimultaneousStateProvider);
    final novelTotal = ref.watch(novelSimultaneousStateProvider);
    final watchPerSrc = ref.watch(watchSimultaneousPerSourceStateProvider);
    final mangaPerSrc = ref.watch(mangaSimultaneousPerSourceStateProvider);
    final novelPerSrc = ref.watch(novelSimultaneousPerSourceStateProvider);
    final layout = ref.watch(downloadCardLayoutStateProvider);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // ── Drag handle ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Gérer les téléchargements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [

                  // ── Actions rapides ──────────────────────────────────────
                  _SheetSection(label: 'Actions rapides', scheme: scheme, icon: Icons.bolt_rounded, helpText: 'Agir sur toute la file d\'attente'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.play_arrow_rounded,
                        label: 'Lancer',
                        color: scheme.primary,
                        onTap: () {
                          Navigator.pop(context);
                          widget.parentRef.read(downloadQueueStateProvider.notifier).resumeAll();
                          widget.parentRef.read(processDownloadsProvider());
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.pause_rounded,
                        label: 'Pause',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          final ids = entries.map((e) => e.id ?? -1).toList();
                          widget.parentRef.read(downloadQueueStateProvider.notifier).pauseAll(ids);
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.stop_rounded,
                        label: 'Arrêter',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(context);
                          for (final e in entries) {
                            if (e.id != null) ActiveDownloadRegistry.cancel(e.id!);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.replay_rounded,
                        label: 'Réessayer',
                        color: scheme.secondary,
                        onTap: () {
                          Navigator.pop(context);
                          for (final e in entries) {
                            if ((e.failed ?? 0) > 0 && e.chapter.value != null) {
                              widget.parentRef.read(downloadQueueStateProvider.notifier).incrementRetry(e.id ?? -1);
                              widget.parentRef.read(downloadChapterProvider(chapter: e.chapter.value!));
                            }
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Simultanés par type ──────────────────────────────────
                  _SheetSection(label: 'Simultanés', scheme: scheme, icon: Icons.download_for_offline_outlined, helpText: 'Nombre de téléchargements parallèles par type et par source'),
                  const SizedBox(height: 10),

                  _SimultaneousRow(
                    icon: Icons.play_circle_outline,
                    label: 'Watch',
                    iconColor: scheme.primary,
                    total: watchTotal,
                    perSource: watchPerSrc,
                    maxTotal: 10,
                    maxPerSource: 5,
                    onTotalChanged: (v) => ref.read(watchSimultaneousStateProvider.notifier).set(v),
                    onPerSourceChanged: (v) => ref.read(watchSimultaneousPerSourceStateProvider.notifier).set(v),
                    scheme: scheme,
                  ),
                  const SizedBox(height: 8),
                  _SimultaneousRow(
                    icon: Icons.menu_book_outlined,
                    label: 'Manga',
                    iconColor: scheme.secondary,
                    total: mangaTotal,
                    perSource: mangaPerSrc,
                    maxTotal: 10,
                    maxPerSource: 5,
                    onTotalChanged: (v) => ref.read(mangaSimultaneousStateProvider.notifier).set(v),
                    onPerSourceChanged: (v) => ref.read(mangaSimultaneousPerSourceStateProvider.notifier).set(v),
                    scheme: scheme,
                  ),
                  const SizedBox(height: 8),
                  _SimultaneousRow(
                    icon: Icons.auto_stories_outlined,
                    label: 'Roman',
                    iconColor: scheme.tertiary,
                    total: novelTotal,
                    perSource: novelPerSrc,
                    maxTotal: 10,
                    maxPerSource: 5,
                    onTotalChanged: (v) => ref.read(novelSimultaneousStateProvider.notifier).set(v),
                    onPerSourceChanged: (v) => ref.read(novelSimultaneousPerSourceStateProvider.notifier).set(v),
                    scheme: scheme,
                  ),

                  const SizedBox(height: 20),

                  // ── Disposition des cartes ───────────────────────────────
                  _SheetSection(label: 'Disposition', scheme: scheme, icon: Icons.view_list_outlined, helpText: 'Densité d\'affichage des éléments de la file'),
                  const SizedBox(height: 10),
                  Row(
                    children: DownloadCardLayout.values.map((l) {
                      final selected = layout == l;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => ref.read(downloadCardLayoutStateProvider.notifier).set(l),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.15)
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(l.icon,
                                      size: 20,
                                      color: selected ? scheme.primary : scheme.onSurfaceVariant),
                                  const SizedBox(height: 4),
                                  Text(
                                    l.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Options ─────────────────────────────────────────────
                  const SizedBox(height: 4),
                  _OptionTile(
                    icon: Icons.cloud_sync_outlined,
                    label: 'Arrière-plan',
                    subtitle: 'Continuer même app fermée',
                    scheme: scheme,
                    onTap: () => botToast('Téléchargement en arrière-plan activé'),
                  ),
                  _OptionTile(
                    icon: Icons.delete_sweep_outlined,
                    label: 'Effacer les terminés',
                    subtitle: 'Retirer de la file les éléments finis',
                    scheme: scheme,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      isar.writeTxnSync(() {
                        final completed = isar.downloads
                            .filter()
                            .isDownloadEqualTo(true)
                            .findAllSync();
                        for (final d in completed) {
                          if (d.id != null) isar.downloads.deleteSync(d.id!);
                        }
                      });
                      botToast('Terminés supprimés de la file');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet helpers ──────────────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String label;
  final ColorScheme scheme;
  final IconData? icon;
  final String? helpText;
  const _SheetSection({
    required this.label,
    required this.scheme,
    this.icon,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 5),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
            letterSpacing: 0.9,
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(width: 5),
          Tooltip(
            message: helpText!,
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(Icons.help_outline_rounded, size: 13, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimultaneousRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final int total;
  final int perSource;
  final int maxTotal;
  final int maxPerSource;
  final ValueChanged<int> onTotalChanged;
  final ValueChanged<int> onPerSourceChanged;
  final ColorScheme scheme;

  const _SimultaneousRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.total,
    required this.perSource,
    required this.maxTotal,
    required this.maxPerSource,
    required this.onTotalChanged,
    required this.onPerSourceChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          _CounterField(
            label: 'Total',
            value: total,
            min: 1,
            max: maxTotal,
            onChanged: onTotalChanged,
            scheme: scheme,
            accentColor: iconColor,
            compact: true,
          ),
          const SizedBox(width: 8),
          _CounterField(
            label: 'Src',
            value: perSource,
            min: 1,
            max: maxPerSource,
            onChanged: onPerSourceChanged,
            scheme: scheme,
            accentColor: iconColor,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _CounterField extends StatelessWidget {
    final String label;
    final int value;
    final int min;
    final int max;
    final ValueChanged<int> onChanged;
    final ColorScheme scheme;
    final Color accentColor;
    final bool compact;

    const _CounterField({
      required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged,
      required this.scheme,
      required this.accentColor,
      this.compact = false,
    });

    @override
    Widget build(BuildContext context) {
      if (compact) {
        // Compact inline layout: label + [-] value [+]
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            _CircleBtn(
              icon: Icons.remove,
              enabled: value > min,
              color: accentColor,
              onTap: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 22,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            _CircleBtn(
              icon: Icons.add,
              enabled: value < max,
              color: accentColor,
              onTap: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CircleBtn(
                icon: Icons.remove,
                enabled: value > min,
                color: accentColor,
                onTap: value > min ? () => onChanged(value - 1) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              _CircleBtn(
                icon: Icons.add,
                enabled: value < max,
                color: accentColor,
                onTap: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ],
      );
    }
  }

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;
  const _CircleBtn({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? color : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.scheme,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color.withValues(alpha: isDestructive ? 1 : 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
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
              size: 60,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 14),
            Text(
              emptyLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final element = entries[index];
        final isPaused = queueState.pausedIds.contains(element.id ?? -1);
        final itemType = element.chapter.value?.manga.value?.itemType;
        final defaultEngineBadge = itemType == ItemType.manga
            ? 'ATLAS'
            : itemType == ItemType.novel
                ? 'HERMES'
                : 'HYDRA';
        final engine =
            queueState.engineMap[element.id ?? -1] ?? defaultEngineBadge;
        final retryCount =
            queueState.retryCounts[element.id ?? -1] ?? 0;

        return Dismissible(
          key: ValueKey('dl_' + (element.id ?? 0).toString()),
          direction: DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.30,
            DismissDirection.endToStart: 0.30,
          },
          background: Container(
            color: Colors.red.shade700,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 28),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 30),
                SizedBox(height: 4),
                Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          secondaryBackground: Builder(
            builder: (ctx) => Container(
              color: Colors.orange.shade700,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white, size: 30),
                  const SizedBox(height: 4),
                  Text(isPaused ? 'Reprendre' : 'Pause', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              onPauseResume(element);
              return false;
            }
            onDelete(element);
            return true;
          },
          child: _DownloadCard(
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
          ),
        );
      },
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
    final itemType = manga?.itemType ?? ItemType.manga;
    ref.watch(cardButtonsStateProvider);
    final layout = ref.watch(downloadCardLayoutStateProvider);

    // Progress calculation
    final succeeded = download.succeeded ?? 0;
    final total = download.total ?? 100;
    final failed = download.failed ?? 0;
    final progress = total > 0 ? succeeded / total : 0.0;
    final isComplete = download.isDownload ?? false;
    final hasFailed = failed > 0 && !isComplete;
    final isPaused = this.isPaused;

    final scheme = Theme.of(context).colorScheme;

    final String statusText = isComplete
        ? 'Terminé'
        : hasFailed
            ? 'Échec'
            : isPaused
                ? 'En pause'
                : progress > 0
                    ? 'En cours…'
                    : 'En attente';
    final Color statusColor = isComplete
        ? scheme.primary
        : hasFailed
            ? Colors.redAccent
            : isPaused
                ? Colors.orange
                : scheme.onSurface.withValues(alpha: 0.54);

    final Color actionColor = hasFailed ? Colors.redAccent : scheme.primary;

    // Progress bar — no TweenAnimationBuilder so progress never "resets to 0"
    // on each Isar stream rebuild (the regression bug). Direct value is correct.
    final progressBar = progress > 0 && !isComplete
        ? ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: layout == DownloadCardLayout.compact ? 2 : 4,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasFailed
                    ? Colors.redAccent
                    : isPaused
                        ? Colors.orange
                        : scheme.primary,
              ),
            ),
          )
        : null;

    final actionBtn = GestureDetector(
      onTap: hasFailed
          ? onRetry
          : isPaused
              ? onPauseResume
              : isComplete
                  ? onOpen
                  : onPauseResume,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: actionColor.withValues(alpha: 0.15),
          border: Border.all(color: actionColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Icon(
          isComplete
              ? Icons.folder_open_outlined
              : hasFailed
                  ? Icons.replay
                  : isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.download_rounded,
          color: actionColor,
          size: 16,
        ),
      ),
    );

    // ── Compact layout ──────────────────────────────────────────────────────
    if (layout == DownloadCardLayout.compact) {
      return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manga?.name ?? 'Inconnu',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        chapter?.name ?? '',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                actionBtn,
              ],
            ),
            if (progressBar != null) ...[
              const SizedBox(height: 4),
              progressBar,
            ],
          ],
        ),
      );
    }

    // ── Full / Étendu layout ────────────────────────────────────────────────
    if (layout == DownloadCardLayout.full) {
      return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Larger cover
            _CoverThumbnail(
              imageUrl: manga?.imageUrl,
              customBytes: manga?.customCoverImage?.cast<int>(),
              itemType: itemType,
              width: 60,
              height: 82,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga?.name ?? 'Inconnu',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapter?.name ?? '',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          engine,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete
                        ? 'Téléchargement terminé'
                        : _buildProgressLabel(itemType, succeeded, total, failed),
                    style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11),
                  ),
                  if (progressBar != null) ...[
                    const SizedBox(height: 6),
                    progressBar,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            actionBtn,
          ],
        ),
      );
    }

    // ── Standard layout (default) ───────────────────────────────────────────
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _CoverThumbnail(
            imageUrl: manga?.imageUrl,
            customBytes: manga?.customCoverImage?.cast<int>(),
            itemType: itemType,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  manga?.name ?? 'Inconnu',
                  style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  chapter?.name ?? '',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      isComplete
                          ? 'Terminé'
                          : _buildProgressLabel(itemType, succeeded, total, failed),
                      style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (progressBar != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: progressBar),
                      const SizedBox(width: 6),
                      actionBtn,
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: actionBtn),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildProgressLabel(ItemType itemType, int succeeded, int total, int failed) {
    switch (itemType) {
      case ItemType.manga:
        // Always show "X / Y images" — total is now the real page count,
        // never the synthetic 100 from the old code.
        if (total > 1) {
          return '$succeeded / $total images';
        }
        // Single-page edge case (shouldn't happen but guards against 0/0).
        return succeeded > 0 ? '1 / 1 image' : '0 / 1 image';
      case ItemType.anime:
        // Two sub-cases depending on what's stored in Isar:
        //
        // A) HLS/direct with real byte data → succeeded & total are in KB
        //    (always > 1024 for a real video file). Show "14 MB / 58 MB".
        //
        // B) Aria2 → store raw percent (0-100). Show "50%".
        //    These engines don't produce byte info; total stays ≤ 100.
        //
        // Threshold: KB values for real videos are almost always > 500 KB
        // (smallest real episode ≈ a few MB = thousands of KB). Using 500
        // as the cutoff correctly separates byte-mode (>500) from %-mode
        // (0-100) without any false positives.
        if (total > 500) {
          if (succeeded >= total) {
            return _formatSize(total);
          }
          return '${_formatSize(succeeded)} / ${_formatSize(total)}';
        }
        // Aria2 percentage mode or early tick before bytes arrive.
        if (total > 1) {
          return '${succeeded.clamp(0, total)}%';
        }
        return 'En attente…';
      case ItemType.novel:
      case ItemType.music:
      case ItemType.game:
        return '${(succeeded.toDouble() / math.max(total, 1) * 100).toStringAsFixed(0)}%';
    }
  }

  /// Format a KB value into a human-readable string (KB → MB → GB).
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
  final double width;
  final double height;

  const _CoverThumbnail({
    required this.imageUrl,
    required this.customBytes,
    required this.itemType,
    this.width = 46,
    this.height = 62,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = width;
    final h = height;
    final placeholder = Container(
      width: w,
      height: h,
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
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
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
            width: w,
            height: h,
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
          width: w,
          height: h,
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
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
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
    final color = engine == 'ARES'
        ? Colors.teal
        : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        engine,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: engine == 'ARES'
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
        color: Colors.orange.withValues(alpha: 0.15),
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
        color: Colors.red.withValues(alpha: 0.15),
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
          child: Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
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
