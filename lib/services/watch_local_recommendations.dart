import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';

/// A library title that shares genres with the one being watched.
class LocalRecommendation {
  const LocalRecommendation({
    required this.manga,
    required this.sharedGenres,
    required this.downloadedEpisodes,
  });

  final Manga manga;
  final int sharedGenres;

  /// Episodes of [manga] present on disk. Zero means the title is in the
  /// library but not downloaded.
  final int downloadedEpisodes;
}

/// "Pour vous" for a title, computed from the library instead of the network.
///
/// The player tab used to call the extension's `getRecommendations`, which
/// needs the source to be reachable and returns whatever the site promotes.
/// The library already knows what the user watches: same genres (thriller,
/// adventure, …), same medium. Titles with downloaded episodes come first, so
/// the shelf suggests things that are actually watchable offline.
List<LocalRecommendation> localRecommendationsFor(
  Manga current, {
  int limit = 18,
}) {
  final genres = _normalizedGenres(current);
  final candidates = isar.mangas
      .where()
      .findAllSync()
      .where(
        (m) =>
            m.id != null &&
            m.id != current.id &&
            m.itemType == current.itemType &&
            m.favorite == true,
      );
  if (candidates.isEmpty) return const [];

  final downloadedChapterIds = isar.downloads
      .where()
      .findAllSync()
      .where((download) => download.isDownload == true)
      .map((download) => download.id)
      .whereType<int>()
      .toSet();

  final result = <LocalRecommendation>[];
  for (final candidate in candidates) {
    final shared = genres.isEmpty
        ? 0
        : _normalizedGenres(candidate).intersection(genres).length;
    if (genres.isNotEmpty && shared == 0) continue;
    result.add(
      LocalRecommendation(
        manga: candidate,
        sharedGenres: shared,
        downloadedEpisodes: _downloadedEpisodeCount(
          candidate,
          downloadedChapterIds,
        ),
      ),
    );
  }

  result.sort((a, b) {
    if (a.downloadedEpisodes != b.downloadedEpisodes) {
      return b.downloadedEpisodes.compareTo(a.downloadedEpisodes);
    }
    if (a.sharedGenres != b.sharedGenres) {
      return b.sharedGenres.compareTo(a.sharedGenres);
    }
    return (b.manga.lastRead ?? 0).compareTo(a.manga.lastRead ?? 0);
  });
  return result.take(limit).toList();
}

int _downloadedEpisodeCount(Manga manga, Set<int> downloadedChapterIds) {
  if (downloadedChapterIds.isEmpty) return 0;
  final chapters = isar.chapters
      .filter()
      .mangaIdEqualTo(manga.id!)
      .findAllSync();
  return chapters.where((c) => downloadedChapterIds.contains(c.id)).length;
}

Set<String> _normalizedGenres(Manga manga) => (manga.genre ?? const <String>[])
    .map((g) => g.trim().toLowerCase())
    .where((g) => g.isNotEmpty)
    .toSet();
