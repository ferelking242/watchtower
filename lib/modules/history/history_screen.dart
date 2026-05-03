import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/widgets/base_library_tab_screen.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/history/providers/isar_providers.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';

// ── Layout mode for the history list ─────────────────────────────────────────
enum _HistoryLayout { list, grid }

// ── Sort mode ────────────────────────────────────────────────────────────────
enum _HistorySort { date, title }

// ── Filter mode ──────────────────────────────────────────────────────────────
enum _HistoryFilter { all, today, thisWeek, thisMonth }

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
        icon = Icons.play_circle_outline_rounded;
        break;
      case ItemType.manga:
        icon = Icons.menu_book_outlined;
        break;
      case ItemType.novel:
        icon = Icons.auto_stories_outlined;
        break;
      case ItemType.music:
        icon = Icons.music_note_outlined;
        break;
      case ItemType.game:
        icon = Icons.sports_esports_outlined;
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
          Icons.filter_list_sharp,
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
          Icons.delete_sweep_outlined,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final primary = Theme.of(ctx).colorScheme.primary;
          void updateBoth(VoidCallback fn) {
            setState(fn);
            setModalState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Disposition ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.grid_view_rounded, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          'Disposition',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const Spacer(),
                        ToggleButtons(
                          isSelected: [
                            _layout == _HistoryLayout.list,
                            _layout == _HistoryLayout.grid,
                          ],
                          onPressed: (i) => updateBoth(() {
                            _layout = i == 0
                                ? _HistoryLayout.list
                                : _HistoryLayout.grid;
                          }),
                          borderRadius: BorderRadius.circular(10),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 36,
                          ),
                          children: const [
                            Icon(Icons.view_list_rounded, size: 18),
                            Icon(Icons.grid_view_rounded, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 8),

                  // ── Trier par ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          'Trier par',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RadioListTile<_HistorySort>(
                    title: const Text('Date de lecture'),
                    secondary: const Icon(Icons.access_time_rounded),
                    value: _HistorySort.date,
                    groupValue: _sort,
                    onChanged: (v) => updateBoth(() => _sort = v!),
                  ),
                  RadioListTile<_HistorySort>(
                    title: const Text('Titre'),
                    secondary: const Icon(Icons.sort_by_alpha_rounded),
                    value: _HistorySort.title,
                    groupValue: _sort,
                    onChanged: (v) => updateBoth(() => _sort = v!),
                  ),
                  const Divider(height: 8),

                  // ── Filtrer par période ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list_sharp,
                            size: 18, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          'Filtrer par période',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RadioListTile<_HistoryFilter>(
                    title: const Text('Tout'),
                    secondary: const Icon(Icons.all_inclusive_rounded),
                    value: _HistoryFilter.all,
                    groupValue: _filter,
                    onChanged: (v) => updateBoth(() => _filter = v!),
                  ),
                  RadioListTile<_HistoryFilter>(
                    title: const Text("Aujourd'hui"),
                    secondary: const Icon(Icons.today_rounded),
                    value: _HistoryFilter.today,
                    groupValue: _filter,
                    onChanged: (v) => updateBoth(() => _filter = v!),
                  ),
                  RadioListTile<_HistoryFilter>(
                    title: const Text('Cette semaine'),
                    secondary: const Icon(Icons.date_range_rounded),
                    value: _HistoryFilter.thisWeek,
                    groupValue: _filter,
                    onChanged: (v) => updateBoth(() => _filter = v!),
                  ),
                  RadioListTile<_HistoryFilter>(
                    title: const Text('Ce mois-ci'),
                    secondary: const Icon(Icons.calendar_month_rounded),
                    value: _HistoryFilter.thisMonth,
                    groupValue: _filter,
                    onChanged: (v) => updateBoth(() => _filter = v!),
                  ),
                ],
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

// ── History Tab ───────────────────────────────────────────────────────────────

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
                      Icons.calendar_today_outlined,
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

// ── List item ─────────────────────────────────────────────────────────────────

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
        typeIcon = Icons.play_circle_outline_rounded;
        typeColor = Colors.deepPurple;
        break;
      case ItemType.manga:
        typeIcon = Icons.menu_book_outlined;
        typeColor = Colors.blue;
        break;
      case ItemType.novel:
        typeIcon = Icons.auto_stories_outlined;
        typeColor = Colors.green;
        break;
      case ItemType.music:
        typeIcon = Icons.music_note_outlined;
        typeColor = Colors.orange;
        break;
      case ItemType.game:
        typeIcon = Icons.sports_esports_outlined;
        typeColor = Colors.red;
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
      onPressed: () async => chapter.pushToReaderView(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover
              GestureDetector(
                onTap: () =>
                    context.push('/manga-reader/detail', extra: manga.id),
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
                        Icon(Icons.access_time_rounded,
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
                icon: Icon(Icons.delete_outline,
                    size: 22, color: cs.onSurfaceVariant),
                tooltip: 'Supprimer de l\'historique',
              ),
            ],
          ),
        ),
      ),
    );
  }

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

// ── Grid view ─────────────────────────────────────────────────────────────────

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
            typeIcon = Icons.play_circle_outline_rounded;
            typeColor = Colors.deepPurple;
            break;
          case ItemType.manga:
            typeIcon = Icons.menu_book_outlined;
            typeColor = Colors.blue;
            break;
          case ItemType.novel:
            typeIcon = Icons.auto_stories_outlined;
            typeColor = Colors.green;
            break;
          case ItemType.music:
            typeIcon = Icons.music_note_outlined;
            typeColor = Colors.orange;
            break;
          case ItemType.game:
            typeIcon = Icons.sports_esports_outlined;
            typeColor = Colors.red;
            break;
        }

        return GestureDetector(
          onTap: () => chapter.pushToReaderView(context),
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
