/// Removes authentication material before request metadata is persisted.
///
/// Page URLs and headers can contain short-lived credentials even when the
/// extension does not use a browser login. Keep those values in memory for the
/// active request, but do not put them in Isar or chapter manifest files.
bool isSensitiveRequestField(String name) {
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('token') ||
      normalized.contains('authorization') ||
      normalized.contains('auth') ||
      normalized.contains('signature') ||
      normalized == 'sig' ||
      normalized.contains('secret') ||
      normalized.contains('password') ||
      normalized.contains('cookie') ||
      normalized.contains('session') ||
      normalized.contains('credential') ||
      normalized == 'key' ||
      normalized.endsWith('key') ||
      normalized.contains('jwt');
}

String sanitizePersistedUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return '';

  final query = <String, dynamic>{};
  for (final entry in uri.queryParametersAll.entries) {
    if (!isSensitiveRequestField(entry.key)) {
      query[entry.key] = entry.value;
    }
  }
  // Rebuild the URI instead of using Uri.replace: replace always emits the
  // query and fragment separators it was given, so an empty query turned
  // "https://host/page" into "https://host/page?#" and broke every cached
  // page URL. Passing null keeps absent components absent.
  return Uri(
    scheme: uri.scheme.isEmpty ? null : uri.scheme,
    host: uri.hasAuthority ? uri.host : null,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// A query parameter whose value rotates on every request while the resource
/// behind the URL does not (CDN signatures, expiry stamps, replay nonces).
bool _isVolatileQueryName(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return n.endsWith('expires') ||
      n.endsWith('expiry') ||
      n.endsWith('timestamp') ||
      n.endsWith('nonce') ||
      n == 'date' ||
      n == 'ts' ||
      n == 'e';
}

/// The URL reduced to the parts that actually identify the resource, for use
/// as a cache key.
///
/// A signed CDN URL carries a rotating token and an expiry stamp in the query
/// string, so keying on the raw URL made every request miss the cache entry it
/// had just written and re-download forever — the same failure the header
/// fingerprint avoids for credentials. Only the *key* is reduced: the request
/// still goes out with the full, signed URL.
String cacheKeyUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasQuery) return raw;

  final query = <String, dynamic>{};
  for (final entry in uri.queryParametersAll.entries) {
    if (isSensitiveRequestField(entry.key)) continue;
    if (_isVolatileQueryName(entry.key)) continue;
    query[entry.key] = entry.value;
  }
  if (query.length == uri.queryParametersAll.length) return raw;
  return Uri(
    scheme: uri.scheme.isEmpty ? null : uri.scheme,
    host: uri.hasAuthority ? uri.host : null,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

String safeUrlOriginForLog(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
    return '<url>';
  }
  return '${uri.scheme}://${uri.host}';
}

Map<String, String> sanitizePersistedHeaders(Map<String, String>? headers) => {
  for (final entry in headers?.entries ?? const <MapEntry<String, String>>[])
    if (!isSensitiveRequestField(entry.key)) entry.key: entry.value,
};
