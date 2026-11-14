/// Recognises the social video platforms Watchtower can hand to the ZeusDL
/// runtime (yt-dlp-style extractors), so a pasted TikTok/Facebook link opens
/// the right one-tap download flow instead of being treated as a direct file.
///
/// No platform API is involved: the extractor fetches the public page and pulls
/// the media URL out of it. This helper only classifies the *link* — it does no
/// network I/O, which keeps it unit-testable.
library;

enum SocialPlatform {
  tiktok,
  facebook,
  instagram,
  twitter,
  youtube,
  reddit,
  other,
}

extension SocialPlatformExt on SocialPlatform {
  String get label {
    switch (this) {
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.twitter:
        return 'X (Twitter)';
      case SocialPlatform.youtube:
        return 'YouTube';
      case SocialPlatform.reddit:
        return 'Reddit';
      case SocialPlatform.other:
        return 'Vidéo';
    }
  }

  /// Whether the platform stamps a watermark the extractor can strip.
  bool get hasWatermark => this == SocialPlatform.tiktok;

  /// Reverse-DNS id of the bundled downloader plugin that handles it.
  String get pluginId {
    switch (this) {
      case SocialPlatform.tiktok:
        return 'en.tiktok-downloader';
      case SocialPlatform.facebook:
        return 'en.facebook-downloader';
      case SocialPlatform.instagram:
        return 'en.instagram-downloader';
      case SocialPlatform.twitter:
        return 'en.twitter-downloader';
      case SocialPlatform.youtube:
        return 'en.youtube-downloader';
      case SocialPlatform.reddit:
        return 'en.reddit-downloader';
      case SocialPlatform.other:
        return 'en.media-downloader';
    }
  }
}

/// Matches a pasted URL against the supported platforms.
abstract final class SocialUrlDetector {
  static const _hosts = <String, SocialPlatform>{
    'tiktok.com': SocialPlatform.tiktok,
    'vm.tiktok.com': SocialPlatform.tiktok,
    'vt.tiktok.com': SocialPlatform.tiktok,
    'm.tiktok.com': SocialPlatform.tiktok,
    'facebook.com': SocialPlatform.facebook,
    'm.facebook.com': SocialPlatform.facebook,
    'fb.watch': SocialPlatform.facebook,
    'fb.com': SocialPlatform.facebook,
    'instagram.com': SocialPlatform.instagram,
    'instagr.am': SocialPlatform.instagram,
    'twitter.com': SocialPlatform.twitter,
    'x.com': SocialPlatform.twitter,
    't.co': SocialPlatform.twitter,
    'youtube.com': SocialPlatform.youtube,
    'youtu.be': SocialPlatform.youtube,
    'm.youtube.com': SocialPlatform.youtube,
    'reddit.com': SocialPlatform.reddit,
    'redd.it': SocialPlatform.reddit,
  };

  /// Returns the platform for [url], or null when the link is not a recognised
  /// social video URL (a direct `.mp4`, an HLS playlist, a random page, …).
  static SocialPlatform? detect(String url) {
    final host = _hostOf(url);
    if (host == null) return null;
    if (_hosts.containsKey(host)) return _hosts[host];
    // Match sub-domains (e.g. `www.tiktok.com`, `web.facebook.com`).
    for (final entry in _hosts.entries) {
      if (host.endsWith('.${entry.key}')) return entry.value;
    }
    return null;
  }

  /// Convenience predicate for callers that only branch on "is this social?".
  static bool isSocial(String url) => detect(url) != null;

  static String? _hostOf(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    var uri = Uri.tryParse(trimmed);
    // A bare `vm.tiktok.com/xyz` has no scheme; retry with one prepended.
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
    }
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host.toLowerCase();
  }
}
