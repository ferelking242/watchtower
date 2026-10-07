import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';

/// Converts the app's real domain objects into JSON-friendly maps.
///
/// The CLI deliberately reuses the exact model classes the application uses,
/// so a value produced here is the same value the UI would render.
Object? cliSerialize(Object? value) {
  if (value == null) return null;
  if (value is num || value is bool || value is String) return value;
  if (value is MManga) return value.toJson();
  if (value is MPages) return value.toJson();
  if (value is Manga) return storedMangaToMap(value);
  if (value is Chapter) return value.toJson();
  if (value is Download) return downloadToMap(value);
  if (value is History) return historyToMap(value);
  if (value is Category) return categoryToMap(value);
  if (value is Source) return sourceToMap(value);
  if (value is Video) return videoToMap(value);
  if (value is PageUrl) return value.toJson();
  if (value is SourcePreference) return value.toJson();
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', cliSerialize(entry)));
  }
  if (value is Iterable) return value.map(cliSerialize).toList();
  // Filter / FilterList and other eval models expose toJson().
  try {
    final dynamic model = value;
    final json = model.toJson();
    if (json is Map) return cliSerialize(json);
  } catch (_) {
    // Not a JSON-serialisable model.
  }
  return value.toString();
}

Map<String, Object?> storedMangaToMap(Manga manga) => {
  'id': manga.id,
  'name': manga.name,
  'link': manga.link,
  'imageUrl': manga.imageUrl,
  'description': manga.description,
  'author': manga.author,
  'artist': manga.artist,
  'status': manga.status.name,
  'itemType': manga.itemType.name,
  'genre': manga.genre,
  'favorite': manga.favorite,
  'source': manga.source,
  'lang': manga.lang,
  'sourceId': manga.sourceId,
  'categories': manga.categories,
  'dateAdded': manga.dateAdded,
  'lastUpdate': manga.lastUpdate,
  'lastRead': manga.lastRead,
  'isLocalArchive': manga.isLocalArchive,
  'chapterCount': manga.chapters.length,
};

Map<String, Object?> downloadToMap(Download download) => {
  'id': download.id,
  'title': download.title,
  'quality': download.quality,
  'status': download.status,
  'isDownload': download.isDownload,
  'isStartDownload': download.isStartDownload,
  'succeeded': download.succeeded,
  'failed': download.failed,
  'total': download.total,
  'downloadedBytes': download.downloadedBytes,
  'totalBytes': download.totalBytes,
  'filePath': download.filePath,
  'chapterId': download.chapter.value?.id,
  'mangaId': download.chapter.value?.mangaId,
};

Map<String, Object?> historyToMap(History history) => {
  'id': history.id,
  'mangaId': history.mangaId,
  'chapterId': history.chapterId,
  'itemType': history.itemType.name,
  'date': history.date,
  'readingTimeSeconds': history.readingTimeSeconds,
  'chapterName': history.chapter.value?.name,
  'mangaName': history.chapter.value?.manga.value?.name,
};

Map<String, Object?> categoryToMap(Category category) => {
  'id': category.id,
  'name': category.name,
  'forItemType': category.forItemType.name,
  'pos': category.pos,
  'hide': category.hide,
  'shouldUpdate': category.shouldUpdate,
};

Map<String, Object?> sourceToMap(Source source) => {
  'id': source.id,
  'name': source.name,
  'lang': source.lang,
  'itemType': source.itemType.name,
  'version': source.version,
  'baseUrl': source.baseUrl,
  'iconUrl': source.iconUrl,
  'isAdded': source.isAdded,
  'isActive': source.isActive,
  'isPinned': source.isPinned,
  'isNsfw': source.isNsfw,
  'isObsolete': source.isObsolete,
  'isLocal': source.isLocal,
  'engine': source.sourceCodeLanguage.name,
  'repo': source.repo?.jsonUrl,
  'hasCode': (source.sourceCode ?? '').isNotEmpty,
  'supportsLatest': source.supportLatest,
};

Map<String, Object?> videoToMap(Video video) => {
  'url': video.url,
  'quality': video.quality,
  'originalUrl': video.originalUrl,
  'headers': video.headers,
  'subtitles': video.subtitles
      ?.map((t) => {'file': t.file, 'label': t.label})
      .toList(),
  'audios': video.audios
      ?.map((t) => {'file': t.file, 'label': t.label})
      .toList(),
};
