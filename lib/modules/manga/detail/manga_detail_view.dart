import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';
import 'package:draggable_menu/draggable_menu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
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
import 'package:watchtower/modules/widgets/custom_draggable_tabbar.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/others.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/detail/widgets/readmore.dart';
import 'package:watchtower/modules/manga/detail/widgets/chapter_filter_list_tile_widget.dart';
import 'package:watchtower/modules/manga/detail/widgets/chapter_list_tile_widget.dart';
import 'package:watchtower/modules/manga/detail/widgets/chapter_sort_list_tile_widget.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../../../utils/constant.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/manga/detail/widgets/detail_skeletons.dart';
import 'package:watchtower/modules/widgets/comments_section.dart';
import 'package:watchtower/services/recommendation.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

enum _DetailSection { chapters, details, similar }

class MangaDetailView extends ConsumerStatefulWidget {
  final Function(bool) isExtended;
  final Manga? manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;
  final ItemType itemType;

  const MangaDetailView({
    super.key,
    required this.isExtended,
    required this.sourceExist,
    required this.manga,
    required this.checkForUpdate,
    required this.itemType,
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  final _scrollOffset = ValueNotifier<double>(0.0);
  _DetailSection _detailSection = _DetailSection.chapters;
  late final ScrollController _scrollController;
  late final isLocalArchive = widget.manga?.isLocalArchive ?? false;

  /// Lazily fetched AniList recommendations backing the Similar section.
  Future<List<RecommendationResult>?>? _similarFuture;
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

  List<Chapter> _filterAndSortChapter({
    required List<Chapter> data,
    required int filterUnread,
    required int filterBookmarked,
    required int filterDownloaded,
    required int sortChapter,
    required List<String> filterScanlator,
  }) {
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
          final modelChapDownload = isar.downloads
              .filter()
              .idEqualTo(element.id)
              .findAllSync();
          return filterDownloaded == 1
              ? modelChapDownload.isNotEmpty &&
                    modelChapDownload.first.isDownload == true
              : filterDownloaded == 2
              ? !(modelChapDownload.isNotEmpty &&
                    modelChapDownload.first.isDownload == true)
              : true;
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
    final showChapters = _detailSection == _DetailSection.chapters;
    final itemCount = showChapters ? chapters.length + 2 : 3;
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
                      builder: (context, ref, child) => Stack(
                        children: [
                          widget.manga!.customCoverImage != null
                              ? Image.memory(
                                  widget.manga!.customCoverImage as Uint8List,
                                  width: context.width(1),
                                  height: 300,
                                  fit: BoxFit.cover,
                                )
                              : cachedNetworkImage(
                                  headers: isLocalArchive
                                      ? null
                                      : ref.watch(
                                          headersProvider(
                                            source: widget.manga!.source!,
                                            lang: widget.manga!.lang!,
                                            sourceId: widget.manga!.sourceId,
                                          ),
                                        ),
                                  imageUrl: toImgUrl(
                                    widget.manga!.customCoverFromTracker ??
                                        widget.manga!.imageUrl ??
                                        "",
                                  ),
                                  width: context.width(1),
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
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
                            icon: const Icon(Icons.clear),
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
                              icon: const Icon(Icons.select_all),
                            ),
                            IconButton(
                              onPressed: () {
                                if (chapters.length == chapterList.length) {
                                  for (var chapter in chapters) {
                                    ref
                                        .read(
                                          chaptersListStateProvider.notifier,
                                        )
                                        .selectSome(chapter);
                                  }
                                  ref
                                      .read(isLongPressedStateProvider.notifier)
                                      .update(false);
                                } else {
                                  for (var chapter in chapters) {
                                    ref
                                        .read(
                                          chaptersListStateProvider.notifier,
                                        )
                                        .selectSome(chapter);
                                  }
                                }
                              },
                              icon: const Icon(Icons.flip_to_back_rounded),
                            ),
                          ],
                        ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: _scrollOffset,
                        builder: (context, offset, _) => AppBar(
                          leading: IconButton(
                            splashRadius: 20,
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                Navigator.maybePop(context);
                              }
                            },
                            icon: const Icon(Broken.arrow_left, size: 26),
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
                              ArrowPopupMenuButton(
                                padding: const EdgeInsets.all(12),
                                popUpAnimationStyle: popupAnimationStyle,
                                icon: const Icon(Icons.download_outlined),
                                itemBuilder: (context) {
                                  return [
                                    PopupMenuItem<int>(
                                      value: 0,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.next_chapter
                                            : context.l10n.next_episode,
                                      ),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 1,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.next_5_chapters
                                            : context.l10n.next_5_episodes,
                                      ),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 2,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.next_10_chapters
                                            : context.l10n.next_10_episodes,
                                      ),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 3,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.next_25_chapters
                                            : context.l10n.next_25_episodes,
                                      ),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 4,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.unread
                                            : context.l10n.unwatched,
                                      ),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 5,
                                      child: Text(
                                        widget.itemType != ItemType.anime
                                            ? context.l10n.all_chapters
                                            : context.l10n.all_episodes,
                                      ),
                                    ),
                                  ];
                                },
                                onSelected: (value) {
                                  final chapters =
                                      _getFilteredAndSortedChapters();
                                  if (value == 0 ||
                                      value == 1 ||
                                      value == 2 ||
                                      value == 3) {
                                    final lastChapterReadIndex = chapters
                                        .lastIndexWhere(
                                          (element) => element.isRead == true,
                                        );
                                    if (lastChapterReadIndex == -1 ||
                                        chapters.length == 1) {
                                      final chapter = chapters.first;
                                      final entry = isar.downloads
                                          .filter()
                                          .idEqualTo(chapter.id)
                                          .findFirstSync();
                                      if (entry == null || !entry.isDownload!) {
                                        ref.watch(
                                          addDownloadToQueueProvider(
                                            chapter: chapter,
                                          ),
                                        );
                                        ref.watch(processDownloadsProvider());
                                      }
                                    } else {
                                      final length = switch (value) {
                                        0 => 1,
                                        1 => 5,
                                        2 => 10,
                                        _ => 25,
                                      };
                                      for (var i = 1; i < length + 1; i++) {
                                        if (chapters.length > 1 &&
                                            chapters.elementAtOrNull(
                                                  lastChapterReadIndex + i,
                                                ) !=
                                                null) {
                                          final chapter =
                                              chapters[lastChapterReadIndex +
                                                  i];
                                          final entry = isar.downloads
                                              .filter()
                                              .idEqualTo(chapter.id)
                                              .findFirstSync();
                                          if (entry == null ||
                                              !entry.isDownload!) {
                                            ref.watch(
                                              addDownloadToQueueProvider(
                                                chapter: chapter,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      ref.watch(processDownloadsProvider());
                                    }
                                  } else if (value == 4) {
                                    final List<Chapter> unreadChapters =
                                        _getFilteredAndSortedChapters()
                                            .where(
                                              (element) =>
                                                  !(element.isRead ?? false),
                                            )
                                            .toList();
                                    isar.chapters
                                        .filter()
                                        .mangaIdEqualTo(widget.manga!.id!)
                                        .isReadEqualTo(false)
                                        .findAllSync();
                                    for (var chapter in unreadChapters) {
                                      final entry = isar.downloads
                                          .filter()
                                          .idEqualTo(chapter.id)
                                          .findFirstSync();
                                      if (entry == null || !entry.isDownload!) {
                                        ref.watch(
                                          addDownloadToQueueProvider(
                                            chapter: chapter,
                                          ),
                                        );
                                      }
                                    }
                                    ref.watch(processDownloadsProvider());
                                  } else if (value == 5) {
                                    final List<Chapter> allChapters =
                                        _getFilteredAndSortedChapters();
                                    for (var chapter in allChapters) {
                                      final entry = isar.downloads
                                          .filter()
                                          .idEqualTo(chapter.id)
                                          .findFirstSync();
                                      if (entry == null || !entry.isDownload!) {
                                        ref.watch(
                                          addDownloadToQueueProvider(
                                            chapter: chapter,
                                          ),
                                        );
                                      }
                                    }
                                    ref.watch(processDownloadsProvider());
                                  }
                                },
                              ),
                            ],
                            IconButton(
                              splashRadius: 20,
                              onPressed: () {
                                _showDraggableMenu();
                              },
                              icon: Icon(
                                Broken.filter,
                                size: 22,
                                color: isNotFiltering ? null : Colors.yellow,
                              ),
                            ),
                            IconButton(
                              splashRadius: 20,
                              onPressed: _shareManga,
                              icon: const Icon(Broken.share, size: 22),
                            ),
                            ArrowPopupMenuButton(
                              padding: const EdgeInsets.all(12),
                              popUpAnimationStyle: popupAnimationStyle,
                              itemBuilder: (context) {
                                return [
                                  if (!isLocalArchive)
                                    PopupMenuItem<int>(
                                      value: 0,
                                      child: Text(l10n.refresh),
                                    ),
                                  if (widget.manga!.favorite! &&
                                      checkCategoryList)
                                    PopupMenuItem<int>(
                                      value: 1,
                                      child: Text(l10n.set_categories),
                                    ),
                                  if (!isLocalArchive)
                                    PopupMenuItem<int>(
                                      value: 2,
                                      child: Text(l10n.share),
                                    ),
                                  PopupMenuItem<int>(
                                    value: 3,
                                    child: Text(l10n.migrate),
                                  ),
                                  PopupMenuItem<int>(
                                    value: 6,
                                    child: const Text('Mass migration'),
                                  ),
                                  if (!isLocalArchive)
                                    PopupMenuItem<int>(
                                      value: 4,
                                      child: Text(l10n.extension_settings),
                                    ),
                                  PopupMenuItem<int>(
                                    value: 5,
                                    child: Text(l10n.export_metadata),
                                  ),
                                  if (!isLocalArchive &&
                                      widget.manga!.link != null)
                                    PopupMenuItem<int>(
                                      value: 7,
                                      child: Text(l10n.webview),
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
                                    _shareManga();
                                    break;
                                  case 7:
                                    _openWebView();
                                    break;
                                  case 3:
                                    context.push(
                                      "/migrate",
                                      extra: widget.manga,
                                    );
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
                                          widget
                                                  .manga!
                                                  .customCoverFromTracker ??
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
                                            "status":
                                                widget.manga!.status.index,
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
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              final l10n = l10nLocalizations(context)!;
                              int finalIndex = index - 1;
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
                                                      Icons.add,
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
                                                        await ref.watch(
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
                              // Comments always close the page.
                              if (index == itemCount - 1) {
                                return _commentsSection();
                              }
                              if (_detailSection == _DetailSection.details) {
                                return _detailsSection();
                              }
                              if (_detailSection == _DetailSection.similar) {
                                return _similarSection();
                              }
                              int reverseIndex =
                                  chapters.length -
                                  chapters.reversed.toList().indexOf(
                                    chapters.reversed.toList()[finalIndex],
                                  ) -
                                  1;
                              final indexx = reverse
                                  ? reverseIndex
                                  : finalIndex;
                              return ChapterListTileWidget(
                                chapter: chapters[indexx],
                                chapterList: chapterList,
                                allChapters: chapters,
                                sourceExist: widget.sourceExist,
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
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                      color: color,
                    ),
                    onPressed: () {
                      final chapters = ref.watch(chaptersListStateProvider);
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
                          ? Icons.remove_done_sharp
                          : Icons.done_all_sharp,
                      color: color,
                    ),
                    onPressed: () {
                      final chapters = ref.watch(chaptersListStateProvider);
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
                          Icon(Icons.done_outlined, color: color),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Icon(
                              Icons.arrow_downward_outlined,
                              size: 11,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        int index = chapters.indexOf(chap.first);
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
                      icon: Icon(Icons.download_outlined, color: color),
                      onPressed: () {
                        for (var chapter in ref.watch(
                          chaptersListStateProvider,
                        )) {
                          final entries = isar.downloads
                              .filter()
                              .idEqualTo(chapter.id)
                              .findAllSync();
                          if (entries.isEmpty || !entries.first.isDownload!) {
                            ref.read(
                              addDownloadToQueueProvider(chapter: chapter),
                            );
                          }
                        }
                        ref.watch(processDownloadsProvider());

                        ref
                            .read(isLongPressedStateProvider.notifier)
                            .update(false);
                        ref.read(chaptersListStateProvider.notifier).clear();
                      },
                    ),
                  if (isLocalArchive)
                    BottomSelectButton(
                      icon: Icon(Icons.delete_outline_outlined, color: color),
                      onPressed: () {
                        final selectedChapters = ref.watch(
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
                                          Icons.warning_amber_rounded,
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

  void _showDraggableMenu() {
    final scanlators = ref.watch(scanlatorsFilterStateProvider(widget.manga!));
    final l10n = l10nLocalizations(context)!;
    customDraggableTabBar(
      tabs: [
        Tab(text: l10n.filter),
        Tab(text: l10n.sort),
        Tab(text: l10n.display),
      ],
      children: [
        Consumer(
          builder: (context, ref, chil) {
            return Column(
              children: [
                if (!isLocalArchive)
                  ListTileChapterFilter(
                    label: l10n.downloaded,
                    type: ref.watch(
                      chapterFilterDownloadedStateProvider(
                        mangaId: widget.manga!.id!,
                      ),
                    ),
                    onTap: () {
                      ref
                          .read(
                            chapterFilterDownloadedStateProvider(
                              mangaId: widget.manga!.id!,
                            ).notifier,
                          )
                          .update();
                    },
                  ),
                ListTileChapterFilter(
                  label: widget.itemType != ItemType.anime
                      ? l10n.unread
                      : l10n.unwatched,
                  type: ref.watch(
                    chapterFilterUnreadStateProvider(
                      mangaId: widget.manga!.id!,
                    ),
                  ),
                  onTap: () {
                    ref
                        .read(
                          chapterFilterUnreadStateProvider(
                            mangaId: widget.manga!.id!,
                          ).notifier,
                        )
                        .update();
                  },
                ),
                ListTileChapterFilter(
                  label: l10n.bookmarked,
                  type: ref.watch(
                    chapterFilterBookmarkedStateProvider(
                      mangaId: widget.manga!.id!,
                    ),
                  ),
                  onTap: () {
                    ref
                        .read(
                          chapterFilterBookmarkedStateProvider(
                            mangaId: widget.manga!.id!,
                          ).notifier,
                        )
                        .update();
                  },
                ),
                if (scanlators.$1.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return Consumer(
                                    builder: (context, ref, child) {
                                      final scanlators = ref.watch(
                                        scanlatorsFilterStateProvider(
                                          widget.manga!,
                                        ),
                                      );
                                      return AlertDialog(
                                        title: Text(
                                          l10n.filter_scanlator_groups,
                                        ),
                                        content: SizedBox(
                                          width: context.width(0.8),
                                          child: SuperListView.builder(
                                            shrinkWrap: true,
                                            itemCount: scanlators.$1.length,
                                            itemBuilder: (context, index) {
                                              return ListTileChapterFilter(
                                                label: scanlators.$1[index],
                                                type:
                                                    scanlators.$3.contains(
                                                      scanlators.$1[index],
                                                    )
                                                    ? 2
                                                    : 0,
                                                onTap: () {
                                                  ref
                                                      .read(
                                                        scanlatorsFilterStateProvider(
                                                          widget.manga!,
                                                        ).notifier,
                                                      )
                                                      .setFilteredList(
                                                        scanlators.$1[index],
                                                      );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                          Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            ref
                                                                .read(
                                                                  scanlatorsFilterStateProvider(
                                                                    widget
                                                                        .manga!,
                                                                  ).notifier,
                                                                )
                                                                .set([]);
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                          child: Text(
                                                            l10n.reset,
                                                            style: TextStyle(
                                                              color: context
                                                                  .primaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () async {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        child: Text(
                                                          l10n.cancel,
                                                          style: TextStyle(
                                                            color: context
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          ref
                                                              .read(
                                                                scanlatorsFilterStateProvider(
                                                                  widget.manga!,
                                                                ).notifier,
                                                              )
                                                              .set(
                                                                scanlators.$3,
                                                              );
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        child: Text(
                                                          l10n.filter,
                                                          style: TextStyle(
                                                            color: context
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Text(l10n.filter_scanlator_groups),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        Consumer(
          builder: (context, ref, chil) {
            final reverse = ref
                .read(
                  sortChapterStateProvider(mangaId: widget.manga!.id!).notifier,
                )
                .isReverse();
            final scanlators = ref.watch(
              scanlatorsFilterStateProvider(widget.manga!),
            );
            final reverseChapter = ref.watch(
              sortChapterStateProvider(mangaId: widget.manga!.id!),
            );
            return Column(
              children: [
                if (scanlators.$1.isNotEmpty)
                  ListTileChapterSort(
                    label: _getSortNameByIndex(0, context),
                    reverse: reverse,
                    onTap: () {
                      ref
                          .read(
                            sortChapterStateProvider(
                              mangaId: widget.manga!.id!,
                            ).notifier,
                          )
                          .set(0);
                    },
                    showLeading: reverseChapter.index == 0,
                  ),
                for (var i = 1; i < 4; i++)
                  ListTileChapterSort(
                    label: _getSortNameByIndex(i, context),
                    reverse: reverse,
                    onTap: () {
                      ref
                          .read(
                            sortChapterStateProvider(
                              mangaId: widget.manga!.id!,
                            ).notifier,
                          )
                          .set(i);
                    },
                    showLeading: reverseChapter.index == i,
                  ),
              ],
            );
          },
        ),
        Consumer(
          builder: (context, ref, chil) {
            return RadioGroup(
              groupValue: "e",
              onChanged: (value) {},
              child: Column(
                children: [
                  RadioListTile(
                    dense: true,
                    title: Text(l10n.source_title),
                    value: "e",
                    selected: true,
                  ),
                  RadioListTile(
                    dense: true,
                    title: Text(
                      widget.itemType != ItemType.anime
                          ? l10n.chapter_number
                          : l10n.episode_number,
                    ),
                    value: "ej",
                    selected: false,
                  ),
                ],
              ),
            );
          },
        ),
      ],
      context: context,
      vsync: this,
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
            _hero(),
            _detailActions(),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _DetailTabPills(
                    selected: _detailSection,
                    onSelect: (s) => setState(() => _detailSection = s),
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
                          icon: Icon(Icons.arrow_right_alt_outlined),
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
                                  icon: Icon(Icons.arrow_right_alt_outlined),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 15),
                  if (!context.isTablet &&
                      _detailSection == _DetailSection.chapters)
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
                                    Icons.add,
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

  // ── HERO · cover + title / author / status ─────────────────────────────────

  Widget _hero() {
    final l10n = l10nLocalizations(context)!;
    final imageProvider = widget.manga!.customCoverImage != null
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
    final lang = widget.manga!.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 20, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openImage(imageProvider),
            child: SizedBox(
              width: 65 * 1.5,
              height: 65 * 2.3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  widget.manga!.name!,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Broken.user,
                  (widget.manga!.author?.isEmpty ?? true)
                      ? l10n.unknown
                      : widget.manga!.author!,
                ),
                const SizedBox(height: 5),
                _infoRow(
                  getMangaStatusIcon(widget.manga!.status),
                  getMangaStatusName(widget.manga!.status, context),
                ),
                if (lang != null && lang.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _langBadge(lang),
                      if (!isLocalArchive && widget.manga!.source != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.manga!.source!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ],
                      if (!isLocalArchive && !widget.sourceExist)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.warning_amber,
                            color: Colors.deepOrangeAccent,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isLocalArchive)
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
              onPressed: _editLocalArchiveInfos,
              icon: const Icon(Broken.edit, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _langBadge(String lang) {
    final flag = _langFlag(lang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.primaryColor.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
          ],
          Text(
            lang.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIONS · library / follow / tracker ───────────────────────────────────

  Widget _detailActions() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _libraryButton()),
          if (!isLocalArchive) ...[
            const SizedBox(width: 8),
            Expanded(child: _followButton()),
          ],
          if (widget.manga!.itemType == ItemType.anime) ...[
            const SizedBox(width: 8),
            Expanded(child: _trackerButton()),
          ],
        ],
      ),
    );
  }

  /// Add / remove from the library — reuses the existing favourite +
  /// category selection systems.
  Widget _libraryButton() {
    final l10n = l10nLocalizations(context)!;
    final inLibrary = widget.manga!.favorite == true;
    return _ActionTile(
      icon: inLibrary ? Broken.heart_filled : Broken.heart,
      label: inLibrary ? l10n.in_library : l10n.add_to_library,
      active: inLibrary,
      onTap: () {
        final model = widget.manga!;
        if (model.favorite == true) {
          isar.writeTxnSync(() {
            model.favorite = false;
            model.dateAdded = 0;
            model.updatedAt = DateTime.now().millisecondsSinceEpoch;
            isar.mangas.putSync(model);
          });
          return;
        }
        final checkCategoryList = isar.categorys
            .filter()
            .forItemTypeEqualTo(model.itemType)
            .isNotEmptySync();
        if (checkCategoryList) {
          showCategorySelectionDialog(
            context: context,
            ref: ref,
            itemType: model.itemType,
            singleManga: model,
          );
        } else {
          isar.writeTxnSync(() {
            model.favorite = true;
            model.dateAdded = DateTime.now().millisecondsSinceEpoch;
            model.updatedAt = DateTime.now().millisecondsSinceEpoch;
            isar.mangas.putSync(model);
          });
        }
      },
    );
  }

  /// Follow updates — reuses the existing smart-update interval state and the
  /// calendar screen that owns it.
  Widget _followButton() {
    final l10n = l10nLocalizations(context)!;
    final days = widget.manga!.smartUpdateDays;
    final following = days != null && days > 0;
    return _ActionTile(
      icon: following ? Broken.tick_circle : Broken.clock,
      label: following ? l10n.n_days(days) : 'Suivre les mises à jour',
      active: following,
      onTap: () =>
          context.push('/calendarScreen', extra: widget.manga!.itemType),
    );
  }

  /// Tracker button (anime only) — reuses the existing tracking system.
  Widget _trackerButton() {
    return StreamBuilder(
      stream: isar.trackPreferences.filter().syncIdIsNotNull().watch(
        fireImmediately: true,
      ),
      builder: (context, snapshot) {
        final entries = snapshot.hasData ? snapshot.data! : <TrackPreference>[];
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return StreamBuilder(
          stream: isar.tracks
              .filter()
              .mangaIdEqualTo(widget.manga!.id!)
              .watch(fireImmediately: true),
          builder: (context, snapshot) {
            final l10n = l10nLocalizations(context)!;
            final trackRes = snapshot.hasData ? snapshot.data! : <Track>[];
            final isNotEmpty = trackRes.isNotEmpty;
            return _ActionTile(
              icon: isNotEmpty ? Broken.tick_circle : Broken.refresh,
              label: isNotEmpty
                  ? (trackRes.length == 1
                        ? l10n.one_tracker
                        : l10n.n_tracker(trackRes.length))
                  : l10n.tracking,
              active: isNotEmpty,
              onTap: () => _trackingDraggableMenu(entries),
            );
          },
        );
      },
    );
  }

  // ── SECTION · details ─────────────────────────────────────────────────────

  Widget _detailsSection() {
    final l10n = l10nLocalizations(context)!;
    final manga = widget.manga!;
    final genres = manga.genre ?? const <String>[];
    final entries = <(String, String)>[
      (
        'Auteur',
        (manga.author?.isEmpty ?? true) ? l10n.unknown : manga.author!,
      ),
      (
        'Artiste',
        (manga.artist?.isEmpty ?? true) ? l10n.unknown : manga.artist!,
      ),
      (l10n.status, getMangaStatusName(manga.status, context)),
      if (!isLocalArchive) (l10n.source_title, manga.source ?? '—'),
      if (!isLocalArchive && (manga.lang?.isNotEmpty ?? false))
        (l10n.language, manga.lang!.toUpperCase()),
      ('Type', manga.itemType.name),
      if (manga.smartUpdateDays != null)
        ('Mise à jour', l10n.n_days(manga.smartUpdateDays!)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (manga.description != null && manga.description!.isNotEmpty) ...[
            ReadMoreWidget(text: manga.description!, onChanged: (_) {}),
            const SizedBox(height: 18),
          ],
          if (genres.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres
                  .map(
                    (g) => Chip(
                      label: Text(g, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
          ],
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      e.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(e.$2, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION · similar ──────────────────────────────────────────────────────

  Widget _similarSection() {
    final future = _similarFuture ??= getRecommendations(
      widget.manga!.name ?? '',
      widget.manga!.itemType,
      ref.read(algorithmWeightsStateProvider),
    );
    return FutureBuilder<List<RecommendationResult>?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SimilarSkeletonRow();
        }
        final results = snapshot.data ?? const <RecommendationResult>[];
        if (results.isEmpty) {
          return const _EmptySection(
            icon: Broken.star,
            message: 'Aucune suggestion disponible pour ce titre.',
          );
        }
        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final r = results[index];
              final title = (r.titleEnglish?.isNotEmpty ?? false)
                  ? r.titleEnglish!
                  : (r.titleRomaji ?? r.titleNative ?? 'Sans titre');
              return PosterCard(
                width: 116,
                heroTag: 'similar-${widget.manga!.id}-${r.id}',
                item: ContentItem(
                  key: 'similar-${r.id}',
                  title: title,
                  posterUrl: r.imgURLs.isNotEmpty ? r.imgURLs.first : null,
                  rating: r.score > 0 ? r.score / 10 : null,
                ),
                onTap: () {
                  final w = ref.read(algorithmWeightsStateProvider);
                  context.push(
                    '/recommendationDetail',
                    extra: (widget.manga!.name, widget.manga!.itemType, w),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── SECTION · comments ────────────────────────────────────────────────────

  Widget _commentsSection() {
    final manga = widget.manga!;
    Source? source;
    var url = '';
    if (!isLocalArchive && manga.source != null && manga.link != null) {
      source = getSource(manga.lang!, manga.source!, manga.sourceId);
      if (source != null) {
        url = '${source.baseUrl}${manga.link!.getUrlWithoutDomain}';
      }
    }
    final scheme = Theme.of(context).colorScheme;
    final canOpenComments = source != null && url.isNotEmpty;
    return CommentsSection(
      url: url,
      title: manga.name ?? '',
      source: (source?.supportsComments ?? false) ? source : null,
      scrollable: false,
      accent: context.primaryColor,
      bg: Theme.of(context).scaffoldBackgroundColor,
      card: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      onSurface: scheme.onSurface,
      grey: Theme.of(context).hintColor,
      faint: scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      emptyActionLabel: canOpenComments ? 'Ouvrir la source' : null,
      emptyAction: canOpenComments ? _openWebView : null,
    );
  }

  // ── ACTIONS · share & webview ─────────────────────────────────────────────

  void _shareManga() {
    final manga = widget.manga!;
    if (manga.lang == null || manga.source == null || manga.link == null) {
      return;
    }
    final source = getSource(manga.lang!, manga.source!, manga.sourceId);
    if (source == null) return;
    final url = '${source.baseUrl}${manga.link!.getUrlWithoutDomain}';
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(
      ShareParams(
        text: url,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _openWebView() {
    final manga = widget.manga!;
    if (manga.lang == null || manga.source == null || manga.link == null) {
      return;
    }
    final source = getSource(manga.lang!, manga.source!, manga.sourceId);
    if (source == null) return;
    final url = '${source.baseUrl}${manga.link!.getUrlWithoutDomain}';
    context.push(
      '/mangawebview',
      extra: {
        'url': url,
        'sourceId': source.id.toString(),
        'title': manga.name!,
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
                                  child: Icon(Icons.close),
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
                                      child: Icon(Icons.share),
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
                                      child: Icon(Icons.save_outlined),
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
                                        Icons.edit_outlined,
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

// ── Detail section tab pills ──────────────────────────────────────────────────

class _DetailTabPills extends StatelessWidget {
  final _DetailSection selected;
  final ValueChanged<_DetailSection> onSelect;
  const _DetailTabPills({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final tabs = [
      (
        section: _DetailSection.chapters,
        label: l10n.chapters,
        icon: Broken.book,
      ),
      (
        section: _DetailSection.details,
        label: 'Détails',
        icon: Broken.information,
      ),
      (section: _DetailSection.similar, label: 'Similaires', icon: Broken.star),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: tabs.map((tab) {
          final isActive = selected == tab.section;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(tab.section),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Action tile (library / follow / tracker) ──────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.82);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty section placeholder ─────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: hint.withValues(alpha: 0.55)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: hint),
          ),
        ],
      ),
    );
  }
}

// ── Similar rail skeleton (shimmer) ──────────────────────────────────────────

class _SimilarSkeletonRow extends StatelessWidget {
  const _SimilarSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      effect: shimmerEffectFor(context),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 0, 8),
        child: Row(
          children: [
            SimilarCardSkeleton(),
            SizedBox(width: 10),
            SimilarCardSkeleton(),
            SizedBox(width: 10),
            SimilarCardSkeleton(),
          ],
        ),
      ),
    );
  }
}

// ── Language flag helper ──────────────────────────────────────────────────────

String _langFlag(String lang) {
  const map = {
    'ja': '🇯🇵',
    'jp': '🇯🇵',
    'ko': '🇰🇷',
    'kr': '🇰🇷',
    'zh': '🇨🇳',
    'cn': '🇨🇳',
    'zh-hant': '🇹🇼',
    'tw': '🇹🇼',
    'en': '🇬🇧',
    'fr': '🇫🇷',
    'es': '🇪🇸',
    'pt': '🇧🇷',
    'pt-br': '🇧🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'ru': '🇷🇺',
    'ar': '🇸🇦',
    'vi': '🇻🇳',
    'th': '🇹🇭',
    'id': '🇮🇩',
  };
  return map[lang.toLowerCase()] ?? '';
}
