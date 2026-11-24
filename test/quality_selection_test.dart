import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/watch/detail/download/quality_selection.dart';

Video _video(String quality, String url) => Video(url, quality, url);

/// The list XVideos answers: the adaptive master, its renditions, and one
/// progressive file.
List<Video> _xvideosList() => [
  _video('Auto (HLS)', 'https://hls.example/master.m3u8'),
  _video('360p', 'https://hls.example/360/index.m3u8'),
  _video('720p', 'https://hls.example/720/index.m3u8'),
  _video('MP4 SD', 'https://mp4.example/sd.mp4'),
];

void main() {
  group('qualityDigits', () {
    test('keeps the resolution digits', () {
      expect(qualityDigits('1080p'), '1080');
      expect(qualityDigits('FHD 1080p60'), '1080');
      expect(qualityDigits('720 P VOSTFR'), '720');
    });

    test('falls back to the trimmed lowercase label', () {
      expect(qualityDigits('MP4 SD'), 'mp4 sd');
    });
  });

  group('selectPreferredVideo', () {
    test('finds a rendition the pipeline pool would have dropped', () {
      // Regression: the pick was only matched against the progressive files,
      // so a chosen 360p (an HLS rendition) was reported as unavailable even
      // though the episode publishes it.
      final videos = _xvideosList();
      final progressivePool = [videos.last];

      final chosen = selectPreferredVideo(
        videos: videos,
        preferredQuality: '360p',
        fallback: QualityFallback.exact,
        preferredPool: progressivePool,
      );

      expect(chosen, isNotNull);
      expect(chosen!.quality, '360p');
      expect(chosen.url, contains('/360/'));
    });

    test('keeps the pipeline pool when the resolution exists in both', () {
      final videos = [
        _video('720p', 'https://hls.example/720/index.m3u8'),
        _video('720p', 'https://mp4.example/720.mp4'),
      ];

      final chosen = selectPreferredVideo(
        videos: videos,
        preferredQuality: '720p',
        fallback: QualityFallback.exact,
        preferredPool: [videos.last],
      );

      expect(chosen, same(videos.last));
    });

    test('returns null without a pick', () {
      expect(
        selectPreferredVideo(
          videos: _xvideosList(),
          preferredQuality: null,
          fallback: QualityFallback.higher,
        ),
        isNull,
      );
    });

    test('exact refuses to substitute a missing resolution', () {
      expect(
        selectPreferredVideo(
          videos: _xvideosList(),
          preferredQuality: '480p',
          fallback: QualityFallback.exact,
        ),
        isNull,
      );
    });
  });

  group('nearestQualityVideo', () {
    test('higher takes the immediately superior resolution', () {
      final videos = [
        _video('240p', 'u240'),
        _video('360p', 'u360'),
        _video('720p', 'u720'),
        _video('1080p', 'u1080'),
      ];

      final chosen = nearestQualityVideo(videos, 480, QualityFallback.higher);

      expect(chosen?.quality, '720p');
    });

    test('lower takes the immediately inferior resolution', () {
      final videos = [
        _video('240p', 'u240'),
        _video('360p', 'u360'),
        _video('720p', 'u720'),
        _video('1080p', 'u1080'),
      ];

      final chosen = nearestQualityVideo(videos, 480, QualityFallback.lower);

      expect(chosen?.quality, '360p');
    });

    test('higher falls back to the highest published resolution', () {
      final videos = [_video('240p', 'u240'), _video('720p', 'u720')];

      final chosen = nearestQualityVideo(videos, 1080, QualityFallback.higher);

      expect(chosen?.quality, '720p');
    });

    test('lower falls back to the lowest published resolution', () {
      final videos = [_video('720p', 'u720'), _video('1080p', 'u1080')];

      final chosen = nearestQualityVideo(videos, 144, QualityFallback.lower);

      expect(chosen?.quality, '720p');
    });

    test('ignores labels without a resolution', () {
      final videos = [_video('Auto (HLS)', 'master'), _video('720p', 'u720')];

      expect(
        nearestQualityVideo(videos, 480, QualityFallback.higher)?.quality,
        '720p',
      );
    });

    test('returns null when nothing carries a resolution', () {
      final videos = [_video('Auto (HLS)', 'master')];

      expect(nearestQualityVideo(videos, 480, QualityFallback.higher), isNull);
    });
  });
}
