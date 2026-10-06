import 'dart:convert';

import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/settings.dart' show ChapterPageurls;

/// Nombre maximal d'entrées (chapitres) conservées dans le cache de pages.
///
/// Le cache vit dans l'enregistrement `Settings` (un seul record réécrit en
/// entier à chaque insertion). Sans borne, il grandit indéfiniment (un
/// chapitre = 60+ URLs longues), ce qui rend les écritures de plus en plus
/// lourdes et augmente le risque d'enregistrement corrompu (cf.
/// `settings_store.dart` pour le mécanisme de crash). 50 chapitres récents
/// suffisent pour un usage réel (relecture / téléchargement différé).
const int kMaxChapterPageCacheEntries = 50;

/// Rebuild cached page URLs without assuming the optional headers list is
/// present or aligned with the URL list. Older cache entries may be partial.
List<PageUrl> decodeCachedPageUrls({
  required List<String>? urls,
  List<String>? headers,
}) {
  if (urls == null || urls.isEmpty) {
    return [];
  }

  return List.generate(
    urls.length,
    (index) => PageUrl(
      urls[index],
      headers: _decodeCachedHeaders(headers, index),
    ),
  );
}

Map<String, String>? _decodeCachedHeaders(List<String>? headers, int index) {
  if (headers == null || index >= headers.length) return null;

  try {
    final decoded = jsonDecode(headers[index]);
    if (decoded is! Map) return null;
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  } catch (_) {
    // A malformed optional header must not make otherwise valid page URLs
    // unusable; the downloader can request that page without custom headers.
    return null;
  }
}

/// Store one header entry per URL whenever any page has custom headers.
///
/// Isar stores headers as List<String>, so empty JSON objects preserve the
/// positions of pages without custom headers.
List<String>? encodeCachedPageHeaders(List<PageUrl> pageUrls) {
  if (!pageUrls.any((page) => page.headers != null)) {
    return null;
  }

  return pageUrls
      .map((page) => jsonEncode(page.headers ?? const <String, String>{}))
      .toList();
}

// ── API « entrée de cache » ──────────────────────────────────────────────────
//
// Les quatre fonctions ci-dessous sont les SEULES voies d'accès autorisées au
// cache `chapterPageUrlsList`. Toute lecture passe par [decodeChapterPageurls]
// (tolérante : une entrée quelconque, même corrompue, ne lève jamais), toute
// écriture passe par [mergeChapterPageurls] (garantit l'invariant
// `headers == null || headers.length == urls.length` et borne la taille du
// cache). Les listes parallèles ne peuvent donc plus se désaligner.

/// Décode une entrée de cache Isar en pages utilisables.
///
/// Tolérante par conception : entrée nulle, listes absentes, listes vides,
/// listes de longueurs différentes, JSON malformé ou entrée « null » — aucun
/// de ces cas ne lève d'exception ; les pages valides sont conservées et les
/// headers invalides sont ignorés (page sans headers personnalisés).
List<PageUrl> decodeChapterPageurls(ChapterPageurls? entry) {
  if (entry == null) return [];
  return decodeCachedPageUrls(urls: entry.urls, headers: entry.headers);
}

/// Construit une entrée de cache en garantissant l'invariant d'alignement :
/// `headers == null` ou `headers.length == urls.length`.
ChapterPageurls buildChapterPageurls({
  int? chapterId,
  String? chapterUrl,
  required List<PageUrl> pageUrls,
}) {
  return ChapterPageurls()
    ..chapterId = chapterId
    ..chapterUrl = chapterUrl
    ..urls = pageUrls.map((e) => e.url).toList()
    ..headers = encodeCachedPageHeaders(pageUrls);
}

/// Vrai si [existing] contient déjà exactement [pageUrls] (mêmes URLs, même
/// encodage de headers) — l'écriture dans Isar peut alors être sautée.
///
/// Sans ce garde-fou, chaque ouverture d'un chapitre (même déjà en cache)
/// réécrivait l'intégralité du méga-record `Settings`, ce qui multipliait les
/// occasions d'écriture interrompue pour un bénéfice nul.
bool cachedPagesUnchanged(ChapterPageurls? existing, List<PageUrl> pageUrls) {
  if (existing == null) return false;
  if (!_listEquals(existing.urls, pageUrls.map((e) => e.url).toList())) {
    return false;
  }
  if (!_listEquals(existing.headers, encodeCachedPageHeaders(pageUrls))) {
    return false;
  }
  return true;
}

/// Remplace (ou insère) l'entrée du chapitre [chapterId] dans la liste du
/// cache, en replaçant l'entrée à jour en fin de liste (éviction FIFO des
/// chapitres les plus anciens au-delà de [maxEntries]).
///
/// L'entrée écrite est toujours alignée ([buildChapterPageurls]) : un cache
/// existant désaligné est remplacé, jamais fusionné tel quel.
List<ChapterPageurls> mergeChapterPageurls(
  List<ChapterPageurls>? existing, {
  required int? chapterId,
  required String? chapterUrl,
  required List<PageUrl> pageUrls,
  int maxEntries = kMaxChapterPageCacheEntries,
  Set<int> protectedChapterIds = const <int>{},
}) {
  final merged = <ChapterPageurls>[];
  for (final entry in existing ?? const <ChapterPageurls>[]) {
    if (entry.chapterId != chapterId) merged.add(entry);
  }
  merged.add(
    buildChapterPageurls(
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      pageUrls: pageUrls,
    ),
  );
  while (merged.length > maxEntries) {
    final evictableIndex = merged.indexWhere(
      (entry) =>
          entry.chapterId == null ||
          !protectedChapterIds.contains(entry.chapterId),
    );
    if (evictableIndex == -1) break;
    merged.removeAt(evictableIndex);
  }
  return merged;
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) return identical(a, b);
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
