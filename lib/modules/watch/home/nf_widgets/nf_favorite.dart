// Shared Isar favourite ("Ma liste") helpers for the watch home widgets.
// Mirrors the sourceId-aware disambiguation used by NfBottomSheet and
// pushToMangaReaderDetail so the same record is always targeted.
import 'package:flutter/services.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';

/// Finds the existing Isar [Manga] record for [manga] on [source],
/// or null when it has never been opened / saved.
Manga? findExistingManga(Source source, MManga manga) {
  final name = manga.name?.trim();
  if (name == null || name.isEmpty) return null;
  if (source.lang == null || source.name == null) return null;

  // isar_community 3.x: findFirstSync works on QAfterFilterCondition;
  // findAllSync does not. The combination of lang+name+source is unique
  // enough that the first match is the right one.
  final match = isar.mangas
      .filter()
      .langEqualTo(source.lang)
      .nameEqualTo(name)
      .sourceEqualTo(source.name)
      .findFirstSync();

  if (match == null) return null;
  // If there are multiple records with different sourceIds (rare), prefer
  // the one matching our source; otherwise return the first hit.
  if (match.sourceId != null && match.sourceId != source.id) {
    // Try a second lookup with sourceId included
    final exact = isar.mangas
        .filter()
        .langEqualTo(source.lang)
        .nameEqualTo(name)
        .sourceEqualTo(source.name)
        .sourceIdEqualTo(source.id)
        .findFirstSync();
    if (exact != null) return exact;
  }
  return match;
}

/// Whether [manga] is currently flagged as favourite ("Ma liste").
bool isMangaInList(Source source, MManga manga) =>
    findExistingManga(source, manga)?.favorite ?? false;

/// Toggles the "Ma liste" flag for [manga]; creates the Isar record when the
/// title is not in the library yet. Returns the new state.
bool toggleMangaInList(Source source, MManga manga) {
  HapticFeedback.mediumImpact();
  final name = manga.name?.trim();
  final lang = source.lang;
  final src = source.name;
  if (name == null || name.isEmpty || lang == null || src == null) {
    return false;
  }

  final existing = findExistingManga(source, manga);
  final now = DateTime.now().millisecondsSinceEpoch;

  if (existing == null) {
    final record = Manga(
      imageUrl: manga.imageUrl,
      name: name,
      genre: manga.genre?.map((e) => e.toString()).toList() ?? [],
      author: manga.author ?? '',
      status: manga.status ?? Status.unknown,
      description: manga.description ?? '',
      link: manga.link,
      source: src,
      lang: lang,
      lastUpdate: 0,
      itemType: source.itemType,
      artist: manga.artist ?? '',
      sourceId: source.id,
    );
    isar.writeTxnSync(() {
      isar.mangas.putSync(record..favorite = true..updatedAt = now);
    });
    return true;
  }

  final newVal = !(existing.favorite ?? false);
  isar.writeTxnSync(() {
    isar.mangas.putSync(existing..favorite = newVal..updatedAt = now);
  });
  return newVal;
}
