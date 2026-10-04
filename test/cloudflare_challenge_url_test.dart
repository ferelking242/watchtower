import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_url.dart';
import 'package:watchtower/services/anti_bot/cloudflare_page_detector.dart';

void main() {
  group('resolveCloudflareChallengeUrl', () {
    test('prefers the installed source landing page', () {
      expect(
        resolveCloudflareChallengeUrl(
          'https://imhentai.xxx/api/search?page=1',
          sourceBaseUrl: 'https://imhentai.xxx/',
        ),
        'https://imhentai.xxx/',
      );
    });

    test('falls back to the failed request origin', () {
      expect(
        resolveCloudflareChallengeUrl(
          'https://api.example.test/v2/search?q=one',
        ),
        'https://api.example.test/',
      );
    });

    test('drops query and fragment from the source landing URL', () {
      expect(
        resolveCloudflareChallengeUrl(
          'https://api.example.test/v2/search',
          sourceBaseUrl: 'https://example.test/catalog?sort=latest#results',
        ),
        'https://example.test/catalog',
      );
    });

    test('rejects non-web URLs', () {
      expect(resolveCloudflareChallengeUrl('javascript:alert(1)'), isNull);
    });
  });

  group('Cloudflare page detection', () {
    test('recognizes a challenge widget even without English body text', () {
      expect(
        isCloudflareChallengeSnapshot('WT_CF_CHALLENGE=1\\nSécurité'),
        isTrue,
      );
    });

    test('does not treat a WAF block page as a solved challenge', () {
      const blockedPage = 'Cloudflare - Sorry, you have been blocked';
      expect(isCloudflareBlockedSnapshot(blockedPage), isTrue);
      expect(isCloudflareChallengeSnapshot(blockedPage), isFalse);
    });
  });
}