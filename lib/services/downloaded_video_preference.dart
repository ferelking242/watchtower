import 'package:watchtower/models/video.dart';

/// Language tags a source may append to a quality label (`720p VF`,
/// `1080p VOSTFR`, `720p FR`, …). Matched case-insensitively on word
/// boundaries so `VOSTFR` is not read as `FR`.
final RegExp _languageRe = RegExp(
  r'\b(VOSTFR|VOSTA|VFF|VF|VO|MULTI|TRUEFRENCH|FRENCH|FR|EN|ENG|ANGLAIS|'
  r'ESPA[NÑ]OL|ESP|ES|DEUTSCH|GER|DE|ITALIANO|ITA|IT|PORTUGU[ÊE]S|PT|'
  r'JAPONAIS|JAP|JP|ARABE|AR|RUSSE|RU|TURC|TR)\b',
  caseSensitive: false,
);

/// The language a quality label carries, or `null` when it carries none.
///
/// Sources spell this differently (`VF`, `VOSTFR`, `French`, …) and sometimes
/// put it in the quality string (`720p VF`) rather than in the audio track
/// list, so the player reads it from the label to offer a language box for
/// downloads too.
String? videoLanguageOf(String quality) {
  final match = _languageRe.firstMatch(quality);
  return match?.group(1)?.toUpperCase();
}

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

/// Identity of a rendition for de-duplication.
///
/// Resolution alone is not enough: a user who downloaded the same episode in
/// two languages ends up with two `720p` files, and collapsing them on `720p`
/// silently dropped one of them (and with it any way to pick the other audio).
/// The language tag is therefore part of the key when the label has one.
String videoQualityKey(String quality) {
  final base = displayVideoQuality(quality).toLowerCase();
  final lang = videoLanguageOf(quality);
  return lang == null ? base : '$base|${lang.toLowerCase()}';
}

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
