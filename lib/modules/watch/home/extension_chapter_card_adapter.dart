import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/media/manga_chapter_cards.dart';

/// Adapts extension chapter data to the existing individual chapter card.
class ExtensionChapterCardAdapter {
  static Widget build({
    required MManga manga,
    required MChapter chapter,
    required double width,
    required VoidCallback onTap,
  }) {
    final mangaName = manga.name!.trim();
    final chapterName = chapter.name!.trim();
    final thumbnail = chapter.thumbnailUrl?.trim();
    final mangaCover = manga.imageUrl?.trim();

    return MangaChapterCard(
      width: width,
      item: MangaChapterItem(
        title: mangaName,
        subtitle: chapterName,
        thumbUrl: thumbnail?.isNotEmpty == true
            ? thumbnail
            : mangaCover?.isNotEmpty == true
            ? mangaCover
            : null,
        onTap: onTap,
      ),
    );
  }
}
