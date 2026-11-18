import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart'
    show isCloudflareError;
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// `isMediaVideo` decides whether an extension's `getVideoList` entry is a
/// direct progressive file (download it as-is) or an HLS manifest (route it
/// through the segment downloader). Matching the extension against the whole
/// URL broke on every signed CDN link: KVS-style sources serve
/// `…/720p.mp4/?v-acctoken=…` and `…/2160p.mp4?token=…`, whose trailing slash
/// or query string made `endsWith('mp4')` fail. The anime download branch then
/// found zero "playable URLs" and aborted a perfectly downloadable file.
void main() {
  group('isMediaVideo', () {
    test('accepts a plain media file', () {
      expect('https://host.tld/video.mp4'.isMediaVideo(), isTrue);
      expect('https://host.tld/path/clip.mkv'.isMediaVideo(), isTrue);
      expect('https://host.tld/a/b/movie.MOV'.isMediaVideo(), isTrue);
    });

    test('accepts a media file with a query string', () {
      expect(
        'https://host.tld/video/2160p.mp4?token=abc123'.isMediaVideo(),
        isTrue,
      );
    });

    test('accepts a KVS-style URL with a trailing slash and a query', () {
      expect(
        'https://www.1porn.tv/get_file/1/ab/cd/ef/720p.mp4/?v-acctoken=xyz'
            .isMediaVideo(),
        isTrue,
      );
    });

    test('accepts a media file with a fragment', () {
      expect('https://host.tld/clip.webm#t=10'.isMediaVideo(), isTrue);
    });

    test('rejects an HLS manifest', () {
      expect('https://host.tld/master.m3u8?token=abc'.isMediaVideo(), isFalse);
    });

    test('rejects a page and an extension-less path', () {
      expect('https://host.tld/watch/episode-1'.isMediaVideo(), isFalse);
      expect('https://host.tld/index.html'.isMediaVideo(), isFalse);
    });

    test('rejects a path that merely ends with a media name', () {
      expect('https://host.tld/mov'.isMediaVideo(), isFalse);
    });
  });

  group('download failure → bypass panel gate', () {
    // The download branch records a ChallengeInbox entry — which force-opens
    // the inline Cloudflare panel — only when the failure text carries real
    // anti-bot evidence. These are the exact strings the anime branch produces
    // for ordinary failures; none of them may open the panel.
    test('ordinary fetch failures are not Cloudflare', () {
      for (final message in const [
        'getVideoList returned no playable URLs',
        'getChapterPages returned empty list',
        'Fetch timed out after 90s — source returned no data',
        'HTTP 404 Not Found',
        'Invalid OAuth code_challenge',
        'Connection closed before full header was received',
      ]) {
        expect(isCloudflareError(message), isFalse, reason: message);
      }
    });

    test('a real Cloudflare refusal still opens the panel', () {
      expect(
        isCloudflareError('MissAV: Cloudflare challenge (HTTP 403) — https://x'),
        isTrue,
      );
      expect(isCloudflareError('Attention Required! | Cloudflare'), isTrue);
      expect(isCloudflareError('Failed to bypass Cloudflare'), isTrue);
    });
  });
}
