import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/utils.dart';

/// The type a chapter must be read as.
///
/// `Manga.itemType` can be stale: two sources may share a display name across
/// catalogues (MKissa exists as both a watch and a manga source), and a
/// name-only lookup used to persist the wrong one. When the row carries a
/// `sourceId`, trust the source it points at and heal the row so the next open
/// is correct without waiting for the detail screen's correction pass. Without
/// an id the name is ambiguous, so the stored type is left alone.
ItemType _readerItemType(Manga manga) {
  if (manga.isLocalArchive ?? false) return manga.itemType;
  final sourceId = manga.sourceId;
  if (sourceId == null) return manga.itemType;
  final source = getSource(manga.lang ?? '', manga.source ?? '', sourceId);
  if (source != null && source.itemType != manga.itemType) {
    try {
      isar.writeTxnSync(() {
        isar.mangas.putSync(manga..itemType = source.itemType);
      });
    } catch (_) {
      // A failed heal must never block opening the chapter.
    }
    return source.itemType;
  }
  return manga.itemType;
}

Future<void> pushMangaReaderView({
  required BuildContext context,
  required Chapter chapter,
}) async {
  final chManga = resolveChapterManga(chapter);
  if (chManga == null) return;
  final sourceExist = isar.sources
      .filter()
      .langContains(chManga.lang!, caseSensitive: false)
      .and()
      .nameContains(chManga.source!, caseSensitive: false)
      .and()
      .isActiveEqualTo(true)
      .and()
      .isAddedEqualTo(true)
      .findAllSync()
      .isNotEmpty;
  if (sourceExist || (chManga.isLocalArchive ?? false)) {
    switch (_readerItemType(chManga)) {
      case ItemType.manga:
        if (!context.mounted) return;
        await context.push('/mangaReaderView', extra: chapter.id!);
        break;
      case ItemType.anime:
        if (!context.mounted) return;
        await context.push('/animePlayerView', extra: chapter.id!);
        break;
      case ItemType.novel:
        if (!context.mounted) return;
        await context.push('/novelReaderView', extra: chapter.id!);
        break;
      case ItemType.music:
      case ItemType.game:
      case ItemType.plugin:
        break;
    }
  }
}

void pushReplacementMangaReaderView({
  required BuildContext context,
  required Chapter chapter,
}) {
  final chManga = resolveChapterManga(chapter);
  if (chManga == null) return;
  switch (_readerItemType(chManga)) {
    case ItemType.manga:
      context.pushReplacement('/mangaReaderView', extra: chapter.id!);
      break;
    case ItemType.anime:
      context.pushReplacement('/animePlayerView', extra: chapter.id!);
      break;
    case ItemType.novel:
      context.pushReplacement('/novelReaderView', extra: chapter.id!);
      break;
    case ItemType.music:
    case ItemType.game:
    case ItemType.plugin:
      break;
  }
}
