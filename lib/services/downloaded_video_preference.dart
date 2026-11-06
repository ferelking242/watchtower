import 'package:watchtower/models/video.dart';

String displayVideoQuality(String quality) {
  final k = RegExp(r'\b(8k|4k)\b', caseSensitive: false).firstMatch(quality);
  if (k != null) return k.group(1)!.toUpperCase();
  final resolution = RegExp(
    r'(\d{3,4})\s*p?',
    caseSensitive: false,
  ).firstMatch(quality);
  if (resolution != null) return '${resolution.group(1)}p';
  return quality.trim();
}

String videoQualityKey(String quality) =>
    displayVideoQuality(quality).toLowerCase();

/// Tries downloaded files before resolving the same episode from the network.
///
/// Matching online qualities are replaced by their local copy. Remaining
/// online qualities stay available as fallbacks if a downloaded file is bad.
List<Video> mergeDownloadedVideosFirst({
  required List<Video> online,
  required List<Video> downloaded,
}) {
  final downloadedByQuality = <String, Video>{};
  for (final video in downloaded) {
    downloadedByQuality[videoQualityKey(video.quality)] = video;
  }

  final merged = downloadedByQuality.values.toList();
  final seen = downloadedByQuality.keys.toSet();
  for (final video in online) {
    if (seen.add(videoQualityKey(video.quality))) {
      merged.add(video);
    }
  }
  return merged;
}
