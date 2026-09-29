import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

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
      .filter()
      .idEqualTo(227)
      .watch(fireImmediately: true);
}
