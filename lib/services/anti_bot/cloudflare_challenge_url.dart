/// Returns the exact URL that must be opened in the interactive Cloudflare
/// WebView — the URL of the request that was actually blocked.
///
/// It deliberately does NOT rewrite an API endpoint to the site root. Opening
/// the homepage hides the truth: the previous behaviour showed a “challenge”
/// UI while the WebView displayed a perfectly normal landing page. The bypass
/// panel now inspects the rendered page and reports challenge / block / normal
/// explicitly, so the failing URL is the only URL worth opening.
String? resolveCloudflareChallengeUrl(String failedUrl) {
  final uri = Uri.tryParse(failedUrl.trim());
  if (!_isHttpUrl(uri)) return null;
  return failedUrl.trim();
}

bool _isHttpUrl(Uri? uri) =>
    uri != null &&
    uri.host.isNotEmpty &&
    (uri.scheme.toLowerCase() == 'http' ||
        uri.scheme.toLowerCase() == 'https');
