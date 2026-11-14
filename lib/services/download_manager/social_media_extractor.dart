/// Extracts a direct media URL from a public social video page **without any
/// platform API** — by reading the Open Graph / Twitter-card meta tags and the
/// JSON blobs the page embeds for its own player.
///
/// This is the no-Python fallback path: when the ZeusDL runtime is not
/// installed, a pasted TikTok/Facebook link can still be resolved to an `.mp4`
/// and downloaded by the internal engine. When ZeusDL *is* available it is
/// preferred, because a real extractor strips the TikTok watermark and picks
/// the best rendition.
///
/// [extractMediaUrl] is pure (HTML in, URL out) so it is unit-tested without a
/// device; [SocialMediaExtractor.resolve] only adds the HTTP fetch.
library;

import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

abstract final class SocialMediaExtractor {
  /// A desktop UA — mobile UAs are frequently served a "open the app" shell
  /// with no media metadata.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// Ordered regex strategies. The first non-empty, http(s) match wins.
  ///
  /// Order matters: `og:video:secure_url` and `playAddr` are the reliable ones
  /// for TikTok/Facebook; the rest are best-effort for other platforms.
  static final List<RegExp> _patterns = [
    // <meta property="og:video:secure_url" content="https://…">
    RegExp(
      r'''<meta[^>]+property=["']og:video:secure_url["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:video:secure_url["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+property=["']og:video(?::url)?["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:video(?::url)?["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+name=["']twitter:player:stream["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    // Embedded player JSON (TikTok `playAddr`, Facebook `playable_url`).
    RegExp(r'''"playAddr"\s*:\s*"([^"]+)"'''),
    RegExp(r'''"playable_url(?:_quality_hd)?"\s*:\s*"([^"]+)"'''),
    RegExp(r'''"contentUrl"\s*:\s*"([^"]+)"'''),
    RegExp(r'''"downloadAddr"\s*:\s*"([^"]+)"'''),
  ];

  /// Returns the first direct media URL found in [html], or null.
  ///
  /// Decodes the JSON/HTML escaping (`\u002F`, `\/`, `&amp;`) that the embedded
  /// blobs use, so the caller gets a URL it can hand to an HTTP client.
  static String? extractMediaUrl(String html) {
    if (html.isEmpty) return null;
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(html);
      final raw = match?.group(1);
      if (raw == null) continue;
      final url = _decode(raw);
      if (_looksLikeMedia(url)) return url;
    }
    return null;
  }

  /// Fetches [pageUrl] and returns the direct media URL it advertises.
  ///
  /// Throws [SocialExtractionException] when the page carries no media URL
  /// (private/deleted post, or a page shape this lightweight parser does not
  /// recognise — the ZeusDL runtime handles those).
  static Future<String> resolve(String pageUrl) async {
    final client = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    final uri = Uri.parse(pageUrl);
    final response = await client.get(
      uri,
      headers: {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );
    if (response.statusCode != 200) {
      throw SocialExtractionException(
        'HTTP ${response.statusCode} while fetching the page',
      );
    }
    final media = extractMediaUrl(response.body);
    if (media == null) {
      AppLogger.log(
        'SocialMediaExtractor: no media URL on ${uri.host}',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
      throw const SocialExtractionException(
        'No downloadable media found on this page. Install the ZeusDL runtime '
        'for extractor-grade support (private posts, watermark removal).',
      );
    }
    return media;
  }

  static String _decode(String value) {
    return value
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u002f', '/')
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(r'\u003A', ':')
        .trim();
  }

  static bool _looksLikeMedia(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    return true;
  }
}

class SocialExtractionException implements Exception {
  final String message;
  const SocialExtractionException(this.message);

  @override
  String toString() => message;
}
