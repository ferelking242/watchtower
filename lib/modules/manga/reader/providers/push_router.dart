import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';

Future<void> pushMangaReaderView({
  required BuildContext context,
  required Chapter chapter,
}) async {
  final chManga = chapter.manga.value;
  if (chManga == null) return;
  final sourceExist = isar.sources
      .filter()
      .langContains(chManga.lang!, caseSensitive: false)
      .and()
      .nameContains(chManga.source!, caseSensitive: false)
      .and()
      .idIsNotNull()
      .and()
      .isActiveEqualTo(true)
      .and()
      .isAddedEqualTo(true)
      .findAllSync()
      .isNotEmpty;
  if (sourceExist || (chManga.isLocalArchive ?? false)) {
    switch (chManga.itemType) {
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
        break;
    }
  }
}

void pushReplacementMangaReaderView({
  required BuildContext context,
  required Chapter chapter,
}) {
  final chManga = chapter.manga.value;
  if (chManga == null) return;
  switch (chManga.itemType) {
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
      break;
  }
}
