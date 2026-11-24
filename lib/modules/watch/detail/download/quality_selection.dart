import 'package:watchtower/models/video.dart';

/// Resolution-selection strategy when the requested quality is not published
/// by an episode's video list.
enum QualityFallback { exact, higher, lower }

/// Reduces a quality string to just its resolution digits (e.g. "1080p",
/// "1080P", "1080", "FHD 1080p60" → "1080").
///
/// Matching by digits, not by label, keeps a quality chosen in one surface
/// comparable with the same resolution named differently elsewhere (uppercase,
/// a language suffix, a container hint…).
String qualityDigits(String raw) {
  final match = RegExp(r'(\d{3,4})').firstMatch(raw);
  if (match != null) return match.group(1)!;
  return raw.trim().toLowerCase();
}

/// Picks the video whose resolution is the closest to [targetDigits] in the
/// direction asked by [fallback] (higher → smallest resolution above the
/// target, lower → largest below it).
///
/// A target outside the published list falls back to the closest resolution in
/// the *other* direction (the highest for [QualityFallback.higher], the lowest
/// for [QualityFallback.lower]): asking for 1080p on an episode that only has
/// 240/360/720 must still download something instead of failing. Only
/// [QualityFallback.exact] — or a list without any resolution — returns null.
Video? nearestQualityVideo(
  List<Video> videos,
  int targetDigits,
  QualityFallback fallback,
) {
  if (fallback == QualityFallback.exact || targetDigits <= 0) return null;
  Video? best;
  int? bestDigits;
  Video? extreme;
  int? extremeDigits;
  for (final video in videos) {
    final digits = int.tryParse(qualityDigits(video.quality));
    if (digits == null) continue;
    final moreExtreme = extremeDigits == null
        ? true
        : fallback == QualityFallback.higher
        ? digits > extremeDigits
        : digits < extremeDigits;
    if (moreExtreme) {
      extreme = video;
      extremeDigits = digits;
    }
    final fits = fallback == QualityFallback.higher
        ? digits > targetDigits
        : digits < targetDigits;
    if (!fits) continue;
    final closer = bestDigits == null
        ? true
        : fallback == QualityFallback.higher
        ? digits < bestDigits
        : digits > bestDigits;
    if (closer) {
      best = video;
      bestDigits = digits;
    }
  }
  return best ?? extreme;
}

/// Stream to download for a quality picked in the batch sheet, or null when
/// [preferredQuality] is unset or nothing can stand in for it.
///
/// The match runs over [videos] — *every* format the episode published — and
/// only uses [preferredPool] to break a tie: XVideos answers 360p/720p as HLS
/// renditions next to one direct "MP4 SD", so restricting the search to the
/// pool the pipeline would have preferred made a chosen 360p look unavailable.
Video? selectPreferredVideo({
  required List<Video> videos,
  required String? preferredQuality,
  required QualityFallback fallback,
  List<Video>? preferredPool,
}) {
  if (preferredQuality == null || videos.isEmpty) return null;
  final wanted = qualityDigits(preferredQuality);
  final exact = [
    for (final video in videos)
      if (qualityDigits(video.quality) == wanted) video,
  ];
  if (exact.isNotEmpty) {
    final pool = preferredPool;
    if (pool != null) {
      for (final video in exact) {
        if (pool.contains(video)) return video;
      }
    }
    return exact.first;
  }
  return nearestQualityVideo(
    videos,
    int.tryParse(wanted) ?? 0,
    fallback,
  );
}
