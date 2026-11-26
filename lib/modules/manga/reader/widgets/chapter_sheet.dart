import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/reader/providers/push_router.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/modules/manga/reader/reader_view.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_prefs_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Opens the in-reader chapter browser.
///
/// The browser is a bottom sheet whose header carries the same drill-down
/// panel the library uses for its filter button ([AdaptiveOverlayMenuButton] +
/// in-place level swapping), so display, filter and sort are reached exactly
/// the way they are in the library instead of through a second, bespoke UI.
Widget btnToShowChapterListDialog(
  BuildContext context,
  String title,
  Chapter chapter, {
  void Function(bool)? onChanged,
  Color? iconColor,
  double? iconSize,
}) {
  return IconButton(
    iconSize: iconSize ?? 24,
    onPressed: () async {
      onChanged?.call(false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ChapterSheet(chapter: chapter, title: title),
      );
      onChanged?.call(true);
    },
    icon: Icon(Broken.layer, color: iconColor),
  );
}

class ChapterSheet extends ConsumerStatefulWidget {
  const ChapterSheet({super.key, required this.chapter, required this.title});

  final Chapter chapter;
  final String title;

  @override
  ConsumerState<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends ConsumerState<ChapterSheet> {
  /// Owned by the enclosing [DraggableScrollableSheet]; captured on first build
  /// so the initial jump can reach it.
  ScrollController? _sheetScroll;

  late final List<Chapter> _chapters =
      resolveChapterManga(widget.chapter)?.getFilteredChapterList() ?? const [];

  /// Downloaded chapter ids, read once: a per-tile `isar.downloads.getSync`
  /// would run a synchronous Isar query for every row on the UI isolate.
  late final Set<int> _downloadedIds = isar.downloads
      .where()
      .findAllSync()
      .where((download) => download.isDownload == true)
      .map((download) => download.id)
      .whereType<int>()
      .toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  bool _isCurrent(Chapter chapter) =>
      chapter.name == widget.chapter.name &&
      chapter.dateUpload == widget.chapter.dateUpload &&
      chapter.scanlator == widget.chapter.scanlator &&
      chapter.url == widget.chapter.url;

  List<Chapter> _visible(String filter, String sort) {
    var chapters = _chapters;
    switch (filter) {
      case 'unread':
        chapters = chapters.where((c) => !(c.isRead ?? false)).toList();
      case 'downloaded':
        chapters = chapters
            .where((c) => c.id != null && _downloadedIds.contains(c.id))
            .toList();
      case 'bookmarked':
        chapters = chapters.where((c) => c.isBookmarked ?? false).toList();
    }
    switch (sort) {
      case 'newest':
        chapters = [...chapters]..sort((a, b) => _date(b).compareTo(_date(a)));
      case 'oldest':
        chapters = [...chapters]..sort((a, b) => _date(a).compareTo(_date(b)));
      case 'alpha':
        chapters = [...chapters]
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    }
    return chapters;
  }

  /// `dateUpload` is epoch milliseconds, not an ISO date; sorting it as a
  /// string would order "9" after "10".
  int _date(Chapter chapter) => int.tryParse(chapter.dateUpload ?? '') ?? 0;

  /// Scrolls the current chapter into view on open.
  ///
  /// Rows have a fixed height, so a proportional offset lands on the right one
  /// without measuring the list. The sheet only builds its scroll view once the
  /// chapter list is non-empty, so this retries on the next frame while that is
  /// still pending — and gives up if the sheet was popped meanwhile.
  void _jumpToCurrent([int attempt = 0]) {
    if (!mounted || _chapters.isEmpty || attempt > 8) return;
    final controller = _sheetScroll;
    if (controller == null || !controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToCurrent(attempt + 1),
      );
      return;
    }
    final visible = _visible(
      ref.read(chapterSheetFilterProvider),
      ref.read(chapterSheetSortProvider),
    );
    final index = visible.indexWhere(_isCurrent);
    if (index <= 0) return;
    final max = controller.position.maxScrollExtent;
    controller.jumpTo((max / visible.length) * index);
  }

