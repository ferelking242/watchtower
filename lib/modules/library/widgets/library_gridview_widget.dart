import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/providers/library_filter_provider.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/isar_batch.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/widgets/bottom_text_widget.dart';
import 'package:watchtower/modules/widgets/cover_view_widget.dart';
import 'package:watchtower/modules/widgets/gridview_widget.dart';
import 'package:watchtower/modules/library/widgets/library_swipe_wrapper.dart';
import 'package:watchtower/modules/library/widgets/continue_reading_button.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';

class LibraryGridViewWidget extends StatefulWidget {
  final bool isCoverOnlyGrid;
  final bool isComfortableGrid;
  final List<int> mangaIdsList;
  final List<Manga> entriesManga;
  final bool language;
  final bool downloadedChapter;
  final bool continueReaderBtn;
  final bool localSource;
  final ItemType itemType;
  const LibraryGridViewWidget({
    super.key,
    required this.entriesManga,
    required this.isCoverOnlyGrid,
    this.isComfortableGrid = false,
    required this.language,
    required this.downloadedChapter,
    required this.continueReaderBtn,
    required this.mangaIdsList,
    required this.localSource,
    required this.itemType,
  });

  @override
  State<LibraryGridViewWidget> createState() => _LibraryGridViewWidgetState();
}

