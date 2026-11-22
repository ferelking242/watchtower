import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';

void main() {
  group('isRawMediaUrl', () {
    test('recognises playlists and segments a WebView cannot serve', () {
      expect(isRawMediaUrl('https://surrit.com/u/playlist.m3u8'), isTrue);
      expect(isRawMediaUrl('https://x.surrit.com/u/720p/video.m3u8'), isTrue);
      expect(isRawMediaUrl('https://cdn.example/a/index.mpd'), isTrue);
      expect(isRawMediaUrl('https://cdn.example/a/seg-1.ts'), isTrue);
      expect(isRawMediaUrl('https://cdn.example/a/seg-1.m4s'), isTrue);
      expect(isRawMediaUrl('https://cdn.example/a/movie.mp4'), isTrue);
    });

    test('leaves real pages alone, so a challenge can still be raised', () {
      expect(isRawMediaUrl('https://missav.ws/en/sone-614'), isFalse);
      expect(isRawMediaUrl('https://missav.ws/en/new?page=2'), isFalse);
      expect(isRawMediaUrl('not a url'), isFalse);
    });
  });
}
