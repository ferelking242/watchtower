/// Returns the website URLs whose cookies can participate in an extension's
/// sign-in flow. The login URL can use a separate host or a path-scoped cookie.
List<String> extensionSessionUrls({
  required String? baseUrl,
  String? loginUrl,
}) {
  final urls = <String>[];
  final seen = <String>{};

  for (final raw in [baseUrl, loginUrl]) {
    final parsed = Uri.tryParse(raw?.trim() ?? '');
    if (parsed == null ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        (parsed.scheme.toLowerCase() != 'http' &&
            parsed.scheme.toLowerCase() != 'https')) {
      continue;
    }

    // Query parameters and fragments are not needed for cookie matching and
    // may contain one-time login state.
    final normalized = Uri(
      scheme: parsed.scheme.toLowerCase(),
      host: parsed.host.toLowerCase(),
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path.isEmpty ? '/' : parsed.path,
    ).toString();
    if (seen.add(normalized)) urls.add(normalized);
  }

  return urls;
}
