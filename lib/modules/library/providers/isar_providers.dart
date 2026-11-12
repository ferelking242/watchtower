import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

/// One Isar watch over the whole `Manga` collection, keyed by
/// `name\0source\0lang` for the extension-result cover cards.
///
/// `MangaImageCardWidget` used to open one filtered `.watch()` **per visible
/// card** to find the library row behind an extension result. `Manga` has no
/// indexes, so each of those watchers re-ran a full collection scan, and every
/// write fired all of them at once — N native scans per mutation while a grid
/// of results was on screen. A single shared watcher gives the same
/// information; each card resolves its row with a map lookup.
final libraryMangaByNameProvider =
    StreamProvider.autoDispose<Map<String, List<Manga>>>((ref) {
  return isar.mangas.where().watch(fireImmediately: true).map((mangas) {
    final byKey = <String, List<Manga>>{};
    for (final manga in mangas) {
      final name = manga.name;
      if (name == null) continue;
      (byKey['$name\u0000${manga.source}\u0000${manga.lang}'] ??= <Manga>[])
          .add(manga);
    }
    return byKey;
  });
});

/// Resolves the library rows behind an extension result from the shared
/// [libraryMangaByNameProvider] map, keeping the exact `sourceId` fallback the
/// old per-card query used (a row with a null `sourceId` matches any source).
List<Manga> libraryRowsFor(
  Map<String, List<Manga>>? byName, {
  required String? name,
  required String? source,
  required String? lang,
  required int? sourceId,
}) {
  if (name == null) return const [];
  final rows = byName?['$name\u0000$source\u0000$lang'];
  if (rows == null || rows.isEmpty) return const [];
  return rows
      .where((e) => e.sourceId == null ? true : e.sourceId == sourceId)
      .toList();
}

@riverpod
Stream<List<Manga>> getAllMangaStream(
  Ref ref, {
  required int? categoryId,
  required ItemType itemType,
}) async* {
  // isar_community can reject filters on nullable bool properties. Observe
  // the collection without a filter and keep the same predicates in Dart.
  yield* isar.mangas.where().watch(fireImmediately: true).map(
        (mangas) => mangas
            .where((manga) =>
                manga.favorite == true &&
                manga.itemType == itemType &&
                (categoryId == null ||
                    manga.categories?.contains(categoryId) == true))
            .toList(),
      );
}

@riverpod
Stream<List<Manga>> getAllMangaWithoutCategoriesStream(
  Ref ref, {
  required ItemType itemType,
}) async* {
  yield* isar.mangas.where().watch(fireImmediately: true).map(
        (mangas) => mangas
            .where((manga) =>
                manga.favorite == true &&
                manga.itemType == itemType &&
                (manga.categories == null || manga.categories!.isEmpty))
            .toList(),
      );
}

@riverpod
Stream<List<Settings>> getSettingsStream(Ref ref) async* {
  yield* isar.settings
      .where()
      .idEqualTo(227)
      .watch(fireImmediately: true);
}

/// One Isar watch over the whole `History` collection, reduced to a
/// `mangaId -> History` map.
///
/// The library grid/list used to open one `StreamBuilder` (i.e. one native
/// Isar query watcher) *per visible card* to find its continue-reading chapter.
/// On a large library that is dozens of watchers firing on every write, all on
/// the UI isolate. A single watcher shared by the whole page gives the same
/// information at a fraction of the cost.
@riverpod
Stream<Map<int, History>> libraryHistoryByManga(Ref ref) {
  return isar.historys.where().watch(fireImmediately: true).map((histories) {
    final byManga = <int, History>{};
    for (final history in histories) {
      final mangaId = history.mangaId;
      if (mangaId == null) continue;
      // There is one History row per manga; keep the newest if that ever
      // changes so the "continue" button always resumes the latest chapter.
      final existing = byManga[mangaId];
      if (existing == null ||
          (int.tryParse(history.date ?? '') ?? 0) >=
              (int.tryParse(existing.date ?? '') ?? 0)) {
        byManga[mangaId] = history;
      }
    }
    return byManga;
  });
}
