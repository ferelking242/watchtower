import 'package:watchtower/models/video.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;

/// Some watch-source extensions (lightweight FR streaming wrappers, mostly)
/// have no real CDN backend of their own — they just relay the official
/// YouTube embed the site uses. Extensions can only hand back concrete URLs,
/// so they return the YouTube watch/embed page verbatim. mpv can't play that
/// page directly (it needs an actual media stream), so this resolver expands
/// any such entry into real, playable Video objects.
///
/// Note: this talks to youtube_explode_dart directly rather than going
/// through the Music module's youtubeEngineProvider — that provider's
/// getStreamManifest() rebuilds a StreamManifest containing only
/// audio-only streams (it's written for music playback), so it never
/// exposes muxed/video-only streams that the watch player needs.
class YoutubeWatchResolver {
  static String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();

    if (host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      final segments = uri.pathSegments;
      final embedIndex = segments.indexOf('embed');
      if (embedIndex != -1 && embedIndex + 1 < segments.length) {
        return segments[embedIndex + 1];
      }
    }
    return null;
  }

  /// Whether [url] is a YouTube watch/embed/short link.
  static bool isYoutubeUrl(String url) => _extractVideoId(url) != null;

  /// Resolves every YouTube entry in [videos] into real, playable streams.
  /// Non-YouTube entries pass through untouched. Entries that fail to
  /// resolve are dropped — the caller's existing "0 videos" handling then
  /// surfaces a clear log instead of a silent mpv hang.
  static Future<List<Video>> resolve(
    List<Video> videos, {
    required String epLabel,
  }) async {
    final result = <Video>[];
    final yt = YoutubeExplode();

    try {
      for (final video in videos) {
        final source =
            video.originalUrl.isNotEmpty ? video.originalUrl : video.url;
        final videoId = _extractVideoId(source);
        if (videoId == null) {
          result.add(video);
          continue;
        }

        try {
          AppLogger.log(
            '[$epLabel] YoutubeWatchResolver  videoId=$videoId  resolving…',
            logLevel: LogLevel.info,
            tag: LogTag.watch,
          );
          // Same client list already proven to work against YouTube's
          // anti-bot protections for the Music module.
          final manifest = await yt.videos.streamsClient.getManifest(
            videoId,
            requireWatchPage: false,
            ytClients: [
              YoutubeApiClient.ios,
              YoutubeApiClient.androidVr,
              YoutubeApiClient.android,
            ],
          );

          if (manifest.muxed.isNotEmpty) {
            final best = manifest.muxed.bestQuality;
            result.add(Video(
              best.url.toString(),
              '${best.videoResolution.height}p',
              source,
            ));
            AppLogger.log(
              '[$epLabel] YoutubeWatchResolver  videoId=$videoId  muxed ${best.videoResolution.height}p',
              logLevel: LogLevel.info,
              tag: LogTag.watch,
            );
            continue;
          }

          // No muxed stream (common above 360p) — take the best video-only
          // stream and attach the best audio-only stream as a separate track.
          if (manifest.videoOnly.isNotEmpty && manifest.audioOnly.isNotEmpty) {
            final bestVideo = manifest.videoOnly.bestQuality;
            final bestAudio = manifest.audioOnly.withHighestBitrate();
            result.add(Video(
              bestVideo.url.toString(),
              '${bestVideo.videoResolution.height}p',
              source,
              audios: [Track(file: bestAudio.url.toString(), label: 'Audio')],
            ));
            AppLogger.log(
              '[$epLabel] YoutubeWatchResolver  videoId=$videoId  video-only ${bestVideo.videoResolution.height}p + audio-only fallback',
              logLevel: LogLevel.info,
              tag: LogTag.watch,
            );
            continue;
          }

          AppLogger.log(
            '[$epLabel] YoutubeWatchResolver  videoId=$videoId  manifest has no usable streams',
            logLevel: LogLevel.warning,
            tag: LogTag.watch,
          );
        } catch (e) {
          AppLogger.log(
            '[$epLabel] YoutubeWatchResolver FAILED  videoId=$videoId: $e',
            logLevel: LogLevel.error,
            tag: LogTag.watch,
          );
        }
      }
    } finally {
      yt.close();
    }

    return result;
  }
}
