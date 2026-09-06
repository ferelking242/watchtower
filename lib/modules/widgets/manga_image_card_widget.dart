import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_main.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/widgets/bottom_text_widget.dart';
import 'package:watchtower/modules/widgets/cover_view_widget.dart';

class MangaImageCardWidget extends ConsumerWidget {
  final Source source;
  final ItemType itemType;
  final bool isComfortableGrid;
  final MManga? getMangaDetail;

  const MangaImageCardWidget({
    required this.source,
    super.key,
    required this.getMangaDetail,
    required this.isComfortableGrid,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: isar.mangas
          .filter()
          .langEqualTo(source.lang)
          .nameEqualTo(getMangaDetail!.name)
          .sourceEqualTo(source.name)
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        bool hasData = snapshot.hasData;
        final mangaList = hasData
            ? snapshot.data!
                  .where(
                    (element) => element.sourceId == null
                        ? true
                        : element.sourceId == source.id,
                  )
                  .toList()
            : [];
        hasData = hasData && mangaList.isNotEmpty;
        return CoverViewWidget(
          bottomTextWidget: BottomTextWidget(
            maxLines: 1,
            text: getMangaDetail!.name!,
            isComfortableGrid: isComfortableGrid,
          ),
          isComfortableGrid: isComfortableGrid,
          image: hasData && mangaList.first.customCoverImage != null
              ? MemoryImage(mangaList.first.customCoverImage as Uint8List)
                    as ImageProvider
              : kIsWeb
              ? NetworkImage(
                  toImgUrl(
                    hasData
                        ? mangaList.first.customCoverFromTracker ??
                              mangaList.first.imageUrl ??
                              ""
                        : getMangaDetail!.imageUrl ?? "",
                  ),
                )
              : CustomExtendedNetworkImageProvider(
                  toImgUrl(
                    hasData
                        ? mangaList.first.customCoverFromTracker ??
                              mangaList.first.imageUrl ??
                              ""
                        : getMangaDetail!.imageUrl ?? "",
                  ),
                  headers: ref.watch(
                    headersProvider(
                      source: source.name!,
                      lang: source.lang!,
                      sourceId: source.id,
                    ),
                  ),
                  cache: true,
                  cacheMaxAge: const Duration(days: 3650),
                ),
          onTap: () {
            // Reel-type links (e.g. RedGIFs) open in ReelScreen (TikTok tabs).
            final link = getMangaDetail!.link;
            if (link != null && link.startsWith('{')) {
              try {
                final data = jsonDecode(link) as Map<String, dynamic>;
                if (data['type'] == 'reel') {
                  context.pushNamed('reel', extra: {
                    'source': source,
                    'listId': (data['listId'] as String?) ?? 'trending',
                    'startGifId': data['gifId'] as String?,
                  });
                  return;
                }
              } catch (_) {}
            }
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              sourceId: source.id,
            );
          },
          onLongPress: () {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              addToFavourite: true,
              sourceId: source.id,
            );
          },
          onSecondaryTap: () {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              addToFavourite: true,
              sourceId: source.id,
            );
          },
          children: [
            Container(
              color: hasData && mangaList.first.favorite!
                  ? Colors.black.withValues(alpha: 0.5)
                  : null,
            ),
            if (hasData && mangaList.first.favorite!)
              Positioned(
                top: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.primaryColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 16,
                        color: context.dynamicWhiteBlackColor,
                      ),
                    ),
                  ),
                ),
              ),
            if (!isComfortableGrid)
              BottomTextWidget(
                isTorrent: source.isTorrent,
                text: getMangaDetail!.name!,
              ),
          ],
        );
      },
    );
  }
}

class MangaImageCardListTileWidget extends ConsumerWidget {
  final Source source;
  final ItemType itemType;
  final MManga? getMangaDetail;

