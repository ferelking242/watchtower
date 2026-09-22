import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'calendar_provider.g.dart';

@riverpod
Stream<List<Manga>> getCalendarStream(Ref ref, {ItemType? itemType}) async* {
  const eligibleStatuses = {
    Status.ongoing,
    Status.unknown,
    Status.publishingFinished,
  };

  // isar_community can reject filters on nullable bool properties. Observe
  // the collection without a filter and keep the same predicates in Dart.
  yield* isar.mangas.where().watch(fireImmediately: true).map(
        (mangas) => mangas
            .where((manga) =>
                manga.favorite == true &&
                manga.itemType == (itemType ?? ItemType.manga) &&
                eligibleStatuses.contains(manga.status) &&
                (manga.smartUpdateDays ?? 0) > 0)
            .toList(),
      );
}
