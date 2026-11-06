import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/downloaded_video_preference.dart';

void main() {
  group('mergeDownloadedVideosFirst', () {
    test('tries a downloaded file before online qualities', () {
      final merged = mergeDownloadedVideosFirst(
        online: [
          Video('https://cdn.example/master.m3u8', 'Auto (HLS)', ''),
          Video('https://cdn.example/480.m3u8', '480p', ''),
        ],
        downloaded: [Video('/watchtower/downloads/episode.mp4', '720p', '')],
      );

      expect(merged.map((video) => video.url), [
        '/watchtower/downloads/episode.mp4',
        'https://cdn.example/master.m3u8',
        'https://cdn.example/480.m3u8',
      ]);
    });

    test('uses a downloaded copy for a matching online quality', () {
      final merged = mergeDownloadedVideosFirst(
        online: [
          Video('https://cdn.example/720.mp4', '720p', ''),
          Video('https://cdn.example/480.mp4', '480p', ''),
        ],
        downloaded: [Video('/watchtower/downloads/episode.mp4', '720 P', '')],
      );

      expect(merged.map((video) => video.url), [
        '/watchtower/downloads/episode.mp4',
        'https://cdn.example/480.mp4',
      ]);
    });
  });
}
