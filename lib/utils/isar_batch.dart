import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';

/// Batched Isar lookups for list/grid builds.
///
/// `IsarLink.value` is a trap on a hot path: when the link is attached but not
/// loaded it calls `loadSync()`, i.e. one synchronous Isar query **on the UI
/// isolate**, and it does so again on every rebuild. A row that reads
/// `entry.chapter.value` and then `chapter.manga.value` therefore pays two
/// blocking queries per row per frame.
///
/// `History` and `Update` already store `chapterId` / `mangaId` as scalars, so
/// the links are unnecessary: resolve the whole visible page with one query
/// per collection and hand the rows a map lookup instead.
///
/// `getAllSync` is used (not `anyOf`) because it hits the primary-key index and
/// keeps the id order; it is chunked to stay well inside SQLite/Isar's
/// expression limits on very large lists.
const int _kBatchChunk = 500;

List<List<T>> _chunks<T>(List<T> items) {
  if (items.length <= _kBatchChunk) return [items];
  return [
    for (var i = 0; i < items.length; i += _kBatchChunk)
      items.sublist(
        i,
        i + _kBatchChunk > items.length ? items.length : i + _kBatchChunk,
      ),
  ];
}

/// Loads [Manga] rows for [ids] in one query per chunk. Missing ids are absent
/// from the result.
Map<int, Manga> loadMangasByIds(Iterable<int?> ids) {
  final wanted = ids.whereType<int>().toSet().toList(growable: false);
  final result = <int, Manga>{};
  for (final chunk in _chunks(wanted)) {
    final rows = isar.mangas.getAllSync(chunk);
    for (final row in rows) {
      final id = row?.id;
      if (row != null && id != null) result[id] = row;
    }
  }
  return result;
}

/// Loads [Chapter] rows for [ids] in one query per chunk. Missing ids are
/// absent from the result.
Map<int, Chapter> loadChaptersByIds(Iterable<int?> ids) {
  final wanted = ids.whereType<int>().toSet().toList(growable: false);
  final result = <int, Chapter>{};
  for (final chunk in _chunks(wanted)) {
    final rows = isar.chapters.getAllSync(chunk);
    for (final row in rows) {
      final id = row?.id;
      if (row != null && id != null) result[id] = row;
    }
  }
  return result;
}

/// Loads the chapters of [mangaIds] grouped by `mangaId`, in one query per
/// chunk. `Manga.chapters` is a lazy `IsarLinks` backlink: touching it runs a
/// synchronous Isar query per manga, which is an O(manga) N+1 when a filter or
/// sort reads it for the whole library.
Map<int, List<Chapter>> loadChaptersByMangaIds(Iterable<int?> mangaIds) {
  final wanted = mangaIds.whereType<int>().toSet().toList(growable: false);
  if (wanted.isEmpty) return const {};
  final result = <int, List<Chapter>>{};
  for (final chunk in _chunks(wanted)) {
    final chapters = isar.chapters
        .where()
        .anyOf(chunk, (q, id) => q.mangaIdEqualTo(id))
        .findAllSync();
    for (final chapter in chapters) {
      final mangaId = chapter.mangaId;
      if (mangaId == null) continue;
      (result[mangaId] ??= <Chapter>[]).add(chapter);
    }
  }
  return result;
}
