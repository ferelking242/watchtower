import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';
import 'package:draggable_menu/draggable_menu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/detail/chapter_download_selection.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/models/track_search.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/local_archive.dart';
import 'package:watchtower/modules/manga/detail/providers/track_state_providers.dart';
import 'package:watchtower/modules/manga/detail/widgets/tracker_search_widget.dart';
import 'package:watchtower/modules/manga/detail/widgets/tracker_widget.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/modules/more/providers/algorithm_weights_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/track/widgets/track_listile.dart';
import 'package:watchtower/modules/tracker_library/tracker_library_screen.dart';
import 'package:watchtower/modules/widgets/bottom_select_bar.dart';
import 'package:watchtower/modules/widgets/category_selection_dialog.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/others.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/manga/detail/widgets/detail_shimmer.dart';
import 'package:watchtower/modules/manga/detail/widgets/similar_section.dart';
import 'package:watchtower/modules/media/comments_view.dart';
import 'package:watchtower/modules/manga/detail/widgets/readmore.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/manga/detail/widgets/chapter_list_tile_widget.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../../../utils/constant.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';

/// Onglets de la page de détail, dans l'ordre demandé :
/// Chapitres · Similar · Commentaires.
///
/// L'ordre de cette enum pilote l'ordre des onglets (index du TabController).
enum _DetailSection { chapters, similar, comments }

class MangaDetailView extends ConsumerStatefulWidget {
  final Function(bool) isExtended;
  final Widget? titleDescription;
  final List<Color>? backButtonColors;
  final Widget? action;
  final Manga? manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;
  final ItemType itemType;

  /// Vrai pendant le chargement des informations depuis la source : les
  /// blocs texte (titre, auteur, statut, description) affichent alors un
  /// shimmer, tandis que leurs icônes restent visibles.
  final bool isLoading;

  const MangaDetailView({
    super.key,
    required this.isExtended,
    this.titleDescription,
    this.backButtonColors,
    this.action,
    required this.sourceExist,
    required this.manga,
    required this.checkForUpdate,
    required this.itemType,
    this.isLoading = false,
  });

  @override
  ConsumerState<MangaDetailView> createState() => _MangaDetailViewState();
}

