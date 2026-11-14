import 'dart:math';

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

/// Below this many manga ids, `anyOf` (one index seek per id) is cheaper than
/// walking the whole `[min, max]` index range; above it the single range walk
/// wins by an order of magnitude. Measured crossover on a 50 000-chapter
/// database sits between 25 and 50 ids.
const int _kIndexSeekThreshold = 25;

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

/// Loads the chapters of [mangaIds] grouped by `mangaId`. `Manga.chapters` is a
/// lazy `IsarLinks` backlink: touching it runs a synchronous Isar query per
/// manga, which is an O(manga) N+1 when a filter or sort reads it for the whole
/// library.
///
/// The grouping order matches what the old per-manga backlink produced, so
/// order-dependent consumers (`lastOrNull` in the library sort, the reader) are
/// unaffected.
Map<int, List<Chapter>> loadChaptersByMangaIds(Iterable<int?> mangaIds) {
  final wanted = mangaIds.whereType<int>().toSet();
  if (wanted.isEmpty) return const {};
  final result = <int, List<Chapter>>{};

  // `anyOf` walks the `mangaId` index once *per id* (O(k) seeks): measured at
  // 376 ms for 500 ids on a 50 000-chapter database, which is the dominant cost
  // of the library filter/sort that re-runs on every rebuild. A single indexed
  // range walk over [min, max] returns the same per-manga order in ~34 ms, so
  // it is used past a small id count where `anyOf` is still the cheaper option
  // (it avoids scanning the whole range for a couple of ids).
  if (wanted.length <= _kIndexSeekThreshold) {
    final rows = isar.chapters
        .where()
        .anyOf(wanted.toList(growable: false), (q, id) => q.mangaIdEqualTo(id))
        .findAllSync();
    for (final chapter in rows) {
      final mangaId = chapter.mangaId;
      if (mangaId == null) continue;
      (result[mangaId] ??= <Chapter>[]).add(chapter);
    }
    return result;
  }

  final lo = wanted.reduce(min);
  final hi = wanted.reduce(max);
  final rows = isar.chapters.where().mangaIdBetween(lo, hi).findAllSync();
  for (final chapter in rows) {
    final mangaId = chapter.mangaId;
    if (mangaId == null || !wanted.contains(mangaId)) continue;
    (result[mangaId] ??= <Chapter>[]).add(chapter);
  }
  return result;
}
