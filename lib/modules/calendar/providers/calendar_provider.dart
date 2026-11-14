import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'calendar_provider.g.dart';

@riverpod
Stream<List<Manga>> getCalendarStream(Ref ref, {ItemType? itemType}) async* {
  const eligibleStatuses = {
    Status.ongoing,
    Status.unknown,
    Status.publishingFinished,
  };

  // Derived from the shared collection watch (see [libraryMangaRootProvider])
  // so the calendar does not open a second full scan of `mangas` — which would
  // re-deserialize every custom cover blob on each write.
  yield* ref.watch(libraryMangaRootProvider).when(
        data: (mangas) => Stream.value(
          mangas
              .where((manga) =>
                  manga.favorite == true &&
                  manga.itemType == (itemType ?? ItemType.manga) &&
                  eligibleStatuses.contains(manga.status) &&
                  (manga.smartUpdateDays ?? 0) > 0)
              .toList(),
        ),
        loading: () => const Stream<List<Manga>>.empty(),
        error: (error, stackTrace) => Stream<List<Manga>>.error(
          error,
          stackTrace,
        ),
      );
}
