import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';

/// Resolves the [Manga] behind a [Chapter]'s IsarLink, tolerating a link that
/// was never loaded or that has gone dangling.
///
/// `chapter.manga.value` is only populated once the link has been loaded, but
/// the detail screens feed the reader from `getChaptersStream`, which queries
/// the denormalized `mangaId` index on purpose (the IsarLink traversal is both
/// slower and unreliable when the link was saved from an unloaded state).
/// Reading `.value` alone therefore throws "Null check operator used on a null
/// value" the first time playback or a download resolves a folder or a source.
///
/// [Chapter.mangaId] is always set and never cleared, so it is the reliable
/// fallback. When the fallback is used the link is re-attached so later writes
/// and the UI see it too.
Manga? resolveChapterManga(Chapter chapter) {
  var manga = chapter.manga.value;
  if (manga != null) return manga;
  if (!chapter.manga.isLoaded) {
    try {
      chapter.manga.loadSync();
    } catch (_) {
      // Missing link row: fall back to mangaId below.
    }
    manga = chapter.manga.value;
    if (manga != null) return manga;
  }
  final id = chapter.mangaId;
  if (id == null) return null;
  try {
    manga = isar.mangas.getSync(id);
  } catch (_) {
    return null;
  }
  if (manga != null) {
    chapter.manga.value = manga;
  }
  return manga;
}

/// Guarantees the manga owning [chapter] is readable before it is queued.
///
/// Older databases can hold absent or corrupt links; this turns the
/// deserialization error into an actionable [StateError] instead of letting a
/// generic `RangeError` or a null-assertion surface later.
void ensureChapterLinksLoaded(Chapter chapter) {
  if (resolveChapterManga(chapter) == null) {
    throw StateError(
      'Impossible de lire le manga lié au chapitre '
      '(chapterId=${chapter.id}, mangaId=${chapter.mangaId})',
    );
  }
}

/// Attaches the resolved title to [chapter]'s IsarLink and returns the chapter.
///
/// Readers are handed chapters straight from the detail screens (which stream
/// them by `mangaId` without loading the link), then dereference
/// `chapter.manga.value!` in dozens of places. Resolving once at entry point
/// keeps those dereferences valid without threading a nullable Manga through
/// the whole widget tree.
Chapter attachChapterManga(Chapter chapter) {
  resolveChapterManga(chapter);
  return chapter;
}
