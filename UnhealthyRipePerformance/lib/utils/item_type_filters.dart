import 'package:watchtower/models/manga.dart';

List<ItemType> hiddenItemTypes(List<String> hideItems) {
  return [
    if (!hideItems.contains("/AnimeLibrary")) ItemType.anime,
    if (!hideItems.contains("/MangaLibrary")) ItemType.manga,
    if (!hideItems.contains("/NovelLibrary")) ItemType.novel,
    if (!hideItems.contains("/MusicLibrary")) ItemType.music,
    if (!hideItems.contains("/GameLibrary")) ItemType.game,
  ];
}
