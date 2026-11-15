import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';

import 'package:watchtower/main.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';

/// Runs the library swipe action the user configured for the left/right swipe.
///
/// [actionIndex] indexes into [kLibrarySwipeActions].
Future<void> runLibrarySwipeAction(
  WidgetRef ref,
  Manga manga,
  int actionIndex,
) async {
  if (actionIndex < 0 || actionIndex >= kLibrarySwipeActions.length) return;

  switch (actionIndex) {
    case 0: // Marquer le chapitre — first unread chapter only
      await _markChapters(ref, manga, onlyFirstUnread: true);
    case 1: // Marquer comme lu — every chapter
      await _markChapters(ref, manga);
    case 2: // Aucun(e)
      return;
    case 3: // Ajouter à la bibliothèque
      await _addToLibrary(manga);
    case 4: // Télécharger — first unread chapter
      await _downloadFirstUnread(ref, manga);
    case 5: // Partager
      await _share(manga);
  }
}

/// Chapters of [manga], read through the denormalized `mangaId` index.
///
/// The lazy `manga.chapters` backlink runs a full synchronous chapter load on
/// the UI isolate, which is felt as a freeze on the swipe action.
List<Chapter> _chaptersOf(Manga manga) {
  final id = manga.id;
  if (id == null) return const [];
  return isar.chapters.where().mangaIdEqualTo(id).findAllSync();
}

Future<void> _downloadFirstUnread(WidgetRef ref, Manga manga) async {
  final chapters = _chaptersOf(manga);
  if (chapters.isEmpty) return;
  final target = chapters.firstWhere(
    (c) => !(c.isRead ?? false),
    orElse: () => chapters.first,
  );
  await ref.read(addDownloadToQueueProvider(chapter: target).future);
}

/// Marks chapters as read and persists both chapters and the parent manga.
Future<void> _markChapters(
  WidgetRef ref,
  Manga manga, {
  bool onlyFirstUnread = false,
}) async {
  final chapters = _chaptersOf(manga);
  if (chapters.isEmpty) return;

  final targets = onlyFirstUnread
      ? chapters.where((c) => !(c.isRead ?? false)).take(1).toList()
      : chapters;
  if (targets.isEmpty) return;

  final now = DateTime.now().millisecondsSinceEpoch;
  for (final chapter in targets) {
    chapter.isRead = true;
    chapter.lastPageRead = '1';
    chapter.updatedAt = now;
    chapter.manga.value = manga;
    chapter.updateTrackChapterRead(ref);
  }
  manga.lastRead = now;
  manga.updatedAt = now;

  isar.writeTxnSync(() {
    isar.chapters.putAllSync(targets);
    isar.mangas.putSync(manga);
  });
}

Future<void> _addToLibrary(Manga manga) async {
  if (manga.favorite == true) return;
  manga.favorite = true;
  manga.dateAdded = DateTime.now().millisecondsSinceEpoch;
  manga.updatedAt = manga.dateAdded;
  isar.writeTxnSync(() => isar.mangas.putSync(manga));
}

Future<void> _share(Manga manga) async {
  final name = manga.name ?? '';
  final link = manga.link ?? '';
  final text = link.isEmpty ? name : '$name\n$link';
  if (text.trim().isEmpty) return;
  await SharePlus.instance.share(ShareParams(text: text));
}
