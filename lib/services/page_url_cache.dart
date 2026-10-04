import 'dart:convert';

import 'package:watchtower/models/page.dart';

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
