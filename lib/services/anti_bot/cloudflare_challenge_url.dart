/// Chooses a top-level page for the interactive Cloudflare WebView.
///
/// Failed extension requests are often API endpoints or subresources, which
/// may return a plain denial instead of Cloudflare's browser challenge page.
/// Prefer the installed source's landing URL; otherwise use the failed
/// request's origin.
String? resolveCloudflareChallengeUrl(
  String failedUrl, {
  String? sourceBaseUrl,
}) {
  final sourceUri = Uri.tryParse(sourceBaseUrl?.trim() ?? '');
  if (_isHttpUrl(sourceUri)) {
    return Uri(
      scheme: sourceUri!.scheme.toLowerCase(),
      host: sourceUri.host,
      port: sourceUri.hasPort ? sourceUri.port : null,
      path: sourceUri.path.isEmpty ? '/' : sourceUri.path,
    ).toString();
  }

  final failedUri = Uri.tryParse(failedUrl.trim());
  if (!_isHttpUrl(failedUri)) return null;
  return Uri(
    scheme: failedUri!.scheme.toLowerCase(),
    host: failedUri.host,
    port: failedUri.hasPort ? failedUri.port : null,
    path: '/',
  ).toString();
}

bool _isHttpUrl(Uri? uri) =>
    uri != null &&
    uri.host.isNotEmpty &&
    (uri.scheme.toLowerCase() == 'http' ||
        uri.scheme.toLowerCase() == 'https');