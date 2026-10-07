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
  return uri
      .replace(userInfo: '', queryParameters: query, fragment: '')
      .toString();
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
