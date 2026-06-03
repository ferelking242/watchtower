import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'isar_providers.g.dart';

@riverpod
Stream<Manga?> getMangaDetailStream(Ref ref, {required int mangaId}) async* {
  yield* isar.mangas.watchObject(mangaId, fireImmediately: true);
}

@riverpod
Stream<List<Chapter>> getChaptersStream(
  Ref ref, {
  required int mangaId,
}) async* {
  if (kIsWeb) {
    // MockIsar ignores all filter predicates — fetch everything and
    // filter client-side by mangaId so each detail page sees only its own episodes.
    final all = await isar.chapters.filter().idIsNotNull().findAll();
    yield all.where((c) => c.mangaId == mangaId).toList();
    return;
  }
  // Use mangaIdEqualTo (denormalized field) instead of the IsarLink traversal.
  // The IsarLink path (.manga((q) => q.idEqualTo(mangaId))) can return an empty
  // result if the link was not properly persisted (e.g. saveSync() called on an
  // unloaded IsarLink clears the relationship).  The mangaId field is always set
  // when a chapter is created and is never cleared, so it is the safe source.
  yield* isar.chapters
      .filter()
      .mangaIdEqualTo(mangaId)
      .watch(fireImmediately: true);
}
