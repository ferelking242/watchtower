import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/widgets/base_library_tab_screen.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/history/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_main.dart'
    show MangaDetailArgs;
import 'package:watchtower/services/watch_resume_store.dart'
    show readWatchResume;
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';

// ââ Layout mode for the history list âââââââââââââââââââââââââââââââââââââââââ
enum _HistoryLayout { list, grid }

// ââ Sort mode ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
enum _HistorySort { date, title }

// ââ Filter mode ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
enum _HistoryFilter { all, today, thisWeek, thisMonth }

/// Opens a history entry.
///
/// For video entries (anime/music) we deliberately route through the regular
/// detail page (`/manga-reader/detail`) — the same flow used by the Watch
/// extension — instead of the bare `AnimePlayerView` page that
/// `pushToReaderView` used to open. That keeps a single player experience and
/// lets us resume the exact episode + timestamp. Other types keep the usual
/// reader behaviour.
Future<void> openHistoryEntry(BuildContext context, History element) async {
  final chapter = element.chapter.value!;
  final manga = chapter.manga.value!;
  final isVideo =
      manga.itemType == ItemType.anime || manga.itemType == ItemType.music;
  if (!isVideo) {
    await chapter.pushToReaderView(context);
    return;
  }
  final resume = manga.id == null
      ? null
      : await readWatchResume(manga.name ?? '', chapter.id!);
  if (!context.mounted) return;
  context.push(
    '/manga-reader/detail',
    extra: MangaDetailArgs(
      manga.id!,
      resumeChapterId: chapter.id,
      resumePosition:
          resume == null ? null : Duration(milliseconds: resume.ms),
    ),
  );
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends BaseLibraryTabScreenState<HistoryScreen> {
  _HistoryLayout _layout = _HistoryLayout.list;
  _HistorySort _sort = _HistorySort.date;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  String get title => l10nLocalizations(context)!.history;

  @override
  Widget buildTabLabel(ItemType type, String label) {
    IconData icon;
    switch (type) {
      case ItemType.anime:
        icon = Broken.video_play;
        break;
      case ItemType.manga:
        icon = Broken.note;
        break;
      case ItemType.novel:
        icon = Broken.book;
        break;
      case ItemType.music:
        icon = Broken.music_play;
        break;
      case ItemType.game:
        icon = Broken.gameboy;
        break;
      case ItemType.plugin:
        icon = Broken.element_plus;
        break;
    }
    return Tab(icon: Icon(icon, size: 18), text: label);
  }

  @override
  Widget buildTab(ItemType type) {
    return HistoryTab(
      itemType: type,
      query: textEditingController.text,
      layout: _layout,
      sort: _sort,
      filter: _filter,
    );
  }

  @override
  List<Widget> buildExtraActions(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      // Unified filter/sort/layout sheet
      IconButton(
        tooltip: 'Filtrer / Trier / Disposition',
        icon: Icon(
          Broken.filter,
          color: (_filter != _HistoryFilter.all || _sort != _HistorySort.date)
              ? Colors.yellow
              : Theme.of(context).hintColor,
        ),
        onPressed: () => _showFilterMenu(context),
      ),
      // Delete all
      IconButton(
        splashRadius: 20,
        icon: Icon(
          Broken.trash,
          color: Theme.of(context).hintColor,
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.remove_everything),
              content: Text(l10n.remove_everything_msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _clearHistory();
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  void _showFilterMenu(BuildContext context) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            void updateBoth(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
            }

            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 24),
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // DISPOSITION
                      Text(
                        'DISPOSITION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LayoutCard(
                              label: 'Liste',
                              icon: Broken.row_vertical,
                              selected: _layout == _HistoryLayout.list,
                              onTap: () => updateBoth(
                                  () => _layout = _HistoryLayout.list),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LayoutCard(
                              label: 'Grille',
                              icon: Broken.grid_2,
                              selected: _layout == _HistoryLayout.grid,
                              onTap: () => updateBoth(
                                  () => _layout = _HistoryLayout.grid),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // TRIER PAR
                      Text(
                        'TRIER PAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _SelectChip(
                            label: 'Date',
                            icon: Broken.clock,
                            selected: _sort == _HistorySort.date,
                            onTap: () =>
                                updateBoth(() => _sort = _HistorySort.date),
                          ),
                          const SizedBox(width: 8),
                          _SelectChip(
                            label: 'Titre',
                            icon: Broken.sort,
                            selected: _sort == _HistorySort.title,
                            onTap: () =>
                                updateBoth(() => _sort = _HistorySort.title),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // PERIODE
                      Text(
                        'PERIODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _SelectChip(
                              label: 'Tout',
                              icon: Broken.category,
                              selected: _filter == _HistoryFilter.all,
                              onTap: () => updateBoth(
                                  () => _filter = _HistoryFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _SelectChip(
                              label: "Aujourd'hui",
                              icon: Broken.calendar_tick,
                              selected: _filter == _HistoryFilter.today,
                              onTap: () => updateBoth(
                                  () => _filter = _HistoryFilter.today),
                            ),
                            const SizedBox(width: 8),
                            _SelectChip(
                              label: 'Cette semaine',
                              icon: Broken.calendar_2,
                              selected: _filter == _HistoryFilter.thisWeek,
                              onTap: () => updateBoth(
                                  () => _filter = _HistoryFilter.thisWeek),
                            ),
                            const SizedBox(width: 8),
                            _SelectChip(
                              label: 'Ce mois-ci',
                              icon: Broken.calendar,
                              selected: _filter == _HistoryFilter.thisMonth,
                              onTap: () => updateBoth(
                                  () => _filter = _HistoryFilter.thisMonth),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    Future<void> _clearHistory() async {
    final List<History> histories = await isar.historys
        .filter()
        .itemTypeEqualTo(getCurrentItemType())
        .findAll();
    final List<Id> idsToDelete = histories.map((h) => h.id!).toList();
    await isar.writeTxn(() => isar.historys.deleteAll(idsToDelete));
  }
}

// ââ History Tab âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class HistoryTab extends ConsumerStatefulWidget {
  final String query;
  final ItemType itemType;
  final _HistoryLayout layout;
  final _HistorySort sort;
  final _HistoryFilter filter;

  const HistoryTab({
    required this.itemType,
    required this.query,
    required this.layout,
    required this.sort,
    required this.filter,
    super.key,
  });

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = l10nLocalizations(context)!;
    final history = ref.watch(
      getAllHistoryStreamProvider(
        itemType: widget.itemType,
        search: widget.query,
      ),
    );
    return history.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Text(l10n.nothing_read_recently));
        }

        // Filter by date range
        final now = DateTime.now();
        List<History> filtered = entries.where((h) {
          if (widget.filter == _HistoryFilter.all) return true;
          final dateStr = h.date ?? '';
          if (dateStr.isEmpty) return false;
          try {
            final d = DateTime.parse(dateStr);
            switch (widget.filter) {
              case _HistoryFilter.today:
                return d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
              case _HistoryFilter.thisWeek:
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                final start = DateTime(
                    weekStart.year, weekStart.month, weekStart.day);
                return d.isAfter(start.subtract(const Duration(seconds: 1)));
              case _HistoryFilter.thisMonth:
                return d.year == now.year && d.month == now.month;
              case _HistoryFilter.all:
                return true;
            }
          } catch (_) {
            return true;
          }
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text(l10n.nothing_read_recently));
        }

        // Sort
        final sorted = filtered;
        if (widget.sort == _HistorySort.title) {
          sorted.sort((a, b) {
            final n1 = a.chapter.value?.manga.value?.name ?? '';
            final n2 = b.chapter.value?.manga.value?.name ?? '';
            return n1.compareTo(n2);
          });
        } else {
          sorted.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
        }

        if (widget.layout == _HistoryLayout.grid) {
          return _HistoryGrid(entries: sorted);
        }

        return CustomScrollView(
          slivers: [
            CustomSliverGroupedListView<History, String>(
              elements: sorted,
              groupBy: (element) => dateFormat(
                element.date!,
                context: context,
                ref: ref,
                forHistoryValue: true,
                useRelativeTimesTamps: false,
              ),
              groupSeparatorBuilder: (String groupByValue) => Padding(
                padding: const EdgeInsets.only(
                    bottom: 8, left: 12, top: 4, right: 12),
                child: Row(
                  children: [
                    Icon(
                      Broken.calendar,
                      size: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat(
                        null,
                        context: context,
                        stringDate: groupByValue,
                        ref: ref,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              itemBuilder: (context, History element) {
                return _HistoryListItem(
                  element: element,
                  onDelete: () =>
                      _openDeleteDialog(l10n, element.chapter.value!.manga.value!, element.id),
                );
              },
              itemComparator: (item1, item2) =>
                  item1.date!.compareTo(item2.date!),
              order: widget.sort == _HistorySort.title
                  ? GroupedListOrder.ASC
                  : GroupedListOrder.DESC,
            ),
          ],
        );
      },
      error: (Object error, StackTrace stackTrace) => ErrorText(error),
      loading: () => const ProgressCenter(),
    );
  }

  Widget _getCoverImage(Manga manga) {
    return manga.customCoverImage != null
        ? Image.memory(manga.customCoverImage as Uint8List)
        : cachedCompressedNetworkImage(
            headers: ref.watch(
              headersProvider(
                source: manga.source!,
                lang: manga.lang!,
                sourceId: manga.sourceId,
              ),
            ),
            imageUrl: toImgUrl(
              manga.customCoverFromTracker ?? manga.imageUrl ?? '',
            ),
            width: 60,
            height: 90,
            fit: BoxFit.cover,
          );
  }

  void _openDeleteDialog(AppLocalizations l10n, Manga manga, int? deleteId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.remove),
          content: Text(l10n.remove_history_msg),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 15),
                TextButton(
                  onPressed: () async => deleteManga(context, manga, deleteId),
                  child: Text(l10n.remove),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteManga(
    BuildContext context,
    Manga manga,
    int? deleteId,
  ) async {
    isar.writeTxnSync(() {
      isar.historys.deleteSync(deleteId!);
      ref
          .read(synchingProvider(syncId: 1).notifier)
          .addChangedPart(ActionType.removeHistory, deleteId, '{}', false);
    });
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}

// ââ List item âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _HistoryListItem extends ConsumerWidget {
  final History element;
  final VoidCallback onDelete;

  const _HistoryListItem({
    required this.element,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = element.chapter.value!;
    final manga = chapter.manga.value!;
    final cs = Theme.of(context).colorScheme;

    // Type badge
    IconData typeIcon;
    Color typeColor;
    switch (manga.itemType) {
      case ItemType.anime:
        typeIcon = Broken.video_play;
        typeColor = Colors.deepPurple;
        break;
      case ItemType.manga:
        typeIcon = Broken.note;
        typeColor = Colors.blue;
        break;
      case ItemType.novel:
        typeIcon = Broken.book;
        typeColor = Colors.green;
        break;
      case ItemType.music:
        typeIcon = Broken.music_play;
        typeColor = Colors.orange;
        break;
      case ItemType.game:
        typeIcon = Broken.gameboy;
        typeColor = Colors.red;
        break;
      case ItemType.plugin:
        typeIcon = Broken.element_plus;
        typeColor = Colors.teal;
        break;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      onPressed: () => _openEntry(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover
              GestureDetector(
                onTap: () => _openEntry(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 80,
                        child: _buildCover(manga, ref),
                      ),
                      // Type icon badge
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(typeIcon,
                              size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapter.name!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Broken.clock,
                            size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          dateFormatHour(element.date!, context),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete
              IconButton(
                onPressed: onDelete,
                icon: Icon(Broken.trash,
                    size: 22, color: cs.onSurfaceVariant),
                tooltip: 'Supprimer de l\'historique',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a history entry.
  ///
  /// For video entries (anime/music) we deliberately route through the
  /// regular detail page (`/manga-reader/detail`) — the same flow used by
  /// the Watch extension — instead of the bare `AnimePlayerView` page that
  /// `pushToReaderView` used to open. That keeps a single player experience
  /// and lets us resume the exact episode + timestamp. Other types keep the
  /// usual reader behaviour.
  Future<void> _openEntry(BuildContext context) =>
      openHistoryEntry(context, element);

  Widget _buildCover(Manga manga, WidgetRef ref) {
    if (manga.customCoverImage != null) {
      return Image.memory(
        manga.customCoverImage as Uint8List,
        fit: BoxFit.cover,
        width: 56,
        height: 80,
      );
    }
    return cachedCompressedNetworkImage(
      headers: ref.read(
        headersProvider(
          source: manga.source!,
          lang: manga.lang!,
          sourceId: manga.sourceId,
        ),
      ),
      imageUrl: toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? ''),
      width: 56,
      height: 80,
      fit: BoxFit.cover,
    );
  }
}

// ââ Grid view âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class _HistoryGrid extends ConsumerWidget {
  final List<History> entries;

  const _HistoryGrid({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final element = entries[i];
        final chapter = element.chapter.value!;
        final manga = chapter.manga.value!;
        final cs = Theme.of(context).colorScheme;

        IconData typeIcon;
        Color typeColor;
        switch (manga.itemType) {
          case ItemType.anime:
            typeIcon = Broken.video_play;
            typeColor = Colors.deepPurple;
            break;
          case ItemType.manga:
            typeIcon = Broken.note;
            typeColor = Colors.blue;
            break;
          case ItemType.novel:
            typeIcon = Broken.book;
            typeColor = Colors.green;
            break;
          case ItemType.music:
            typeIcon = Broken.music_play;
            typeColor = Colors.orange;
            break;
          case ItemType.game:
            typeIcon = Broken.gameboy;
            typeColor = Colors.red;
            break;
          case ItemType.plugin:
            typeIcon = Broken.element_plus;
            typeColor = Colors.teal;
            break;
        }

        return GestureDetector(
          onTap: () => openHistoryEntry(context, element),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCover(manga, ref),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(typeIcon, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                manga.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                chapter.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCover(Manga manga, WidgetRef ref) {
    if (manga.customCoverImage != null) {
      return Image.memory(
        manga.customCoverImage as Uint8List,
        fit: BoxFit.cover,
      );
    }
    return cachedCompressedNetworkImage(
      headers: ref.read(
        headersProvider(
          source: manga.source!,
          lang: manga.lang!,
          sourceId: manga.sourceId,
        ),
      ),
      imageUrl: toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? ''),
      width: null,
      height: null,
      fit: BoxFit.cover,
    );
  }
}

  // ── Layout card (card-preview for disposition picker) ──────────────────────

  class _LayoutCard extends StatelessWidget {
    final String label;
    final IconData icon;
    final bool selected;
    final VoidCallback onTap;

    const _LayoutCard({
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceVariant.withValues(alpha: 0.4),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ── Select chip (for sort and period pickers) ──────────────────────────────

  class _SelectChip extends StatelessWidget {
    final String label;
    final IconData icon;
    final bool selected;
    final VoidCallback onTap;

    const _SelectChip({
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceVariant.withValues(alpha: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  