  void _open(Chapter chapter) {
    if (_isCurrent(chapter)) return;
    Navigator.pop(context);
    MangaChapterPageGalleryState.setNavigatingToChapter();
    pushReplacementMangaReaderView(context: context, chapter: chapter);
  }

  @override
  Widget build(BuildContext context) {
    final display = ref.watch(chapterSheetDisplayProvider);
    final gridSize = ref.watch(chapterSheetGridSizeProvider);
    final filter = ref.watch(chapterSheetFilterProvider);
    final sort = ref.watch(chapterSheetSortProvider);
    final chapters = _visible(filter, sort);
    final isGrid = display == 'grid';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sheetController) {
        _sheetScroll = sheetController;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SheetHeader(
                title: widget.title,
                count: chapters.length,
                display: display,
                gridSize: gridSize,
                filter: filter,
                sort: sort,
              ),
              Expanded(
                child: chapters.isEmpty
                    ? Center(
                        child: Icon(
                          Broken.document_text,
                          size: 32,
                          color: context.secondaryColor,
                        ),
                      )
                    : CustomScrollView(
                        controller: sheetController,
                        slivers: [
                          if (isGrid)
                            SliverPadding(
                              padding: const EdgeInsets.all(12),
                              sliver: SliverGrid.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: gridSize,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      mainAxisExtent: 62,
                                    ),
                                itemCount: chapters.length,
                                itemBuilder: (context, index) => _ChapterTile(
                                  chapter: chapters[index],
                                  isCurrent: _isCurrent(chapters[index]),
                                  onTap: () => _open(chapters[index]),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              sliver: SliverList.builder(
                                itemCount: chapters.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _ChapterTile(
                                    chapter: chapters[index],
                                    isCurrent: _isCurrent(chapters[index]),
                                    onTap: () => _open(chapters[index]),
                                  ),
                                ),
                              ),
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
}

/// Header: chapter count, the grid-size shortcut and the drill-down panel.
class _SheetHeader extends ConsumerWidget {
  const _SheetHeader({
    required this.title,
    required this.count,
    required this.display,
    required this.gridSize,
    required this.filter,
    required this.sort,
  });

  final String title;
  final int count;
  final String display;
  final int gridSize;
  final String filter;
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final isGrid = display == 'grid';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
      child: Row(
        children: [
          Icon(Broken.book_1, size: 18, color: context.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.n_chapters(count),
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
              ],
            ),
          ),
          if (isGrid)
            AdaptiveOverlayMenuButton(
              menuWidth: 170,
              trigger: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_gridIcon(gridSize), size: 20),
                    const Icon(Broken.arrow_down_1, size: 12),
                  ],
                ),
              ),
              contentBuilder: (close) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final columns in kChapterGridSizes)
                    AdaptiveOverlayItem(
                      icon: _gridIcon(columns),
                      label: '$columns×$columns',
                      selected: gridSize == columns,
                      onTap: () {
                        ref
                            .read(chapterSheetGridSizeProvider.notifier)
                            .set(columns);
                        close();
                      },
                    ),
                ],
              ),
            ),
          AdaptiveOverlayMenuButton(
            menuWidth: 250,
            trigger: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Broken.layer, size: 20),
            ),
            contentBuilder: (close) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdaptiveOverlayItem(
                  icon: Broken.row_horizontal,
                  label: l10n.list,
                  selected: display == 'list',
                  onTap: () {
                    ref.read(chapterSheetDisplayProvider.notifier).set('list');
                    close();
                  },
                ),
                for (final columns in kChapterGridSizes)
                  AdaptiveOverlayItem(
                    icon: _gridIcon(columns),
                    label: '${l10n.grid_size} $columns×$columns',
                    selected: display == 'grid' && gridSize == columns,
                    onTap: () {
                      ref
                          .read(chapterSheetDisplayProvider.notifier)
                          .set('grid');
                      ref
                          .read(chapterSheetGridSizeProvider.notifier)
                          .set(columns);
                      close();
                    },
                  ),
                const Divider(height: 12),
                for (final option in kChapterFilterOptions)
                  AdaptiveOverlayItem(
                    icon: Broken.filter,
                    label: _filterLabel(option, l10n),
                    selected: filter == option,
                    onTap: () {
                      ref.read(chapterSheetFilterProvider.notifier).set(option);
                      close();
                    },
                  ),
                const Divider(height: 12),
                for (final option in kChapterSortOptions)
                  AdaptiveOverlayItem(
                    icon: Broken.sort,
                    label: _sortLabel(option, l10n),
                    selected: sort == option,
                    onTap: () {
                      ref.read(chapterSheetSortProvider.notifier).set(option);
                      close();
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Broken.close_circle, size: 20),
          ),
        ],
      ),
    );
  }

  static IconData _gridIcon(int columns) => switch (columns) {
    3 => Broken.grid_3,
    4 => Broken.grid_4,
    _ => Broken.grid_2,
  };

  static String _filterLabel(String option, AppLocalizations l10n) =>
      switch (option) {
        'unread' => l10n.unread,
        'downloaded' => l10n.downloaded,
        'bookmarked' => l10n.bookmarked,
        _ => l10n.all_chapters,
      };

  static String _sortLabel(String option, AppLocalizations l10n) =>
      switch (option) {
        'newest' => l10n.chapter_sheet_sort_newest,
        'oldest' => l10n.chapter_sheet_sort_oldest,
        'alpha' => l10n.chapter_sheet_sort_alpha,
        _ => l10n.chapter_sheet_sort_source,
      };
}