  const MangaImageCardListTileWidget({
    required this.source,
    super.key,
    required this.itemType,
    required this.getMangaDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: isar.mangas
          .filter()
          .langEqualTo(source.lang)
          .nameEqualTo(getMangaDetail!.name)
          .sourceEqualTo(source.name)
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        bool hasData = snapshot.hasData;
        final mangaList = hasData
            ? snapshot.data!
                  .where(
                    (element) => element.sourceId == null
                        ? true
                        : element.sourceId == source.id,
                  )
                  .toList()
            : [];
        hasData = hasData && mangaList.isNotEmpty;
        final _imgUrl = toImgUrl(
          hasData
              ? mangaList.first.customCoverFromTracker ??
                    mangaList.first.imageUrl ??
                    ""
              : getMangaDetail!.imageUrl ?? "",
        );
        final ImageProvider<Object> image = hasData && mangaList.first.customCoverImage != null
            ? MemoryImage(mangaList.first.customCoverImage as Uint8List)
                  as ImageProvider<Object>
            : kIsWeb
            ? NetworkImage(_imgUrl)
            : CustomExtendedNetworkImageProvider(
                _imgUrl,
                headers: ref.watch(
                  headersProvider(
                    source: source.name!,
                    lang: source.lang!,
                    sourceId: source.id,
                  ),
                ),
              );
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            borderRadius: BorderRadius.circular(5),
            color: Colors.transparent,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  sourceId: source.id,
                );
              },
              onLongPress: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  addToFavourite: true,
                  sourceId: source.id,
                );
              },
              onSecondaryTap: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  addToFavourite: true,
                  sourceId: source.id,
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Stack(
                      children: [
                        Material(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          child: Image(
                            height: 90,
                            width: 62,
                            fit: BoxFit.cover,
                            image: image,
                          ),
                        ),
                        Container(
                          height: 90,
                          width: 62,
                          decoration: BoxDecoration(
                            color: hasData && mangaList.first.favorite!
                                ? Colors.black.withValues(alpha: 0.5)
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          getMangaDetail!.name ?? '',
                          maxLines: 2,
                          style: TextStyle(
                            overflow: TextOverflow.ellipsis,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textColor,
                          ),
                        ),
                        if (getMangaDetail!.chapters?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.book_outlined, size: 12,
                                  color: context.primaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  getMangaDetail!.chapters![0].name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12,
                                  color: Theme.of(context).hintColor),
                              const SizedBox(width: 4),
                              Text(
                                _relativeTime(
                                    getMangaDetail!.chapters![0].dateUpload),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                          if (getMangaDetail!.chapters![0].scanlator?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.group_outlined, size: 12,
                                    color: Theme.of(context).hintColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    getMangaDetail!.chapters![0].scanlator!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (hasData && mangaList.first.favorite!)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.primaryColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.collections_bookmark_outlined,
                            size: 16,
                            color: context.dynamicWhiteBlackColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _relativeTime(String? dateUploadMs) {
  if (dateUploadMs == null || dateUploadMs.isEmpty) return '';
  final ts = int.tryParse(dateUploadMs);
  if (ts == null || ts == 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  return '${diff.inDays ~/ 30}mo ago';
}

Future<void> pushToMangaReaderDetail({
  MManga? getManga,
  required WidgetRef ref,
  required String lang,
  required BuildContext context,
  required String source,
  required int? sourceId,
  int? archiveId,
  Manga? mangaM,
  ItemType? itemType,
  bool useMaterialRoute = false,
  bool addToFavourite = false,
}) async {
  int? mangaId;
  mangaId = isar.mangas
      .filter()
      .isLocalArchiveEqualTo(true)
      .sourceEqualTo("local")
      .nameEqualTo(getManga?.name)
      .findFirstSync()
      ?.id;

  if (mangaId == null) {
    if (archiveId == null) {
      final manga =
          mangaM ??
          Manga(
            imageUrl: getManga!.imageUrl,
            name: getManga.name!.trim(),
            genre: getManga.genre?.map((e) => e.toString()).toList() ?? [],
            author: getManga.author ?? "",
            status: getManga.status ?? Status.unknown,
            description: getManga.description ?? "",
            link: getManga.link,
            source: source,
            lang: lang,
            lastUpdate: 0,
            itemType: itemType ?? ItemType.manga,
            artist: getManga.artist ?? '',
            sourceId: sourceId,
          );
      final empty = isar.mangas
          .filter()
          .langEqualTo(lang)
          .nameEqualTo(manga.name)
          .sourceEqualTo(manga.source)
          .isEmptySync();
      if (empty) {
        isar.writeTxnSync(() {
          isar.mangas.putSync(
            manga..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
        });
      } else {
        isar.writeTxnSync(() {
          isar.mangas.putSync(manga);
        });
      }

      mangaId = isar.mangas
          .filter()
          .langEqualTo(lang)
          .nameEqualTo(manga.name)
          .sourceEqualTo(manga.source)
          .findAllSync()
          .firstWhere(
            (element) =>
                element.sourceId == null ? true : element.sourceId == sourceId,
          )
          .id!;
    } else {
      mangaId = archiveId;
    }
  }

  final mang = isar.mangas.getSync(mangaId);
  if (mang!.sourceId == null && !(mang.isLocalArchive ?? false)) {
    isar.writeTxnSync(() {
      isar.mangas.putSync(mang..sourceId = sourceId);
    });
  }
  final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
  final sortList = settings.sortChapterList ?? [];
  final checkIfExist = sortList
      .where((element) => element.mangaId == mangaId)
      .toList();
  if (checkIfExist.isEmpty) {
    isar.writeTxnSync(() {
      List<SortChapter>? sortChapterList = [];
      for (var sortChapter in settings.sortChapterList ?? []) {
        sortChapterList.add(sortChapter);
      }
      List<ChapterFilterBookmarked>? chapterFilterBookmarkedList = [];
      for (var sortChapter in settings.chapterFilterBookmarkedList ?? []) {
        chapterFilterBookmarkedList.add(sortChapter);
      }
      List<ChapterFilterDownloaded>? chapterFilterDownloadedList = [];
      for (var sortChapter in settings.chapterFilterDownloadedList ?? []) {
        chapterFilterDownloadedList.add(sortChapter);
      }
      List<ChapterFilterUnread>? chapterFilterUnreadList = [];
      for (var sortChapter in settings.chapterFilterUnreadList ?? []) {
        chapterFilterUnreadList.add(sortChapter);
      }
      sortChapterList.add(SortChapter()..mangaId = mangaId);
      chapterFilterBookmarkedList.add(
        ChapterFilterBookmarked()..mangaId = mangaId,
      );
      chapterFilterDownloadedList.add(
        ChapterFilterDownloaded()..mangaId = mangaId,
      );
      chapterFilterUnreadList.add(ChapterFilterUnread()..mangaId = mangaId);
      isar.settings.putSync(
        settings
          ..sortChapterList = sortChapterList
          ..chapterFilterBookmarkedList = chapterFilterBookmarkedList
          ..chapterFilterDownloadedList = chapterFilterDownloadedList
          ..chapterFilterUnreadList = chapterFilterUnreadList
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
  if (!addToFavourite) {
    if (useMaterialRoute) {
      await Navigator.push(
        context,
        createRoute(page: MangaReaderDetail(mangaId: mangaId)),
      );
    } else {
      await context.push('/manga-reader/detail', extra: mangaId);
    }
  } else {
    final getManga = isar.mangas.filter().idEqualTo(mangaId).findFirstSync()!;
    isar.writeTxnSync(() {
      isar.mangas.putSync(
        getManga
          ..favorite = !getManga.favorite!
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}
