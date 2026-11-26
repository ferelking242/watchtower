import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/watch_comments_store.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/utils.dart';

/// Fetches and stores the comments of [chapter] when its video is downloaded.
///
/// The comment tab asks the extension runtime for `getComments`, which needs
/// the network; caching at download time is what makes the tab work offline.
/// [title] must be the series name used by the resume store, so the player
/// finds the cache again for every episode of the series.
Future<void> cacheEpisodeComments({
  required String title,
  required Chapter chapter,
  required Manga? sourceManga,
}) async {
  final chapterId = chapter.id;
  if (chapterId == null || title.trim().isEmpty) return;
  final manga = sourceManga;
  if (manga == null) return;
  final url = manga.link ?? chapter.url ?? '';
  if (url.trim().isEmpty) return;

  final Source? source = getSource(
    manga.lang ?? '',
    manga.source ?? '',
    manga.sourceId,
  );
  if (source == null) return;

  try {
    final raw = await getIsolateService.get<List<dynamic>>(
      url: url,
      source: source,
      serviceType: 'getComments',
    );
    if (raw.isEmpty) return;
    await writeWatchComments(title, chapterId, raw);
  } catch (error) {
    AppLogger.log(
      'cacheEpisodeComments failed for chapter $chapterId: $error',
      logLevel: LogLevel.warning,
      tag: LogTag.watch,
    );
  }
}
