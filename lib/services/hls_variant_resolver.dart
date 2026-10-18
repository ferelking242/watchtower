import 'package:watchtower/models/video.dart';

/// Expands an HLS *master* playlist into one [Video] per variant, plus a
/// leading adaptive entry.
///
/// Extensions report a single `quality: "Auto"` entry for an `.m3u8` URL, but
/// that URL is usually a master playlist listing every rendition the CDN
/// offers. Without parsing it the quality picker shows one opaque "Auto" line
/// (or worse, a hard-coded lie like the `mp4_high`/720p label on xnxx, which
/// actually serves 360p) and the user cannot choose 1080p even though the
/// stream carries it.
///
/// The first returned entry keeps [Video.quality] as the adaptive master so
/// the player can hand the whole playlist to libmpv; the following entries
/// point at individual variant playlists so a fixed resolution can be forced.
class HlsVariantResolver {
  /// Master playlists are identified by `#EXT-X-STREAM-INF`, which only
  /// appears in a variant list - never in a media playlist.
  static const _streamInf = '#EXT-X-STREAM-INF:';

  /// `RESOLUTION=1920x1080` → 1080.
  static final _resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)');

  /// `BANDWIDTH=1327104` → 1327104.
  static final _bandwidth = RegExp(r'BANDWIDTH=(\d+)');

  /// `NAME="720p"` when the CDN labels its renditions.
  static final _name = RegExp(r'NAME="([^"]*)"');

  /// True when [body] is an HLS master (variant) playlist rather than a media
  /// playlist listing segments.
  static bool isMasterPlaylist(String body) =>
      body.contains(_streamInf) && body.contains('#EXTM3U');

  /// Parses [body] and returns the variants ordered by descending bandwidth
  /// (best first), each labelled by its vertical resolution.
  ///
  /// Returns an empty list when [body] is not a master playlist or lists no
  /// usable variant, so callers can fall back to the extension's own entry.
  static List<HlsVariant> parseMaster(String body, {required Uri masterUrl}) {
    if (!isMasterPlaylist(body)) return const [];

    final variants = <HlsVariant>[];
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith(_streamInf)) continue;

      // The URI of a variant is the next non-empty, non-tag line.
      String? uri;
      for (var j = i + 1; j < lines.length; j++) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty) continue;
        if (candidate.startsWith('#')) break;
        uri = candidate;
        break;
      }
      if (uri == null) continue;

      final resMatch = _resolution.firstMatch(line);
      final bwMatch = _bandwidth.firstMatch(line);
      final nameMatch = _name.firstMatch(line);

      final height = resMatch == null ? null : int.tryParse(resMatch.group(2)!);
      final bandwidth = bwMatch == null ? null : int.tryParse(bwMatch.group(1)!);
      // Prefer the CDN's own label, then the resolution, then the bitrate.
      final label = _labelFor(nameMatch?.group(1), height, bandwidth);
      if (label == null) continue;

      variants.add(
        HlsVariant(
          url: masterUrl.resolve(uri).toString(),
          label: label,
          height: height,
          bandwidth: bandwidth,
        ),
      );
    }

    variants.sort((a, b) => (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0));
    return variants;
  }

  static String? _labelFor(String? name, int? height, int? bandwidth) {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (height != null) return '${height}p';
    if (bandwidth != null) {
      // No resolution declared: fall back to the rounded kbps so the entry
      // stays distinguishable and ordered.
      return '${(bandwidth / 1000).round()} kbps';
    }
    return null;
  }
}

/// A single rendition listed by an HLS master playlist.
class HlsVariant {
  final String url;
  final String label;

  /// Vertical resolution, when the playlist declares one.
  final int? height;

  /// Advertised peak bitrate in bits/s, used to pick a rendition that fits
  /// the measured throughput.
  final int? bandwidth;

  const HlsVariant({
    required this.url,
    required this.label,
    this.height,
    this.bandwidth,
  });
}