class _MangaDetailViewState extends ConsumerState<MangaDetailView>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        _scrollOffset.value = _scrollController.offset;
      });
    _sectionController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (_sectionController.indexIsChanging) return;
        final next = _DetailSection.values[_sectionController.index];
        if (next != _detailSection && mounted) {
          setState(() => _detailSection = next);
        }
      });
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  final _scrollOffset = ValueNotifier<double>(0.0);
  bool _expanded = false;
  _DetailSection _detailSection = _DetailSection.chapters;
  late final TabController _sectionController;
  late final ScrollController _scrollController;
  late final isLocalArchive = widget.manga?.isLocalArchive ?? false;
  @override
  Widget build(BuildContext context) {
    final scanlators = ref.watch(scanlatorsFilterStateProvider(widget.manga!));
    final reverse = ref
        .watch(sortChapterStateProvider(mangaId: widget.manga!.id!))
        .reverse!;
    final filterUnread = ref.watch(
      chapterFilterUnreadStateProvider(mangaId: widget.manga!.id!),
    );
    final filterBookmarked = ref.watch(
      chapterFilterBookmarkedStateProvider(mangaId: widget.manga!.id!),
    );
    final filterDownloaded = ref.watch(
      chapterFilterDownloadedStateProvider(mangaId: widget.manga!.id!),
    );
    final sortChapter =
        ref.watch(sortChapterStateProvider(mangaId: widget.manga!.id!)).index
            as int;
    final chapters = ref.watch(
      getChaptersStreamProvider(mangaId: widget.manga!.id!),
    );
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.forward) {
          widget.isExtended(true);
        }
        if (notification.direction == ScrollDirection.reverse) {
          widget.isExtended(false);
        }
        return true;
      },
      child: chapters.when(
        data: (data) {
          List<Chapter> chapters = _filterAndSortChapter(
            data: data.reversed.toList(),
            filterUnread: filterUnread,
            filterBookmarked: filterBookmarked,
            filterDownloaded: filterDownloaded,
            sortChapter: sortChapter,
            filterScanlator: scanlators.$2,
          );
          ref.read(chaptersListttStateProvider.notifier).set(chapters);
          return _buildWidget(chapters: chapters, reverse: reverse);
        },
        error: (Object error, StackTrace stackTrace) {
          return ErrorText(error);
        },
        loading: () {
          return _buildWidget(
            chapters: widget.manga!.chapters.toList().reversed.toList(),
            reverse: reverse,
          );
        },
      ),
    );
  }

  List<Chapter> _getFilteredAndSortedChapters() {
    final filterScanlator = ref.read(
      scanlatorsFilterStateProvider(widget.manga!),
    );
    final filterUnread = ref.read(
      chapterFilterUnreadStateProvider(mangaId: widget.manga!.id!),
    );
    final filterBookmarked = ref.read(
      chapterFilterBookmarkedStateProvider(mangaId: widget.manga!.id!),
    );
    final filterDownloaded = ref.read(
      chapterFilterDownloadedStateProvider(mangaId: widget.manga!.id!),
    );
    final sortChapter =
        ref.read(sortChapterStateProvider(mangaId: widget.manga!.id!)).index
            as int;
    final chapters = isar.chapters
        .filter()
        .mangaIdEqualTo(widget.manga!.id!)
        .findAllSync();
    return _filterAndSortChapter(
      data: chapters,
      filterUnread: filterUnread,
      filterBookmarked: filterBookmarked,
      filterDownloaded: filterDownloaded,
      sortChapter: sortChapter,
      filterScanlator: filterScanlator.$2,
    );
  }

  Future<void> _queueChapters(Iterable<Chapter> chapters) async {
    try {
      for (final chapter in chapters) {
        final manga = widget.manga;
        if (manga != null &&
            manga.id != null &&
            chapter.mangaId == manga.id) {
          // The detail route already has this Manga instance. Prefer it over
          // re-reading a potentially corrupt Isar row while adding chapters.
          chapter.manga.value = manga;
        }
        await ref.read(addDownloadToQueueProvider(chapter: chapter).future);
        final id = chapter.id;
        if (id != null) {
          ref.read(downloadQueueStateProvider.notifier).setPaused(id, false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[MangaDetailView] queue failed: $e\n$stackTrace');
      botToast('Impossible de démarrer : ${friendlyErrorMessage(e)}');
    } finally {
      // Persisted entries are always processed, including when a later item
      // in a multi-chapter request failed to save.
      ref.read(processDownloadsProvider());
    }
  }

  /// Ligne icône + libellé partagée par les menus déroulants du détail.
  Widget _menuRow(IconData icon, String label) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
  );

  /// Extrait la valeur numérique du libellé d'un chapitre ("Chapitre 44.5" →
  /// 44.5). Retourne null quand le nom ne porte aucun nombre.
  double? _chapterNumber(Chapter chapter) {
    final match = RegExp(
      r'\d+(?:[.,]\d+)?',
    ).firstMatch(chapter.name?.trim() ?? '');
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '');
  }

  String _formatChapterNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// « Télécharger une plage » : demande un début et une fin puis met en file
  /// tous les chapitres compris entre les deux, dans l'ordre de lecture.
  Future<void> _downloadRange(List<Chapter> chapters) async {
    if (chapters.isEmpty) return;
    final l10n = l10nLocalizations(context)!;
    final numbered = chapters
        .map((c) => (chapter: c, number: _chapterNumber(c)))
        .where((e) => e.number != null)
        .toList();
    if (numbered.isEmpty) {
      botToast(l10n.invalid_range);
      return;
    }
    final numbers = numbered.map((e) => e.number!).toList()..sort();
    final startController = TextEditingController(
      text: _formatChapterNumber(numbers.first),
    );
    final endController = TextEditingController(
      text: _formatChapterNumber(numbers.last),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.download_range),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.range_start),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.range_end),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.download_range_hint,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.download),
          ),
        ],
      ),
    );
    final start = double.tryParse(
      startController.text.trim().replaceAll(',', '.'),
    );
    final end = double.tryParse(
      endController.text.trim().replaceAll(',', '.'),
    );
    startController.dispose();
    endController.dispose();
    if (confirmed != true || start == null || end == null) return;
    final low = start <= end ? start : end;
    final high = start <= end ? end : start;
    final selected = numbered
        .where((e) => e.number! >= low && e.number! <= high)
        .map((e) => e.chapter)
        .toList();
    if (selected.isEmpty) {
      botToast(l10n.invalid_range);
      return;
    }
    await _queueChapters(selected);
  }

  List<Chapter> _filterAndSortChapter({
    required List<Chapter> data,
    required int filterUnread,
    required int filterBookmarked,
    required int filterDownloaded,
    required int sortChapter,
    required List<String> filterScanlator,
  }) {
    // One Isar query for the whole chapter list instead of one per chapter.
    // The download filter used to run `isar.downloads...findAllSync()` inside
    // the `where` predicate, i.e. a synchronous Isar read per chapter, on the
    // UI isolate, on every rebuild of the detail screen — the freeze reported
    // when opening a title with hundreds of chapters.
    final Set<int>? downloadedIds = filterDownloaded == 0
        ? null
        : isar.downloads
              .where()
              .findAllSync()
              .where((download) => download.isDownload == true)
              .map((download) => download.id)
              .whereType<int>()
              .toSet();

    List<Chapter>? chapterList;
    chapterList = data
        .where(
          (element) => filterUnread == 1
              ? element.isRead == false
              : filterUnread == 2
              ? element.isRead == true
              : true,
        )
        .where(
          (element) => filterBookmarked == 1
              ? element.isBookmarked == true
              : filterBookmarked == 2
              ? element.isBookmarked == false
              : true,
        )
        .where((element) {
          if (downloadedIds == null) return true;
          final isDownloaded =
              element.id != null && downloadedIds.contains(element.id);
          return filterDownloaded == 1 ? isDownloaded : !isDownloaded;
        })
        .where((element) => !filterScanlator.contains(element.scanlator))
        .toList();
    List<Chapter> chapters = sortChapter == 1
        ? chapterList.reversed.toList()
        : chapterList;
    if (sortChapter == 0) {
      chapters.sort((a, b) {
        return (a.scanlator == null ||
                b.scanlator == null ||
                a.dateUpload == null ||
                b.dateUpload == null)
            ? 0
            : a.scanlator!.compareTo(b.scanlator!) |
                  a.dateUpload!.compareTo(b.dateUpload!);
      });
    } else if (sortChapter == 2) {
      chapters.sort((a, b) {
        return (a.dateUpload == null || b.dateUpload == null)
            ? 0
            : int.parse(a.dateUpload!).compareTo(int.parse(b.dateUpload!));
      });
    } else if (sortChapter == 3) {
      chapters.sort((a, b) {
        return (a.name == null || b.name == null)
            ? 0
            : a.name!.compareTo(b.name!);
      });
    }
    return chapters;
  }

  Widget _buildWidget({
    required List<Chapter> chapters,
    required bool reverse,
  }) {
    final chapterList = ref.watch(chaptersListStateProvider);
    final isLongPressed = ref.watch(isLongPressedStateProvider);
    final checkCategoryList = isar.categorys
        .filter()
        .forItemTypeEqualTo(widget.manga!.itemType)
        .isNotEmptySync();
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _scrollOffset,
          builder: (context, offset, _) {
            return Positioned(
              top: 0,
              child: offset == 0.0
                  ? Consumer(
                      builder: (context, ref, child) => DetailShimmerImage(
                        // Arrière-plan du cover : shimmer détaillé pendant le
                        // chargement (le voile de lisibilité n'est appliqué
                        // qu'une fois l'image prête).
                        imageProvider: widget.manga!.customCoverImage != null
                            ? MemoryImage(
                                widget.manga!.customCoverImage as Uint8List,
                              )
                            : CustomExtendedNetworkImageProvider(
                                toImgUrl(
                                  widget.manga!.customCoverFromTracker ??
                                      widget.manga!.imageUrl ??
                                      "",
                                ),
                                headers: isLocalArchive
                                    ? null
                                    : ref.watch(
                                        headersProvider(
                                          source: widget.manga!.source!,
                                          lang: widget.manga!.lang!,
                                          sourceId: widget.manga!.sourceId,
                                        ),
                                      ),
                              ),
                        width: context.width(1),
                        height: 300,
                        fit: BoxFit.cover,
                        placeholderBuilder: (context) =>
                            const DetailHeroShimmer(height: 300),
                        loadedBuilder: (context, image) => Stack(
                          children: [
                            image,
                            Stack(
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: context.width(1),
                                      height: AppBar().preferredSize.height,
                                      color: context.isTablet
                                          ? Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor
                                          : Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withValues(alpha: 0.9),
                                    ),
                                    Container(
                                      width: context.width(1),
                                      height: 465,
                                      color: context.isTablet
                                          ? Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor
                                          : Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withValues(alpha: 0.9),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    width: context.width(1),
                                    height: 100,
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(),
            );
          },
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(AppBar().preferredSize.height),
            child: Consumer(
              builder: (context, ref, child) {
                final l10n = l10nLocalizations(context)!;
                final isNotFiltering = ref.watch(
                  chapterFilterResultStateProvider(manga: widget.manga!),
                );
                return isLongPressed
                    ? Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: AppBar(
                          title: Text(chapterList.length.toString()),
                          backgroundColor: context.primaryColor.withValues(
                            alpha: 0.2,
                          ),
                          leading: IconButton(
                            onPressed: () {
                              ref
                                  .read(chaptersListStateProvider.notifier)
                                  .clear();

                              ref
                                  .read(isLongPressedStateProvider.notifier)
                                  .update(!isLongPressed);
                            },
                            icon: const Icon(Broken.close_circle, size: 24),
                          ),
                          actions: [
                            IconButton(
                              onPressed: () {
                                for (var chapter in chapters) {
                                  ref
                                      .read(chaptersListStateProvider.notifier)
                                      .selectAll(chapter);
                                }
                              },
                              icon: const Icon(Broken.tick_square, size: 23),
                            ),
                            IconButton(
                              tooltip: l10n.select_invert,
                              onPressed: () {
                                ref
                                    .read(chaptersListStateProvider.notifier)
                                    .invertSelection(chapters);
                              },
                              icon: const Icon(
                                Broken.refresh_left_square,
                                size: 23,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.select_range,
                              onPressed: () {
                                ref
                                    .read(chaptersListStateProvider.notifier)
                                    .selectBetweenExtremes(chapters);
                              },
                              icon: const Icon(Broken.maximize_3, size: 23),
                            ),
                          ],
                        ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: _scrollOffset,
                        builder: (context, offset, _) => AppBar(
                        leading: IconButton(
                          icon: const Icon(Broken.arrow_left_2, size: 26),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        title: offset > 200
                            ? Text(
                                widget.manga!.name!,
                                style: const TextStyle(fontSize: 17),
                              )
                            : null,
                        backgroundColor: offset == 0.0
                            ? Colors.transparent
                            : Theme.of(context).scaffoldBackgroundColor,
                        actions: [
                          if (!isLocalArchive) ...[
                            AdaptiveOverlayMenu<int>(
                              icon: const Icon(
                                // Icône de téléchargement Broken (anneau de
                                // progression affiché sur les tuiles chapitre).
                                Broken.receive_square,
                                size: 23,
                              ),
                              menuWidth: 250,
                              itemBuilder: (context) {
                                final isAnime =
                                    widget.itemType == ItemType.anime;
                                Widget row(IconData icon, String label) => Row(
                                  children: [
                                    Icon(icon, size: 18),
                                    const SizedBox(width: 10),
                                    Text(label),
                                  ],
                                );
                                return [
                                  PopupMenuItem<int>(
                                    value: 0,
                                    child: row(
                                      Broken.book_1,
                                      isAnime
                                          ? context.l10n.next_episode
                                          : context.l10n.next_chapter,
                                    ),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 1,
                                    child: row(
                                      Broken.element_3,
                                      isAnime
                                          ? context.l10n.next_5_episodes
                                          : context.l10n.next_5_chapters,
                                    ),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 2,
                                    child: row(
                                      Broken.task,
                                      isAnime
                                          ? context.l10n.next_10_episodes
                                          : context.l10n.next_10_chapters,
                                    ),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 3,
                                    child: row(
                                      Broken.layer,
                                      isAnime
                                          ? context.l10n.next_25_episodes
                                          : context.l10n.next_25_chapters,
                                    ),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem<int>(
                                    value: 4,
                                    child: row(
                                      Broken.bookmark,
                                      isAnime
                                          ? context.l10n.unwatched
                                          : context.l10n.unread,
                                    ),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 5,
                                    child: row(
                                      Broken.gallery,
                                      isAnime
                                          ? context.l10n.all_episodes
                                          : context.l10n.all_chapters,
                                    ),
                                  ),
                                  PopupMenuDivider(),
                                  PopupMenuItem<int>(
                                    value: 6,
                                    child: row(
                                      Broken.calendar_1,
                                      context.l10n.download_range,
                                    ),
                                  ),
                                ];
                              },
                              onSelected: (value) async {
                                final chapters =
                                    _getFilteredAndSortedChapters();
                                if (value >= 0 && value <= 3) {
                                  final lastChapterReadIndex = chapters
                                      .lastIndexWhere(
                                        (element) => element.isRead == true,
                                      );
                                  final requestedCount = switch (value) {
                                    0 => 1,
                                    1 => 5,
                                    2 => 10,
                                    _ => 25,
                                  };
                                  final chaptersToDownload =
                                      selectChaptersToDownload(
                                        chapters: chapters,
                                        lastReadIndex: lastChapterReadIndex,
                                        limit: requestedCount,
                                      );
                                  await _queueChapters(chaptersToDownload);
                                } else if (value == 4) {
                                  final List<Chapter> unreadChapters = chapters
                                      .where(
                                        (element) =>
                                            !(element.isRead ?? false),
                                      )
                                      .toList();
                                  await _queueChapters(unreadChapters);
                                } else if (value == 5) {
                                  await _queueChapters(chapters);
                                } else if (value == 6) {
                                  await _downloadRange(chapters);
                                }
                              },
                            ),
                          AdaptiveOverlayMenuButton(
                            trigger: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Broken.filter,
                                size: 23,
                                color: isNotFiltering ? null : Colors.yellow,
                              ),
                            ),
                            menuWidth: 280,
                            contentBuilder: _chapterFilterMenu,
                          ),
                          AdaptiveOverlayMenu<int>(
                            menuWidth: 240,
                            icon: const Icon(Broken.more_2, size: 23),
                            itemBuilder: (context) {
                              return [
                                if (!isLocalArchive)
                                  PopupMenuItem<int>(
                                    value: 0,
                                    child: _menuRow(Broken.refresh, l10n.refresh),
                                  ),
                                if (widget.manga!.favorite! &&
                                    checkCategoryList)
                                  PopupMenuItem<int>(
                                    value: 1,
                                    child: _menuRow(
                                      Broken.tag,
                                      l10n.set_categories,
                                    ),
                                  ),
                                if (!isLocalArchive)
                                  PopupMenuItem<int>(
                                    value: 2,
                                    child: _menuRow(Broken.share, l10n.share),
                                  ),
                                PopupMenuItem<int>(
                                  value: 3,
                                  child: _menuRow(Broken.convert, l10n.migrate),
                                ),
                                PopupMenuItem<int>(
                                  value: 6,
                                  child: _menuRow(
                                    Broken.layer,
                                    'Mass migration',
                                  ),
                                ),
                                if (!isLocalArchive)
                                  PopupMenuItem<int>(
                                    value: 4,
                                    child: _menuRow(
                                      Broken.settings,
                                      l10n.extension_settings,
                                    ),
                                  ),
                                PopupMenuItem<int>(
                                  value: 5,
                                  child: _menuRow(
                                    Broken.export,
                                    l10n.export_metadata,
                                  ),
                                ),
                              ];
                            },
                            onSelected: (value) async {
                              switch (value) {
                                case 0:
                                  widget.checkForUpdate(true);
                                  break;
                                case 1:
                                  showCategorySelectionDialog(
                                    context: context,
                                    ref: ref,
                                    itemType: widget.manga!.itemType,
                                    singleManga: widget.manga!,
                                  );
                                  break;
                                case 2:
                                  final source = getSource(
                                    widget.manga!.lang!,
                                    widget.manga!.source!,
                                    widget.manga!.sourceId,
                                  );
                                  if (source == null) return;
                                  final url =
                                      "${source.baseUrl}${widget.manga!.link!.getUrlWithoutDomain}";
                                  final box =
                                      context.findRenderObject() as RenderBox?;
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text: url,
                                      sharePositionOrigin:
                                          box!.localToGlobal(Offset.zero) &
                                          box.size,
                                    ),
                                  );
                                  break;
                                case 3:
                                  context.push("/migrate", extra: widget.manga);
                                  break;
                                case 4:
                                  final source = getSource(
                                    widget.manga!.lang!,
                                    widget.manga!.source!,
                                    widget.manga!.sourceId,
                                  );
                                  if (source == null) return;
                                  context.push(
                                    '/extension_detail',
                                    extra: source,
                                  );
                                  break;
                                case 5:
                                  try {
                                    final result =
                                        await FilePicker.getDirectoryPath();
                                    if (result != null) {
                                      final client = MClient.init();
                                      final coverFile = File(
                                        p.join(result, "cover.jpg"),
                                      );
                                      final metadataFile = File(
                                        p.join(result, "metadata.json"),
                                      );
                                      final headers =
                                          widget.manga!.isLocalArchive!
                                          ? null
                                          : ref.read(
                                              headersProvider(
                                                source: widget.manga!.source!,
                                                lang: widget.manga!.lang!,
                                                sourceId:
                                                    widget.manga!.sourceId,
                                              ),
                                            );
                                      final imageUrl = toImgUrl(
                                        widget.manga!.customCoverFromTracker ??
                                            widget.manga!.imageUrl ??
                                            "",
                                      );
                                      final res = await client.get(
                                        Uri.parse(imageUrl),
                                        headers: headers,
                                      );
                                      await coverFile.writeAsBytes(
                                        res.bodyBytes,
                                      );
                                      await metadataFile.writeAsString(
                                        jsonEncode({
                                          "name": widget.manga!.name,
                                          "description":
                                              widget.manga!.description,
                                          "artist": widget.manga!.artist,
                                          "author": widget.manga!.author,
                                          "genre": widget.manga!.genre,
                                          "status": widget.manga!.status.index,
                                        }),
                                      );
                                      botToast(l10n.exported);
                                    }
                                  } catch (e) {
                                    botToast("Failed to export metadata: $e");
                                  }
                                  break;
                                case 6:
                                  context.push(
                                    "/massMigration",
                                    extra: widget.manga,
                                  );
                                  break;
                              }
                            },
                          ),
                          ],
                        ],
                      ),
                    );
              },
            ),
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (context.isTablet)
                  SizedBox(
                    width: context.width(0.5),
                    height: context.height(1),
                    child: SingleChildScrollView(
                      child: _bodyContainer(chapterLength: chapters.length),
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    interactive: true,
                    thickness: 12,
                    radius: const Radius.circular(10),
                    controller: _scrollController,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 0, bottom: 60),
                          sliver: SuperSliverList.builder(
                            itemCount: _detailSection == _DetailSection.chapters
                                ? chapters.length + 1
                                : 1,
                            itemBuilder: (context, index) {
                              final l10n = l10nLocalizations(context)!;
                              if (_detailSection == _DetailSection.similar) {
                                return SimilarSection(
                                  name: widget.manga!.name!,
                                  itemType: widget.manga!.itemType,
                                  weights: ref.read(
                                    algorithmWeightsStateProvider,
                                  ),
                                );
                              }
                              if (_detailSection == _DetailSection.comments) {
                                final source = getSource(
                                  widget.manga!.lang!,
                                  widget.manga!.source!,
                                  widget.manga!.sourceId,
                                );
                                final url = source == null
                                    ? ''
                                    : '${source.baseUrl}'
                                          '${widget.manga!.link?.getUrlWithoutDomain ?? ''}';
                                return CommentsSection(
                                  url: url,
                                  source: source,
                                );
                              }
                              if (index == 0) {
                                return context.isTablet
                                    ? Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Row(
                                              mainAxisAlignment: isLocalArchive
                                                  ? MainAxisAlignment
                                                        .spaceBetween
                                                  : MainAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: chapters.isEmpty
                                                      ? context.height(1)
                                                      : null,
                                                  color: Theme.of(
                                                    context,
                                                  ).scaffoldBackgroundColor,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    child: Text(
                                                      widget.manga!.itemType !=
                                                              ItemType.anime
                                                          ? l10n.n_chapters(
                                                              chapters.length,
                                                            )
                                                          : l10n.n_episodes(
                                                              chapters.length,
                                                            ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (isLocalArchive)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            5,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                      Broken.add,
                                                      color: context
                                                          .secondaryColor,
                                                    ),
                                                    label: Text(
                                                      widget.manga!.itemType !=
                                                              ItemType.anime
                                                          ? l10n.add_chapters
                                                          : l10n.add_episodes,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: context
                                                            .secondaryColor,
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      final manga =
                                                          widget.manga;
                                                      if (manga!.source ==
                                                          "torrent") {
                                                        addTorrent(
                                                          context,
                                                          manga: manga,
                                                        );
                                                      } else {
                                                        final splitChapters =
                                                            manga.itemType ==
                                                                ItemType.novel
                                                            ? await _showSplitChaptersDialog(
                                                                context,
                                                              )
                                                            : true;
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        await ref.read(
                                                          importArchivesFromFileProvider(
                                                            itemType:
                                                                manga.itemType,
                                                            manga,
                                                            init: false,
                                                            splitChapters:
                                                                splitChapters,
                                                          ).future,
                                                        );
                                                      }
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : _bodyContainer(
                                        chapterLength: chapters.length,
                                      );
                              }
                              final chapterIndex = chapterIndexForListItem(
                                itemIndex: index,
                                chapterCount: chapters.length,
                                reverse: reverse,
                              );
                              if (chapterIndex == null) {
                                return const SizedBox.shrink();
                              }
                              return ChapterListTileWidget(
                                chapter: chapters[chapterIndex],
                                chapterList: chapterList,
                                allChapters: chapters,
                                sourceExist: widget.sourceExist,
                                manga: widget.manga!,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Builder(
            builder: (context) {
              final chap = ref.watch(chaptersListStateProvider);
              bool getLength1 = chap.length == 1;
              bool checkFirstBookmarked =
                  chap.isNotEmpty && chap.first.isBookmarked! && getLength1;
              bool checkReadBookmarked =
                  chap.isNotEmpty && chap.first.isRead! && getLength1;
              final l10n = l10nLocalizations(context)!;
              final color = Theme.of(context).textTheme.bodyLarge!.color!;
              return BottomSelectBar(
                isVisible: isLongPressed,
                actions: [
                  BottomSelectButton(
                    icon: Icon(
                      checkFirstBookmarked
                          ? Broken.bookmark
                          : Broken.bookmark_2,
                      color: color,
                    ),
                    onPressed: () {
                      final chapters = ref.read(chaptersListStateProvider);
                      final List<Chapter> updatedChapters = [];
                      final now = DateTime.now().millisecondsSinceEpoch;
                      for (var chapter in chapters) {
                        chapter.isBookmarked = !chapter.isBookmarked!;
                        chapter.updatedAt = now;
                        chapter.manga.value = widget.manga;
                        updatedChapters.add(chapter);
                      }
                      isar.writeTxnSync(() {
                        isar.chapters.putAllSync(updatedChapters);
                      });
                      ref
                          .read(isLongPressedStateProvider.notifier)
                          .update(false);
                      ref.read(chaptersListStateProvider.notifier).clear();
                    },
                  ),
                  BottomSelectButton(
                    icon: Icon(
                      checkReadBookmarked
                          ? Broken.close_circle
                          : Broken.tick_square,
                      color: color,
                    ),
                    onPressed: () {
                      final chapters = ref.read(chaptersListStateProvider);
                      final List<Chapter> updatedChapters = [];
                      final now = DateTime.now().millisecondsSinceEpoch;
                      for (var chapter in chapters) {
                        chapter.isRead = !chapter.isRead!;
                        if (!chapter.isRead!) {
                          chapter.lastPageRead = "1";
                        }
                        chapter.updatedAt = now;
                        chapter.manga.value = widget.manga;
                        updatedChapters.add(chapter);
                        if (chapter.isRead!) {
                          chapter.updateTrackChapterRead(ref);
                        }
                      }
                      isar.writeTxnSync(() {
                        isar.chapters.putAllSync(updatedChapters);
                        isar.mangas.putSync(widget.manga!);
                      });
                      ref
                          .read(isLongPressedStateProvider.notifier)
                          .update(false);
                      ref.read(chaptersListStateProvider.notifier).clear();
                    },
                  ),
                  if (getLength1)
                    BottomSelectButton(
                      icon: Stack(
                        children: [
                          Icon(Broken.tick_circle, color: color),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Icon(
                              Broken.arrow_down_2,
                              size: 11,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        int index = chapters.indexOf(chap.first);
                        if (index < 0 || index + 1 >= chapters.length) {
                          return;
                        }
                        final List<Chapter> updatedChapters = [];
                        final now = DateTime.now().millisecondsSinceEpoch;
                        chapters[index + 1].updateTrackChapterRead(ref);
                        for (var i = index + 1; i < chapters.length; i++) {
                          final chapter = chapters[i];
                          if (!chapter.isRead!) {
                            chapter.isRead = true;
                            chapter.lastPageRead = "1";
                            chapter.updatedAt = now;
                            chapter.manga.value = widget.manga;
                            updatedChapters.add(chapter);
                          }
                        }
                        isar.writeTxnSync(() {
                          isar.chapters.putAllSync(updatedChapters);
                          isar.mangas.putSync(widget.manga!);
                        });
                        ref
                            .read(isLongPressedStateProvider.notifier)
                            .update(false);
                        ref.read(chaptersListStateProvider.notifier).clear();
                      },
                    ),
                  if (!isLocalArchive)
                    BottomSelectButton(
                      icon: Icon(Broken.receive_square, color: color),
                      onPressed: () async {
                        await _queueChapters(
                          ref.read(chaptersListStateProvider),
                        );
                        ref
                            .read(isLongPressedStateProvider.notifier)
                            .update(false);
                        ref.read(chaptersListStateProvider.notifier).clear();
                      },
                    ),
                  if (isLocalArchive)
                    BottomSelectButton(
                      icon: Icon(Broken.trash, color: color),
                      onPressed: () {
                        final selectedChapters = ref.read(
                          chaptersListStateProvider,
                        );
                        final totalChapters = widget.manga!.chapters.length;
                        final isLastChapters =
                            selectedChapters.length == totalChapters;
                        final isAnime = widget.itemType == ItemType.anime;
                        final entryType = isAnime ? l10n.episode : l10n.chapter;
                        final pluralEntryType = isAnime
                            ? l10n.episodes
                            : l10n.chapters;
                        final mediaType = isAnime ? l10n.watch : l10n.manga;
                        final warningMessage = l10n.last_entry_delete_warning(
                          totalChapters,
                          entryType,
                          pluralEntryType,
                          mediaType,
                        );
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(l10n.delete_chapters),
                              content: isLastChapters
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Broken.warning_2,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            warningMessage,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                              actions: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text(l10n.cancel),
                                    ),
                                    const SizedBox(width: 15),
                                    TextButton(
                                      onPressed: () async {
                                        final navigator = Navigator.of(context);
                                        await isar.writeTxn(() async {
                                          final idsToDelete = selectedChapters
                                              .map((c) => c.id!)
                                              .toList();
                                          await isar.chapters.deleteAll(
                                            idsToDelete,
                                          );
                                        });
                                        if (!mounted) return;
                                        ref
                                            .read(
                                              isLongPressedStateProvider
                                                  .notifier,
                                            )
                                            .update(false);
                                        ref
                                            .read(
                                              chaptersListStateProvider
                                                  .notifier,
                                            )
                                            .clear();
                                        navigator.pop();
                                        if (isLastChapters) {
                                          navigator.pop();
                                          Future.delayed(
                                            const Duration(milliseconds: 350),
                                            () {
                                              isar.writeTxn(
                                                () => isar.mangas.delete(
                                                  widget.manga!.id!,
                                                ),
                                              );
                                            },
                                          );
                                        }
                                      },
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Contenu du panneau de filtre des chapitres, rendu dans la même bulle de
  /// verre que la bibliothèque et la recherche (AdaptiveOverlayMenuButton).
  Widget _chapterFilterMenu(VoidCallback close) {
    final manga = widget.manga!;
    final mangaId = manga.id!;
    return Consumer(
            builder: (context, ref, child) {
              final l10n = l10nLocalizations(context)!;
              final scanlators = ref.watch(scanlatorsFilterStateProvider(manga));
              final downloaded = ref.watch(
                chapterFilterDownloadedStateProvider(mangaId: mangaId),
              );
              final unread = ref.watch(
                chapterFilterUnreadStateProvider(mangaId: mangaId),
              );
              final bookmarked = ref.watch(
                chapterFilterBookmarkedStateProvider(mangaId: mangaId),
              );
              final sort = ref.watch(
                sortChapterStateProvider(mangaId: mangaId),
              );
              final sortIndices = <int>[
                if (scanlators.$1.isNotEmpty) 0,
                1,
                2,
                3,
              ];
              final sortPosition = sortIndices.indexOf(sort.index ?? 1);
              final initialSortPosition = sortPosition < 0 ? 0 : sortPosition;
              final initialSortDirection = !(sort.reverse ?? false);
              final sortOptions = sortIndices
                  .map(
                    (index) => SelectFilterOption(
                      _getSortNameByIndex(index, context),
                      index.toString(),
                      'SelectOption',
                    ),
                  )
                  .toList();
              final filterList = <dynamic>[
                HeaderFilter(l10n.filter, 'HeaderFilter'),
                if (!isLocalArchive)
                  TriStateFilter(
                    'downloaded',
                    l10n.downloaded,
                    '',
                    'TriState',
                    state: downloaded,
                  ),
                TriStateFilter(
                  'unread',
                  widget.itemType != ItemType.anime
                      ? l10n.unread
                      : l10n.unwatched,
                  '',
                  'TriState',
                  state: unread,
                ),
                TriStateFilter(
                  'bookmarked',
                  l10n.bookmarked,
                  '',
                  'TriState',
                  state: bookmarked,
                ),
                if (scanlators.$1.isNotEmpty)
                  GroupFilter(
                    'scanlators',
                    l10n.filter_scanlator_groups,
                    scanlators.$1
                        .map(
                          (name) => CheckBoxFilter(
                            'scanlator',
                            name,
                            name,
                            'CheckBox',
                            state: scanlators.$3.contains(name),
                          ),
                        )
                        .toList(),
                    'GroupFilter',
                  ),
                SeparatorFilter('SeparatorFilter'),
                HeaderFilter(l10n.sort, 'HeaderFilter'),
                SortFilter(
                  'sortChapter',
                  l10n.sort,
                  SortState(
                    initialSortPosition,
                    initialSortDirection,
                    'SortState',
                  ),
                  sortOptions,
                  'SortFilter',
                ),
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdaptiveOverlaySection(title: l10n.filter),
                  FilterWidget(
                      filterList: filterList,
                      onChanged: (changedFilters) {
                        for (final filter
                            in changedFilters.whereType<TriStateFilter>()) {
                          switch (filter.type) {
                            case 'downloaded':
                              if (filter.state != downloaded) {
                                ref
                                    .read(
                                      chapterFilterDownloadedStateProvider(
                                        mangaId: mangaId,
                                      ).notifier,
                                    )
                                    .setType(filter.state);
                              }
                              break;
                            case 'unread':
                              if (filter.state != unread) {
                                ref
                                    .read(
                                      chapterFilterUnreadStateProvider(
                                        mangaId: mangaId,
                                      ).notifier,
                                    )
                                    .setType(filter.state);
                              }
                              break;
                            case 'bookmarked':
                              if (filter.state != bookmarked) {
                                ref
                                    .read(
                                      chapterFilterBookmarkedStateProvider(
                                        mangaId: mangaId,
                                      ).notifier,
                                    )
                                    .setType(filter.state);
                              }
                              break;
                          }
                        }

                        for (final group
                            in changedFilters.whereType<GroupFilter>()) {
                          if (group.type != 'scanlators') continue;
                          final selected = group.state
                              .whereType<CheckBoxFilter>()
                              .where((filter) => filter.state)
                              .map((filter) => filter.value)
                              .toSet();
                          final draft = Set<String>.from(
                            ref.read(scanlatorsFilterStateProvider(manga)).$3,
                          );
                          final notifier = ref.read(
                            scanlatorsFilterStateProvider(manga).notifier,
                          );
                          for (final name in scanlators.$1) {
                            final wasSelected = draft.contains(name);
                            final isSelected = selected.contains(name);
                            if (wasSelected == isSelected) continue;
                            notifier.setFilteredList(name);
                            if (isSelected) {
                              draft.add(name);
                            } else {
                              draft.remove(name);
                            }
                          }
                        }

                        for (final filter
                            in changedFilters.whereType<SortFilter>()) {
                          final positionChanged =
                              filter.state.index != initialSortPosition;
                          final directionChanged =
                              filter.state.ascending != initialSortDirection;
                          if (!positionChanged && !directionChanged) continue;
                          if (filter.state.index < 0 ||
                              filter.state.index >= sortIndices.length) {
                            continue;
                          }
                          ref
                              .read(
                                sortChapterStateProvider(
                                  mangaId: mangaId,
                                ).notifier,
                              )
                              .set(sortIndices[filter.state.index]);
                        }
                      },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      children: [
                        if (scanlators.$1.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(
                                    scanlatorsFilterStateProvider(
                                      manga,
                                    ).notifier,
                                  )
                                  .set([]);
                            },
                            child: Text(l10n.reset),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: close,
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            if (scanlators.$1.isNotEmpty) {
                              final draft = ref
                                  .read(scanlatorsFilterStateProvider(manga))
                                  .$3;
                              ref
                                  .read(
                                    scanlatorsFilterStateProvider(
                                      manga,
                                    ).notifier,
                                  )
                                  .set(draft);
                            }
                            close();
                          },
                          child: Text(l10n.filter),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
  }

  String _getSortNameByIndex(int index, BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    if (index == 0) {
      return l10n.by_scanlator;
    } else if (index == 1) {
      return widget.itemType != ItemType.anime
          ? l10n.by_chapter_number
          : l10n.by_episode_number;
    } else if (index == 2) {
      return l10n.by_upload_date;
    }
    return l10n.by_name;
  }

  Widget _bodyContainer({required int chapterLength}) {
    final l10n = l10nLocalizations(context)!;
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.05),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: const [0, .3],
            ),
          ),
        ),
        Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: context.width(1),
                  child: Row(
                    children: [
                      _coverCard(),
                      Expanded(child: _titles()),
                    ],
                  ),
                ),
                if (isLocalArchive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: () {
                        _editLocalArchiveInfos();
                      },
                      icon: const CircleAvatar(
                        child: Icon(Broken.edit_2),
                      ),
                    ),
                  ),
              ],
            ),
            _actionFavouriteAndWebview(),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isLoading)
                    // Description : squelette aux mêmes marges que
                    // ReadMoreWidget (Padding 8 puis horizontal 6).
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: DetailDescriptionSkeleton(),
                    )
                  else if (widget.manga!.description != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ReadMoreWidget(
                        text: widget.manga!.description!,
                        onChanged: (value) {
                          setState(() {
                            _expanded = value;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Onglets avec séparation basse et indicateur animé.
                  _DetailTabs(
                    isLoading: widget.isLoading,
                    controller: _sectionController,
                    onSelect: (s) {
                      if (_detailSection != s) {
                        setState(() => _detailSection = s);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (widget.manga!.itemType == ItemType.anime)
                    SizedBox(
                      width: context.width(1),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OutlinedButton.icon(
                          style: ButtonStyle(
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                          ),
                          onPressed: () {
                            context.push(
                              "/watchOrder",
                              extra: (widget.manga!.name, null),
                            );
                          },
                          label: Text(l10n.watch_order),
                          icon: Icon(Broken.arrow_right_2),
                        ),
                      ),
                    ),
                  if (widget.manga!.itemType == ItemType.anime)
                    StreamBuilder(
                      stream: isar.tracks
                          .filter()
                          .mangaIdEqualTo(widget.manga!.id!)
                          .watch(fireImmediately: true),
                      builder: (context, snapshot) {
                        List<Track>? trackRes = snapshot.hasData
                            ? snapshot.data
                            : [];
                        final isNotSupported =
                            trackRes?.firstOrNull?.syncId !=
                                TrackerProviders.myAnimeList.syncId &&
                            trackRes?.firstOrNull?.syncId !=
                                TrackerProviders.anilist.syncId;
                        if ((trackRes?.isEmpty ?? true) || (isNotSupported)) {
                          return Container();
                        }
                        return Column(
                          children: [
                            const SizedBox(height: 15),
                            SizedBox(
                              width: context.width(1),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: OutlinedButton.icon(
                                  style: ButtonStyle(
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          30.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    context.push(
                                      "/watchOrder",
                                      extra: (
                                        widget.manga!.name,
                                        trackRes?.firstOrNull,
                                      ),
                                    );
                                  },
                                  label: Text(l10n.sequels),
                                  icon: Icon(Broken.arrow_right_2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 15),
                  if (!context.isTablet && _detailSection == _DetailSection.chapters)
                    Column(
                      children: [
                        //Description
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: isLocalArchive
                                ? MainAxisAlignment.spaceBetween
                                : MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  widget.manga!.itemType != ItemType.anime
                                      ? l10n.n_chapters(chapterLength)
                                      : l10n.n_episodes(chapterLength),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isLocalArchive)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  icon: Icon(
                                    Broken.add,
                                    color: context.secondaryColor,
                                  ),
                                  label: Text(
                                    widget.manga!.itemType != ItemType.anime
                                        ? l10n.add_chapters
                                        : l10n.add_episodes,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.secondaryColor,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final manga = widget.manga;
                                    if (manga!.source == "torrent") {
                                      addTorrent(context, manga: manga);
                                    } else {
                                      final splitChapters =
                                          manga.itemType == ItemType.novel
                                          ? await _showSplitChaptersDialog(
                                              context,
                                            )
                                          : true;
                                      if (!context.mounted) return;
                                      await ref.watch(
                                        importArchivesFromFileProvider(
                                          itemType: manga.itemType,
                                          manga,
                                          init: false,
                                          splitChapters: splitChapters,
                                        ).future,
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (chapterLength == 0)
              Container(
                width: context.width(1),
                height: context.height(1),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
          ],
        ),
      ],
    );
  }

  Widget _coverCard() {
    final isCustomCover = widget.manga!.customCoverImage != null;
    final imageProvider = isCustomCover
        ? MemoryImage(widget.manga!.customCoverImage as Uint8List)
              as ImageProvider
        : CustomExtendedNetworkImageProvider(
            toImgUrl(
              widget.manga!.customCoverFromTracker ??
                  widget.manga!.imageUrl ??
                  "",
            ),
            headers: widget.manga!.isLocalArchive!
                ? null
                : ref.watch(
                    headersProvider(
                      source: widget.manga!.source!,
                      lang: widget.manga!.lang!,
                      sourceId: widget.manga!.sourceId,
                    ),
                  ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
      child: GestureDetector(
        onTap: () {
          _openImage(imageProvider);
        },
        child: SizedBox(
          width: 65 * 1.5,
          height: 65 * 2.3,
          // La cover affiche un shimmer détaillé tant que l'image n'est pas
          // décodée, puis l'image apparaît en fondu.
          child: DetailShimmerImage(
            imageProvider: imageProvider,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            placeholderBuilder: (context) => const _CoverShimmer(),
          ),
        ),
      ),
    );
  }

  Widget _titles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          // Même encombrement que le vrai titre (fontSize 20).
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: DetailShimmerBox(width: 180, height: 24, radius: 6),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Un appui sur le nom copie le titre dans le presse-papiers.
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: widget.manga!.name!),
              );
              if (!mounted) return;
              botToast(l10nLocalizations(context)!.copied_to_clipboard);
            },
            child: Text(
              widget.manga!.name!,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        widget.titleDescription!,
      ],
    );
  }

  Widget _actionFavouriteAndWebview() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: widget.action!),
          if (!isLocalArchive) Expanded(child: _smartUpdateDays()),
          _action(),
          if (!isLocalArchive)
            Expanded(
              child: SizedBox(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final manga = widget.manga!;

                    final source = getSource(
                      widget.manga!.lang!,
                      widget.manga!.source!,
                      widget.manga!.sourceId,
                    );
                    if (source == null) return;
                    final url =
                        "${source.baseUrl}${widget.manga!.link!.getUrlWithoutDomain}";

                    Map<String, dynamic> data = {
                      'url': url,
                      'sourceId': source.id.toString(),
                      'title': manga.name!,
                    };
                    context.push("/mangawebview", extra: data);
                  },
                  child: widget.isLoading
                      ? const DetailActionButtonSkeleton(labelWidth: 48)
                      : Column(
                          children: [
                            Icon(
                              Broken.global,
                              size: 20,
                              color: context.secondaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.webview,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smartUpdateDays() {
    return SizedBox(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
        ),
        onPressed: () =>
            context.push("/calendarScreen", extra: widget.manga!.itemType),
        // Pendant le chargement : même contenu (icône 20 + libellé 11) que le
        // bouton réel, inséré dans le VRAI ElevatedButton — le chrome, les
        // marges et la position du bouton sont donc identiques.
        child: widget.isLoading
            ? const DetailActionButtonSkeleton(labelWidth: 52)
            : Column(
                children: [
                  Icon(
                    Broken.timer,
                    size: 20,
                    color: context.secondaryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.manga?.smartUpdateDays != null
                        ? context.l10n.n_days(widget.manga!.smartUpdateDays!)
                        : "N/A",
                    style: TextStyle(
                      fontSize: 11,
                      color: context.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  /// Tracker button
  Widget _action() {
    return StreamBuilder(
      stream: isar.trackPreferences.filter().syncIdIsNotNull().watch(
        fireImmediately: true,
      ),
      builder: (context, snapshot) {
        List<TrackPreference>? entries = snapshot.hasData ? snapshot.data! : [];
        if (entries.isEmpty) {
          return SizedBox.shrink();
        }
        return Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
            ),
            onPressed: () {
              _trackingDraggableMenu(entries);
            },
            child: StreamBuilder(
              stream: isar.tracks
                  .filter()
                  .mangaIdEqualTo(widget.manga!.id!)
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (widget.isLoading) {
                  // Squelette : même contenu (icône 20 + libellé 11) que le
                  // bouton traceurs, dans le VRAI ElevatedButton.
                  return const DetailActionButtonSkeleton(labelWidth: 44);
                }
                final l10n = l10nLocalizations(context)!;
                List<Track>? trackRes = snapshot.hasData ? snapshot.data : [];
                bool isNotEmpty = trackRes!.isNotEmpty;
                Color color = isNotEmpty
                    ? context.primaryColor
                    : context.secondaryColor;
                return Column(
                  children: [
                    Icon(
                      isNotEmpty ? Broken.tick_circle : Broken.refresh,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isNotEmpty
                          ? trackRes.length == 1
                                ? l10n.one_tracker
                                : l10n.n_tracker(trackRes.length)
                          : l10n.tracking,
                      style: TextStyle(fontSize: 11, color: color),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openImage(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: PhotoViewGallery.builder(
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  itemCount: 1,
                  builder: (context, index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: imageProvider,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: 2.0,
                    );
                  },
                  loadingBuilder: (context, event) {
                    return const ProgressCenter();
                  },
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: StreamBuilder(
                        stream: isar.trackPreferences
                            .filter()
                            .syncIdIsNotNull()
                            .watch(fireImmediately: true),
                        builder: (context, snapshot) {
                          List<TrackPreference>? entries = snapshot.hasData
                              ? snapshot.data!
                              : [];
                          if (entries.isEmpty) {
                            return Container();
                          }
                          return Column(
                            children: entries
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: MaterialButton(
                                      padding: const EdgeInsets.all(0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      onPressed: () async {
                                        final trackSearch =
                                            await trackersSearchDraggableMenu(
                                                  context,
                                                  itemType:
                                                      widget.manga!.itemType,
                                                  track: Track(
                                                    status:
                                                        TrackStatus.planToRead,
                                                    syncId: e.syncId!,
                                                    title: widget.manga!.name!,
                                                  ),
                                                )
                                                as TrackSearch?;
                                        if (trackSearch != null) {
                                          isar.writeTxnSync(() {
                                            isar.mangas.putSync(
                                              widget.manga!
                                                ..customCoverImage = null
                                                ..customCoverFromTracker =
                                                    trackSearch.coverUrl
                                                ..updatedAt = DateTime.now()
                                                    .millisecondsSinceEpoch,
                                            );
                                          });
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            botToast(
                                              context.l10n.cover_updated,
                                              second: 3,
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          color: trackInfos(e.syncId!).$3,
                                        ),
                                        width: 45,
                                        height: 50,
                                        child: Image.asset(
                                          trackInfos(e.syncId!).$1,
                                          height: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: context.width(1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: context.isLight
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Broken.close_circle),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: context.isLight
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final bytes = await imageProvider
                                          .getBytes(context);
                                      if (bytes != null) {
                                        await SharePlus.instance.share(
                                          ShareParams(
                                            files: [
                                              XFile.fromData(
                                                bytes,
                                                name: widget.manga!.name,
                                                mimeType: 'image/png',
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Broken.export),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final dir = await StorageProvider()
                                          .getGalleryDirectory();
                                      if (context.mounted) {
                                        final bytes = await imageProvider
                                            .getBytes(context);
                                        if (bytes != null && context.mounted) {
                                          final file = File(
                                            p.join(
                                              dir!.path,
                                              "${widget.manga!.name}.png",
                                            ),
                                          );
                                          file.writeAsBytesSync(bytes);
                                          botToast(
                                            context.l10n.cover_saved,
                                            second: 3,
                                          );
                                        }
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Broken.save_2),
                                    ),
                                  ),
                                  ArrowPopupMenuButton(
                                    popUpAnimationStyle: popupAnimationStyle,
                                    itemBuilder: (context) {
                                      return [
                                        if (widget.manga!.customCoverImage !=
                                                null ||
                                            widget
                                                    .manga!
                                                    .customCoverFromTracker !=
                                                null)
                                          PopupMenuItem<int>(
                                            value: 0,
                                            child: Text(context.l10n.delete),
                                          ),
                                        PopupMenuItem<int>(
                                          value: 1,
                                          child: Text(context.l10n.edit),
                                        ),
                                      ];
                                    },
                                    onSelected: (value) async {
                                      final manga = widget.manga!;
                                      if (value == 0) {
                                        isar.writeTxnSync(() {
                                          isar.mangas.putSync(
                                            manga
                                              ..customCoverImage = null
                                              ..customCoverFromTracker = null
                                              ..updatedAt = DateTime.now()
                                                  .millisecondsSinceEpoch,
                                          );
                                        });
                                        Navigator.pop(context);
                                      } else if (value == 1) {
                                        FilePickerResult? result =
                                            await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'png',
                                                'jpg',
                                                'jpeg',
                                              ],
                                            );
                                        if (result != null && context.mounted) {
                                          if (result.files.first.size <
                                              5000000) {
                                            final customCoverImage = File(
                                              result.files.first.path!,
                                            ).readAsBytesSync();
                                            isar.writeTxnSync(() {
                                              isar.mangas.putSync(
                                                manga
                                                  ..customCoverImage =
                                                      customCoverImage
                                                  ..updatedAt = DateTime.now()
                                                      .millisecondsSinceEpoch,
                                              );
                                            });
                                            botToast(
                                              context.l10n.cover_updated,
                                              second: 3,
                                            );
                                          }
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Broken.edit_2,
                                        color: !context.isLight
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  void _editLocalArchiveInfos() {
    final l10n = l10nLocalizations(context)!;
    TextEditingController? name = TextEditingController(
      text: widget.manga!.name!,
    );
    TextEditingController? description = TextEditingController(
      text: widget.manga!.description!,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.edit),
          content: SizedBox(
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Text(l10n.name),
                      ),
                      TextFormField(controller: name),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Text(l10n.description),
                      ),
                      TextFormField(controller: description),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 15),
                TextButton(
                  onPressed: () {
                    isar.writeTxnSync(() {
                      final manga = widget.manga!;
                      manga.description = description.text;
                      manga.name = name.text;
                      manga.updatedAt = DateTime.now().millisecondsSinceEpoch;
                      isar.mangas.putSync(manga);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(l10n.edit),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _trackingDraggableMenu(List<TrackPreference>? entries) {
    DraggableMenu.open(
      context,
      Consumer(
        builder: (context, ref, _) {
          final isPureBlack = ref.watch(pureBlackDarkModeStateProvider);
          final theme = Theme.of(context);
          final bgColor = context.isLight || !isPureBlack
              ? theme.scaffoldBackgroundColor.withValues(alpha: 0.9)
              : theme.cardColor;

          return DraggableMenu(
            ui: ClassicDraggableMenu(
              radius: 20,
              barItem: Container(),
              color: theme.scaffoldBackgroundColor,
            ),
            allowToShrink: true,
            child: Material(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SuperListView.separated(
                  padding: const EdgeInsets.all(0),
                  itemCount: entries!.length,
                  primary: false,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    return StreamBuilder(
                      stream: isar.tracks
                          .filter()
                          .syncIdEqualTo(entries[index].syncId)
                          .mangaIdEqualTo(widget.manga!.id!)
                          .watch(fireImmediately: true),
                      builder: (context, snapshot) {
                        List<Track>? trackRes = snapshot.hasData
                            ? snapshot.data
                            : [];
                        return trackRes!.isNotEmpty
                            ? TrackerWidget(
                                mangaId: widget.manga!.id!,
                                syncId: entries[index].syncId!,
                                trackRes: trackRes.first,
                                itemType: widget.manga!.itemType,
                              )
                            : TrackListile(
                                text: l10nLocalizations(context)!.add_tracker,
                                onTap: () async {
                                  final trackSearch =
                                      await trackersSearchDraggableMenu(
                                            context,
                                            itemType: widget.manga!.itemType,
                                            track: Track(
                                              status: TrackStatus.planToRead,
                                              syncId: entries[index].syncId!,
                                              title: widget.manga!.name!,
                                            ),
                                          )
                                          as TrackSearch?;
                                  if (trackSearch != null) {
                                    await ref
                                        .read(
                                          trackStateProvider(
                                            track: null,
                                            itemType: widget.manga!.itemType,
                                            widgetRef: ref,
                                          ).notifier,
                                        )
                                        .setTrackSearch(
                                          trackSearch,
                                          widget.manga!.id!,
                                          entries[index].syncId!,
                                        );
                                  }
                                },
                                id: entries[index].syncId!,
                                entries: const [],
                              );
                      },
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<bool> _showSplitChaptersDialog(BuildContext context) async {
  final l10n = l10nLocalizations(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.split_epub_chapters),
          content: Text(l10n.split_epub_chapters_description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.split_epub_chapters),
            ),
          ],
        ),
      ) ??
      true;
}

// ── Detail section tabs ──────────────────────────────────────────────────────

/// Onglets de la page de détail avec une ligne continue en bas et un indicateur
/// animé sous l'onglet actif.
class _DetailTabs extends StatelessWidget {
  final TabController controller;
  final ValueChanged<_DetailSection> onSelect;

  /// Pendant le chargement, le contenu de chaque onglet (icône + libellé) est
  /// remplacé par des blocs shimmer : la barre garde exactement sa géométrie
  /// réelle (hauteur 44, icône 15, écart 6, libellé 13) et sa position.
  final bool isLoading;

  const _DetailTabs({
    required this.controller,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = [
      (
        section: _DetailSection.chapters,
        label: 'Chapitres',
        labelWidth: 62.0,
        icon: Broken.document_text,
      ),
      (
        section: _DetailSection.similar,
        label: 'Similar',
        labelWidth: 45.0,
        icon: Broken.star,
      ),
      (
        section: _DetailSection.comments,
        label: 'Commentaires',
        labelWidth: 78.0,
        icon: Broken.message,
      ),
    ];

    return TabBar(
        controller: controller,
        onTap: (index) => onSelect(_DetailSection.values[index]),
        isScrollable: false,
        // Indicateur fin sous l'onglet actif
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3,
            color: scheme.primary,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 26),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        // Ligne de séparation en bas, sur toute la largeur
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.55),
        dividerHeight: 1,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.zero,
        splashBorderRadius: BorderRadius.zero,
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06),
        ),
        tabs: [
          for (final tab in tabs)
            Tab(
              height: DetailSkeletonMetrics.tabHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const DetailShimmerBox(
                      width: DetailSkeletonMetrics.tabIconSize,
                      height: DetailSkeletonMetrics.tabIconSize,
                      radius: 4,
                    )
                  else
                    Icon(tab.icon, size: DetailSkeletonMetrics.tabIconSize),
                  const SizedBox(width: DetailSkeletonMetrics.tabGap),
                  if (isLoading)
                    Flexible(
                      child: DetailShimmerBox(
                        width: tab.labelWidth,
                        height: DetailSkeletonMetrics.tabLabelHeight,
                        radius: 4,
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
        ],
    );
  }
}

// ── Cover shimmer ────────────────────────────────────────────────────────────

/// Squelette détaillé de la cover : bloc shimmer + voile bas + glyphe image,
/// affiché tant que la vraie jaquette n'est pas décodée.
class _CoverShimmer extends StatelessWidget {
  const _CoverShimmer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DetailShimmerBox(radius: 5),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(5),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.22),
                ],
              ),
            ),
          ),
        ),
        const Center(
          child: Icon(Broken.image, size: 26, color: Colors.white70),
        ),
      ],
    );
  }
}
