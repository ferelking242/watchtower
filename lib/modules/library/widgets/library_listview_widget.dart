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
import 'package:watchtower/modules/widgets/listview_widget.dart';
import 'package:watchtower/modules/library/widgets/library_swipe_wrapper.dart';
import 'package:watchtower/modules/library/widgets/continue_reading_button.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';

class LibraryListViewWidget extends ConsumerWidget {
  final List<Manga> entriesManga;
  final bool language;
  final bool downloadedChapter;
  final List<int> mangaIdsList;
  final bool continueReaderBtn;
  final bool localSource;
  const LibraryListViewWidget({
    super.key,
    required this.entriesManga,
    required this.language,
    required this.downloadedChapter,
    required this.continueReaderBtn,
    required this.mangaIdsList,
    required this.localSource,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One batched query for the whole list instead of a synchronous Isar load
    // per visible row (the badge counters used to touch `entry.chapters`, a
    // lazy backlink that runs its own query on the UI thread). The row always
    // shows a chapter count (total, or unread when the setting is on), so the
    // chapters are always needed here.
    final showUnread = ref.watch(libraryShowUnreadChaptersProvider);
    final chaptersByManga = loadChaptersByMangaIds(
      entriesManga.map((e) => e.id).whereType<int>(),
    );

    return SuperListViewWidget(
      itemCount: entriesManga.length,
      itemBuilder: (context, index) {
        final entry = entriesManga[index];
        final entryChapters = chaptersByManga[entry.id] ?? const <Chapter>[];
        bool isLocalArchive = entry.isLocalArchive ?? false;
        return Consumer(
          builder: (context, ref, child) {
            final isLongPressed = ref.watch(isLongPressedStateProvider);
            final overlay = ref.watch(libraryOverlayProvider);
            return LibrarySwipeWrapper(
              manga: entry,
              child: Material(
                borderRadius: BorderRadius.circular(5),
                color: Colors.transparent,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: InkWell(
                  onTap: () async {
                    if (isLongPressed) {
                      ref.read(mangasListStateProvider.notifier).update(entry);
                    } else {
                      await pushToMangaReaderDetail(
                        ref: ref,
                        archiveId: isLocalArchive ? entry.id : null,
                        context: context,
                        lang: entry.lang!,
                        mangaM: entry,
                        source: entry.source!,
                        sourceId: entry.sourceId,
                      );
                      ref.invalidate(
                        getAllMangaWithoutCategoriesStreamProvider(
                          itemType: entry.itemType,
                        ),
                      );
                      ref.invalidate(
                        getAllMangaStreamProvider(
                          categoryId: null,
                          itemType: entry.itemType,
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!isLongPressed) {
                      ref.read(mangasListStateProvider.notifier).update(entry);

                      ref
                          .read(isLongPressedStateProvider.notifier)
                          .update(!isLongPressed);
                    } else {
                      ref.read(mangasListStateProvider.notifier).update(entry);
                    }
                  },
                  onSecondaryTap: () {
                    if (!isLongPressed) {
                      ref.read(mangasListStateProvider.notifier).update(entry);

                      ref
                          .read(isLongPressedStateProvider.notifier)
                          .update(!isLongPressed);
                    } else {
                      ref.read(mangasListStateProvider.notifier).update(entry);
                    }
                  },
                  child: Container(
                    color: mangaIdsList.contains(entry.id)
                        ? context.primaryColor.withValues(alpha: 0.4)
                        : Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Material(
                                      child: Ink.image(
                                        fit: BoxFit.cover,
                                        width: 40,
                                        height: 45,
                                        image: entry.customCoverImage != null
                                            ? MemoryImage(
                                                    entry.customCoverImage
                                                        as Uint8List,
                                                  )
                                                  as ImageProvider
                                            : CustomExtendedNetworkImageProvider(
                                                toImgUrl(
                                                  entry.customCoverFromTracker ??
                                                      entry.imageUrl!,
                                                ),
                                                headers: ref.watch(
                                                  headersProvider(
                                                    source: entry.source!,
                                                    lang: entry.lang!,
                                                    sourceId: entry.sourceId,
                                                  ),
                                                ),
                                              ),
                                        child: InkWell(
                                          child: Container(
                                            color:
                                                mangaIdsList.contains(entry.id)
                                                ? context.primaryColor
                                                      .withValues(alpha: 0.4)
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(entry.name!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
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
                                child: SizedBox(
                                  height: 22,
                                  child: Row(
                                    children: [
                                      if (localSource && isLocalArchive)
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
                                          child: const Padding(
                                            padding: EdgeInsets.only(
                                              left: 3,
                                              right: 3,
                                            ),
                                            child: Text(
                                              "Local",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (downloadedChapter)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 5,
                                          ),
                                          child: Consumer(
                                            builder: (context, ref, child) {
                                              final downloadedIds = ref.watch(
                                                downloadedChapterIdsProvider,
                                              );
                                              final downloadedCount =
                                                  entryChapters
                                                      .where(
                                                        (chap) =>
                                                            chap.id != null &&
                                                            downloadedIds
                                                                .contains(
                                                                  chap.id,
                                                                ),
                                                      )
                                                      .length;
                                              if (downloadedCount == 0) {
                                                return const SizedBox.shrink();
                                              }
                                              return Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(3),
                                                        bottomLeft:
                                                            Radius.circular(3),
                                                      ),
                                                  color: Theme.of(
                                                    context,
                                                  ).hintColor,
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 3,
                                                        right: 3,
                                                      ),
                                                  child: Text(
                                                    downloadedCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 3,
                                        ),
                                        child: Text(
                                          (showUnread
                                                  ? entryChapters
                                                        .where(
                                                          (e) =>
                                                              e.isRead != true,
                                                        )
                                                        .length
                                                  : entryChapters.length)
                                              .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (language && entry.lang!.isNotEmpty)
                                        Container(
                                          color: context.primaryColor,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topRight: Radius.circular(
                                                      3,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(3),
                                                  ),
                                              color: Theme.of(
                                                context,
                                              ).hintColor,
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (continueReaderBtn)
                              ContinueReadingButton(entry: entry),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
