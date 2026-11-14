import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

/// The single Isar watch over the whole `Manga` collection, shared by every
/// derived provider below.
///
/// `Manga` rows embed the custom cover blob and the full synopsis, so Isar
/// deserializes *both* on every collection read. Opening one independent
/// `isar.mangas.where().watch()` per consumer (library list, each category
/// badge, calendar, extension cards) meant every write re-scanned the whole
/// collection once per watcher and re-decoded every cover blob — N× the work
/// for identical data, on the UI isolate. That is the multi-second freeze felt
/// when tapping a title, which triggers a `put` and therefore fires them all.
///
/// Everything now derives from this one watcher, so a mutation deserializes the
/// collection once. The filtered providers below are `autoDispose`, so when no
/// consumer is watching them Riverpod tears them down and drops the derived
/// list; this root is `autoDispose` too, so when the last consumer leaves the
/// collection is no longer held in memory.
final libraryMangaRootProvider =
    StreamProvider.autoDispose<List<Manga>>((ref) {
  return isar.mangas.where().watch(fireImmediately: true);
});

/// The `mangas` collection keyed by `name\0source\0lang` for the
/// extension-result cover cards.
///
/// Derived from [libraryMangaRootProvider] so it costs no extra Isar watcher.
final libraryMangaByNameProvider =
    Provider.autoDispose<AsyncValue<Map<String, List<Manga>>>>((ref) {
  final root = ref.watch(libraryMangaRootProvider);
  return root.whenData((mangas) {
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
  // Derived from the shared root watch so this costs no extra Isar watcher.
  // isar_community can reject filters on nullable bool properties, so the
  // predicates stay in Dart. While the root is loading we emit nothing and the
  // provider keeps its loading state until the first collection read lands.
  yield* ref.watch(libraryMangaRootProvider).when(
        data: (mangas) => Stream.value(
          mangas
              .where((manga) =>
                  manga.favorite == true &&
                  manga.itemType == itemType &&
                  (categoryId == null ||
                      manga.categories?.contains(categoryId) == true))
              .toList(),
        ),
        loading: () => const Stream<List<Manga>>.empty(),
        error: (error, stackTrace) => Stream<List<Manga>>.error(
          error,
          stackTrace,
        ),
      );
}

@riverpod
Stream<List<Manga>> getAllMangaWithoutCategoriesStream(
  Ref ref, {
  required ItemType itemType,
}) async* {
  yield* ref.watch(libraryMangaRootProvider).when(
        data: (mangas) => Stream.value(
          mangas
              .where((manga) =>
                  manga.favorite == true &&
                  manga.itemType == itemType &&
                  (manga.categories == null || manga.categories!.isEmpty))
              .toList(),
        ),
        loading: () => const Stream<List<Manga>>.empty(),
        error: (error, stackTrace) => Stream<List<Manga>>.error(
          error,
          stackTrace,
        ),
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
