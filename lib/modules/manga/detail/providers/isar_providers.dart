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
  yield* isar.chapters
      .filter()
      .manga((q) => q.idEqualTo(mangaId))
      .watch(fireImmediately: true);
}