class _ChapterTile extends ConsumerWidget {
  const _ChapterTile({
    required this.chapter,
    required this.isCurrent,
    required this.onTap,
  });

  final Chapter chapter;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = chapter.isRead ?? false;
    final metaStyle = TextStyle(fontSize: 10, color: context.secondaryColor);
    final date = (chapter.dateUpload ?? '').isEmpty
        ? ''
        : dateFormat(chapter.dateUpload!, ref: ref, context: context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCurrent
            ? context.primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(
                color: context.primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      isCurrent
                          ? Broken.play_circle
                          : (isRead ? Broken.tick_circle : Broken.record_circle),
                      size: 14,
                      color: isCurrent
                          ? context.primaryColor
                          : (isRead
                                ? context.secondaryColor
                                : context.primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter.name ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isRead && !isCurrent
                              ? context.secondaryColor
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if ((chapter.scanlator ?? '').isNotEmpty) ...[
                      Icon(Broken.user, size: 11, color: context.secondaryColor),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          chapter.scanlator!,
                          style: metaStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (date.isNotEmpty) ...[
                      Icon(
                        Broken.calendar,
                        size: 11,
                        color: context.secondaryColor,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          date,
                          style: metaStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_progress(context) case final progress?)
                      Text(
                        progress,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.primaryColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reading progress of a started, unfinished chapter.
  ///
  /// `lastPageRead` holds a page number for manga, a fraction for novels, and a
  /// duration in milliseconds for anime; "1" means "finished", not "page 1",
  /// so the read flag has to be checked first.
  String? _progress(BuildContext context) {
    final raw = chapter.lastPageRead;
    if ((chapter.isRead ?? false) || raw == null || raw.isEmpty || raw == '1') {
      return null;
    }
    final l10n = context.l10n;
    return switch (resolveChapterManga(chapter)?.itemType) {
      ItemType.anime => l10n.episode_progress(
        Duration(milliseconds: int.tryParse(raw) ?? 0).toString().substringBefore(
          '.',
        ),
      ),
      ItemType.manga => l10n.page(raw),
      _ => '${((double.tryParse(raw) ?? 0) * 100).toStringAsFixed(0)} %',
    };
  }
}

