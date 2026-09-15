/// Scraper subtitle urls are shaped `/api/v2/subtitles/<provider>/<id>.vtt`, so
/// the segment after `subtitles` identifies who supplied the track. Providers
/// offer many tracks per language and their reliability differs, which is what
/// makes the provider worth showing next to the language.
///
/// Returns the host for urls that are not shaped that way, and an empty string
/// when [url] carries nothing usable.
String subtitleProviderTagForUrl(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return '';
  final segments = uri.pathSegments;
  final markerIndex = segments.indexOf('subtitles');
  // The segment right after the marker is only a provider when something else
  // follows it: in `/subtitles/wyzie/1.vtt` it names the provider, while in
  // `/download/subtitles/movie.vtt` it names the file.
  if (markerIndex >= 0 && markerIndex + 2 <= segments.length - 1) {
    return segments[markerIndex + 1];
  }
  return uri.host.replaceFirst('www.', '');
}
