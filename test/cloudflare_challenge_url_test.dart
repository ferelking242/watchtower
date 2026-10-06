import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_url.dart';

void main() {
  group('resolveCloudflareChallengeUrl', () {
    test('keeps the exact failing URL — never the site root', () {
      expect(
        resolveCloudflareChallengeUrl('https://imhentai.xxx/api/search?page=1'),
        'https://imhentai.xxx/api/search?page=1',
      );
    });

    test('keeps path and query so the WebView shows the same request', () {
      expect(
        resolveCloudflareChallengeUrl(
          'https://api.example.test/v2/search?q=one',
        ),
        'https://api.example.test/v2/search?q=one',
      );
    });

    test('rejects non-web URLs', () {
      expect(resolveCloudflareChallengeUrl('javascript:alert(1)'), isNull);
      expect(resolveCloudflareChallengeUrl(''), isNull);
    });
  });

  group('Cloudflare page detection', () {
    test('recognizes a challenge widget even without English body text', () {
      expect(
        assessPageContent(
          title: 'Just a moment...',
          text: 'Sécurité',
          cloudflareChallengeDom: true,
        ).challenge,
        isTrue,
      );
    });

    test('does not treat a WAF block page as a solved challenge', () {
      final blocked = assessPageContent(
        title: 'Sorry, you have been blocked',
        text: 'Cloudflare',
      );
      expect(blocked.blocked, isTrue);
      expect(blocked.challenge, isFalse);
    });

    test('a normal page is never a challenge', () {
      final page = assessPageContent(title: 'My site', text: 'Welcome');
      expect(page.pageType, AntiBotPageType.normal);
      expect(page.challenge, isFalse);
    });
  });
}