/// Rewrites a single adaptive HLS entry into the full variant list.
///
/// [videos] is the extension's own list and [fetchPlaylist] retrieves a
/// playlist body (injected so this stays testable and so the caller controls
/// headers/timeouts). The adaptive master always stays first: it is the only
/// entry that lets libmpv switch renditions mid-playback.
///
/// Never throws: on any failure the original list is returned untouched, so a
/// CDN hiccup can only cost the extra quality entries, never playback.
Future<List<Video>> expandHlsVariants(
  List<Video> videos, {
  required Future<String?> Function(String url) fetchPlaylist,
}) async {
  if (videos.isEmpty) return videos;

  final masterIndex = videos.indexWhere(_looksLikeHls);
  if (masterIndex < 0) return videos;

  final master = videos[masterIndex];
  String? body;
  try {
    body = HlsPlaylistCache.get(master.url) ?? await fetchPlaylist(master.url);
  } catch (_) {
    return videos;
  }
  if (body == null) return videos;
  HlsPlaylistCache.put(master.url, body);

  final Uri? masterUri = Uri.tryParse(master.url);
  if (masterUri == null) return videos;

  final variants = HlsVariantResolver.parseMaster(body, masterUrl: masterUri);
  if (variants.isEmpty) return videos;

  // Ascending bitrate: the entries double as fallbacks for the adaptive
  // master, and a fallback should step *down* rather than land on a rendition
  // as heavy as the one that just failed.
  final ordered = variants
      .where((variant) => variant.bandwidth != null)
      .toList()
    ..sort((a, b) => a.bandwidth!.compareTo(b.bandwidth!));
  final orderedUrls = {for (final variant in ordered) variant.url};

  // Keep the extension's label for the adaptive entry (it may carry extra
  // meaning such as "Auto · ZeusDL"), and add one fixed entry per rendition.
  final expanded = <Video>[
    master,
    for (final variant in ordered)
      if (variant.url != master.url)
        Video(
          variant.url,
          variant.label,
          variant.url,
          headers: master.headers,
        ),
    // Renditions the master did not describe (no BANDWIDTH) keep their file
    // order rather than being dropped.
    for (final variant in variants)
      if (variant.bandwidth == null &&
          variant.url != master.url &&
          !orderedUrls.contains(variant.url))
        Video(
          variant.url,
          variant.label,
          variant.url,
          headers: master.headers,
        ),
  ];

  // Rebuild in place so the caller's ordering (extension preference, then
  // `_applySourcePreferences`) still applies to the new entries.
  return [
    for (final video in videos)
      if (identical(video, master)) ...expanded else video,
  ];
}

bool _looksLikeHls(Video video) {
  final url = video.url.toLowerCase();
  return url.contains('.m3u8') || video.quality.toLowerCase() == 'auto';
}

/// Short-lived cache of fetched playlist bodies.
///
/// One startup reads the same master playlist twice: [expandHlsVariants]
/// fetches it to enumerate the renditions, then the player's ABR probe fetches
/// it again to measure the connection. Both happen within a second of each
/// other and a signed master URL is immutable for its lifetime, so the second
/// fetch is pure latency on the tap-to-play path — the very path this player
/// exists to shorten.
///
/// Deliberately tiny and time-bounded: entries expire after [ttl] and the map
/// never holds more than [maxEntries], so this can only ever save a request,
/// never serve a stale rendition list to a later session.
class HlsPlaylistCache {
  HlsPlaylistCache._();

  /// How long a fetched body stays reusable. Long enough to cover the gap
  /// between `getVideoList` and the player's first `open()`, short enough that
  /// a retry or a re-entered screen refetches.
  static Duration ttl = const Duration(seconds: 30);

  static const int maxEntries = 16;

  static final Map<String, _HlsCacheEntry> _entries = {};

  /// Returns the cached body for [url], or `null` when absent or expired.
  static String? get(String url) {
    final entry = _entries[url];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _entries.remove(url);
      return null;
    }
    return entry.body;
  }

  /// Stores [body] for [url], evicting the oldest entry beyond [maxEntries].
  static void put(String url, String body) {
    _entries[url] = _HlsCacheEntry(body, DateTime.now());
    if (_entries.length <= maxEntries) return;
    final oldest = _entries.entries.reduce(
      (a, b) => a.value.storedAt.isBefore(b.value.storedAt) ? a : b,
    );
    _entries.remove(oldest.key);
  }

  /// Drops every entry. For tests and for callers that know a URL changed.
  static void clear() => _entries.clear();
}

class _HlsCacheEntry {
  final String body;
  final DateTime storedAt;

  const _HlsCacheEntry(this.body, this.storedAt);
}
