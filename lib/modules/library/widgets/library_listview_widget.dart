import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/library/providers/library_filter_provider.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
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
    // Badge stats come from a provider that re-runs only on a chapter/download
    // write, not on every list rebuild. The old inline `loadChaptersByMangaIds`
    // read every chapter of the library synchronously on each rebuild.
    final showUnread = ref.watch(libraryShowUnreadChaptersProvider);
    final statsByManga =
        ref.watch(libraryChapterStatsProvider).asData?.value ??
            const <int, MangaChapterStats>{};

    return SuperListViewWidget(
      itemCount: entriesManga.length,
      itemBuilder: (context, index) {
        final entry = entriesManga[index];
        final entryStats = statsByManga[entry.id] ??
            const MangaChapterStats(total: 0, unread: 0, downloaded: 0);
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
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    if (isLongPressed) {
                      ref.read(mangasListStateProvider.notifier).update(entry);
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
                      // Both providers are Isar `.watch()` streams: the write
                      // performed inside the detail route re-emits them on its
                      // own. Invalidating here rebuilt the whole library stream
                      // and re-ran the filter/sort provider — a synchronous
                      // read of every chapter of the library — on the tap.
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
                                              final downloadedCount =
                                                  entryStats.downloaded;
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
                                                  ? entryStats.unread
                                                  : entryStats.total)
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
