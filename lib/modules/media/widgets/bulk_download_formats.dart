import 'dart:math' as math;

import 'package:watchtower/main.dart' show isar;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/watch/detail/download/video_file_meta.dart';
import 'package:watchtower/modules/watch/detail/download/video_meta_cache.dart';

/// Reduces a quality label to its resolution digits (e.g. `"1080p60"` → `1080`).
///
/// Matching by digits, not by label, keeps a quality chosen in one surface
/// comparable with the same resolution named differently elsewhere (uppercase,
/// a language suffix, a container hint…).
String resolutionKey(String raw) {
  final match = RegExp(r'(\d{3,4})').firstMatch(raw);
  return match == null ? raw.trim().toLowerCase() : match.group(1)!;
}

/// Human-readable size of a byte count (`"259.9MB"`, `"4.1GB"`), or null.
String? formatVideoBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  final label = formatBytes(bytes);
  return label.isEmpty ? null : label;
}

/// Size of one concrete stream, without downloading it.
///
/// * HLS media playlist → weight of its segments (exact when the playlist
///   declares `#EXT-X-BYTERANGE`, estimated from a few `Content-Range` probes
///   otherwise).
/// * Direct file → exact `Content-Range` total.
///
/// Both go through the shared per-URL cache, so a size measured for the
/// download sheet is reused here and never probed twice.
Future<String?> probeStreamSize(Video video) async {
  try {
    if (isHlsUrl(video.url)) {
      final meta = await cachedHlsMeta(video.url, video.headers);
      final playlist = meta?.playlistBytesEstimate;
      if (playlist != null && playlist > 0) return formatVideoBytes(playlist);
      final tracks = meta?.tracks ?? const [];
      if (tracks.isNotEmpty) {
        final best = tracks
            .map((track) => track.estimatedBytes ?? 0)
            .fold<int>(0, math.max);
        return formatVideoBytes(best);
      }
      return null;
    }
    return formatVideoBytes(await fetchDirectFileSize(video.url, video.headers));
  } catch (_) {
    // A size is a display nicety: a refused probe must never fail the row.
    return null;
  }
}

/// Weights of every distinct resolution in [videos], keyed by [resolutionKey].
///
/// The probes run in a bounded pool rather than one after another: the whole
/// point of showing a size is that it arrives with the format list, not after
/// a minute of serial round-trips.
Future<Map<String, String>> probeFormatSizes(
  List<Video> videos, {
  int concurrency = 6,
}) async {
  final byResolution = <String, Video>{};
  for (final video in videos) {
    final key = resolutionKey(video.quality);
    if (key.isEmpty) continue;
    byResolution.putIfAbsent(key, () => video);
  }
  final entries = byResolution.entries.toList(growable: false);
  if (entries.isEmpty) return const {};

  final sizes = <String, String>{};
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= entries.length) return;
      final entry = entries[index];
      final size = await probeStreamSize(entry.value);
      if (size != null) sizes[entry.key] = size;
    }
  }

  final workers = math.min(concurrency, entries.length);
  await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  return sizes;
}

/// Resolutions already downloaded for the catalogue item [link] of [source].
///
/// Keys are [resolutionKey] values, so the caller can drop a resolution from
/// the picker instead of offering a download that the engine would refuse as a
/// duplicate — while still offering every *other* resolution of the same video.
Set<String> downloadedResolutionKeys(Source source, String? link) =>
    downloadedResolutionKeysForSource(source.id, link);

/// [downloadedResolutionKeys] for callers that only hold the source id (the
/// download sheet receives a `Manga`, not a `Source`).
Set<String> downloadedResolutionKeysForSource(int? sourceId, String? link) {
  final url = link?.trim();
  if (sourceId == null || url == null || url.isEmpty) return const {};
  try {
    final manga = isar.mangas
        .filter()
        .sourceIdEqualTo(sourceId)
        .and()
        .linkEqualTo(url)
        .findFirstSync();
    final mangaId = manga?.id;
    if (mangaId == null) return const {};
    final keys = <String>{};
    for (final chapter in isar.chapters.filter().mangaIdEqualTo(mangaId).findAllSync()) {
      final chapterId = chapter.id;
      if (chapterId == null) continue;
      final download = isar.downloads.getSync(chapterId);
      if (download?.isDownload != true) continue;
      final key = resolutionKey(_downloadQualityLabel(download!));
      if (key.isNotEmpty) keys.add(key);
    }
    return keys;
  } catch (_) {
    // A damaged row must not hide the whole format list.
    return const {};
  }
}

/// Quality label of a completed download. Prefers the stored quality and falls
/// back to the file path, which carries the `[720p]` suffix the engine appends,
/// so legacy rows without a quality column are still recognised as downloaded.
String _downloadQualityLabel(Download download) {
  final quality = download.quality?.trim();
  if (quality != null && quality.isNotEmpty) return quality;
  return download.filePath?.trim() ?? '';
}