class _LibraryGridViewWidgetState extends State<LibraryGridViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final isLongPressed = ref.watch(isLongPressedStateProvider);
        final itemType = widget.itemType;
        final showUnread = ref.watch(libraryShowUnreadChaptersProvider);
        final overlay = ref.watch(libraryOverlayProvider);

        // Chapter counts for the badges: one batched query for the whole grid
        // instead of a synchronous Isar load per visible card.
        final chaptersByManga = (showUnread || widget.downloadedChapter)
            ? loadChaptersByMangaIds(
                widget.entriesManga.map((e) => e.id).whereType<int>(),
              )
            : const <int, List<Chapter>>{};

        final rawGridSize = ref.watch(
          libraryGridSizeStateProvider(itemType: itemType),
        );
        // Default to 3 columns (matching the browse catalog) when the user
        // hasn't set an explicit preference.
        final gridSize = (rawGridSize == null || rawGridSize == 0)
            ? 3
            : rawGridSize;
        return GridViewWidget(
          gridSize: gridSize,
          childAspectRatio: widget.isComfortableGrid ? 0.642 : 0.69,
          itemCount: widget.entriesManga.length,
          itemBuilder: (context, index) {
            final entry = widget.entriesManga[index];
            final entryChapters =
                chaptersByManga[entry.id] ?? const <Chapter>[];

            return Builder(
              builder: (context) {
                bool isLocalArchive = entry.isLocalArchive ?? false;
                return LibrarySwipeWrapper(
                  manga: entry,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CoverViewWidget(
                      isLongPressed: widget.mangaIdsList.contains(entry.id),
                      bottomTextWidget: BottomTextWidget(
                        maxLines: 1,
                        text: entry.name!,
                        isComfortableGrid: widget.isComfortableGrid,
                      ),
                      isComfortableGrid: widget.isComfortableGrid,
                      image: entry.customCoverImage != null
                          ? MemoryImage(entry.customCoverImage as Uint8List)
                                as ImageProvider
                          : CustomExtendedNetworkImageProvider(
                              toImgUrl(
                                entry.customCoverFromTracker ??
                                    entry.imageUrl ??
                                    "",
                              ),
                              // Null-safe: `isLocalArchive` is nullable and the
                              // old `!` crashed the whole grid with a null-check
                              // error as soon as one local entry lacked the flag.
                              headers: (entry.isLocalArchive ?? false)
                                  ? null
                                  : ref.watch(
                                      headersProvider(
                                        source: entry.source!,
                                        lang: entry.lang!,
                                        sourceId: entry.sourceId,
                                      ),
                                    ),
                            ),
                      onTap: () async {
                        if (isLongPressed) {
                          ref
                              .read(mangasListStateProvider.notifier)
                              .update(entry);
                        } else {
                          await pushToMangaReaderDetail(
                            ref: ref,
                            archiveId: isLocalArchive ? entry.id : null,
                            knownMangaId: entry.id,
                            context: context,
                            lang: entry.lang!,
                            mangaM: entry,
                            source: entry.source!,
                            sourceId: entry.sourceId,
                          );
                          if (context.mounted) {
                            ref.invalidate(
                              getAllMangaWithoutCategoriesStreamProvider(
                                itemType: widget.itemType,
                              ),
                            );
                            ref.invalidate(
                              getAllMangaStreamProvider(
                                categoryId: null,
                                itemType: widget.itemType,
                              ),
                            );
                          }
                        }
                      },
                      onLongPress: () {
                        _handleLongOrSecondaryTap(isLongPressed, ref, entry);
                      },
                      onSecondaryTap: () {
                        _handleLongOrSecondaryTap(isLongPressed, ref, entry);
                      },
                      children: [
                        Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: overlay
                                        ? context.primaryColor.withValues(
                                            alpha: 0.85,
                                          )
                                        : context.primaryColor,
                                  ),
                                  child: Row(
                                    children: [
                                      if (widget.localSource && isLocalArchive)
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  bottomLeft: Radius.circular(
                                                    3,
                                                  ),
                                                ),
                                            color: Theme.of(context).hintColor,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 3,
                                              right: 3,
                                            ),
                                            child: Text(
                                              "Local",
                                              style: TextStyle(
                                                color: context
                                                    .dynamicBlackWhiteColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (showUnread)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 5,
                                          ),
                                          child: Consumer(
                                            builder: (context, ref, child) {
                                              // O(chapters) set lookups instead of
                                              // one Isar query per chapter, run
                                              // synchronously on the UI thread
                                              // for every visible card.
                                              final downloadedIds = ref.watch(
                                                downloadedChapterIdsProvider,
                                              );
                                              final downloadedCount =
                                                  widget.downloadedChapter
                                                  ? entryChapters
                                                        .where(
                                                          (chap) =>
                                                              chap.id != null &&
                                                              downloadedIds
                                                                  .contains(
                                                                    chap.id,
                                                                  ),
                                                        )
                                                        .length
                                                  : 0;

                                              return Row(
                                                children: [
                                                  if (downloadedCount > 0 &&
                                                      widget.downloadedChapter)
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            const BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                              bottomLeft:
                                                                  Radius.circular(
                                                                    3,
                                                                  ),
                                                            ),
                                                        color: Theme.of(
                                                          context,
                                                        ).secondaryHeaderColor,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 3,
                                                              right: 3,
                                                            ),
                                                        child: Text(
                                                          downloadedCount
                                                              .toString(),
                                                        ),
                                                      ),
                                                    ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 3,
                                                        ),
                                                    child: Text(
                                                      entryChapters
                                                          .where(
                                                            (element) =>
                                                                element
                                                                    .isRead !=
                                                                true,
                                                          )
                                                          .length
                                                          .toString(),
                                                      style: TextStyle(
                                                        color: context
                                                            .dynamicBlackWhiteColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (widget.language && entry.lang!.isNotEmpty)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Container(
                                    color: context.themeData.cardColor,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(3),
                                          bottomLeft: Radius.circular(3),
                                        ),
                                        color: overlay
                                            ? Theme.of(context).hintColor
                                                  .withValues(alpha: 0.85)
                                            : Theme.of(context).hintColor,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 3,
                                          right: 3,
                                        ),
                                        child: Text(
                                          entry.lang!.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!widget.isComfortableGrid &&
                            !widget.isCoverOnlyGrid)
                          BottomTextWidget(text: entry.name!),
                        if (widget.continueReaderBtn)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: ContinueReadingButton(entry: entry),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleLongOrSecondaryTap(
    bool isLongPressed,
    WidgetRef ref,
    Manga entry,
  ) {
    if (!isLongPressed) {
      ref.read(mangasListStateProvider.notifier).update(entry);
      ref.read(isLongPressedStateProvider.notifier).update(!isLongPressed);
    } else {
      ref.read(mangasListStateProvider.notifier).update(entry);
    }
  }
}
