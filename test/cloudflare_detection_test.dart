import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';

/// Regression tests for the “Cloudflare challenge while the WebView shows the
/// homepage” bug: 403/503 alone must never be classified as Cloudflare, and a
/// normal page must never be reported as a resolved challenge.
void main() {
  group('Cloudflare detection — HTTP responses', () {
    test('Test 1: 403 without Cloudflare evidence is NOT Cloudflare', () {
      final a = assessHttpResponse(
        statusCode: 403,
        headers: {'server': 'nginx'},
        body: '{"error":"forbidden"}',
      );
      expect(a.challenge, isFalse);
      expect(a.blocked, isFalse);
      expect(a.cloudflareInvolved, isFalse);
      expect(a.pageType, AntiBotPageType.unknown);
    });

    test('Test 2: 403 + Server: cloudflare → block only with a block page',
        () {
      final plain = assessHttpResponse(
        statusCode: 403,
        headers: {'Server': 'cloudflare'},
        body: '{"error":"rate limited"}',
      );
      expect(plain.challenge, isFalse);
      // The CDN header alone is not proof of a block page.
      expect(plain.blocked, isFalse);

      final blocked = assessHttpResponse(
        statusCode: 403,
        headers: {'server': 'Cloudflare'},
        body: '<html><head><title>Attention Required! | Cloudflare</title>'
            '</head><body>You have been blocked</body></html>',
      );
      expect(blocked.blocked, isTrue);
      expect(blocked.challenge, isFalse);
      expect(blocked.cloudflareInvolved, isTrue);
    });

    test('Test 3: 503 without Cloudflare is NOT automatically Cloudflare', () {
      final a = assessHttpResponse(
        statusCode: 503,
        headers: {'content-type': 'text/html'},
        body: '<html><body>Service temporarily unavailable</body></html>',
      );
      expect(a.challenge, isFalse);
      expect(a.blocked, isFalse);
      expect(a.cloudflareInvolved, isFalse);
    });

    test('Test 4: 503 + a real Cloudflare challenge page IS a challenge', () {
      final a = assessHttpResponse(
        statusCode: 503,
        headers: {'server': 'cloudflare', 'cf-ray': 'abc123-CDG'},
        body: '<html><title>Just a moment...</title>'
            '<script src="/cdn-cgi/challenge-platform/h/b/orchestrate/chl_page/v1">'
            '</script></html>',
      );
      expect(a.challenge, isTrue);
      expect(a.cloudflareInvolved, isTrue);
    });

    test('Test 5: HTML "Just a moment..." → challenge (even with HTTP 200)',
        () {
      final a = assessHttpResponse(
        statusCode: 200,
        headers: {'content-type': 'text/html'},
        body: '<html><head><title>Just a moment...</title></head><body>'
            'Checking your browser before accessing the site.</body></html>',
      );
      expect(a.pageType, AntiBotPageType.challenge);
    });

    test('Test 6: normal homepage → NORMAL, never a challenge', () {
      final a = assessHttpResponse(
        statusCode: 200,
        headers: {'server': 'cloudflare', 'cf-ray': 'x'},
        body: '<html><title>My site</title><body>Hello world</body></html>',
      );
      expect(a.pageType, AntiBotPageType.normal);
      expect(a.challenge, isFalse);
      expect(a.blocked, isFalse);
      // CDN involvement is still reported for diagnostics.
      expect(a.cloudflareInvolved, isTrue);
    });

    test('challenge markers in JavaScript/JSON payloads are not page challenges',
        () {
      const sourceLikeBody = '''
        const markers = [
          "just a moment",
          "checking your browser",
          "challenge-platform",
          "cf-chl",
          "attention required"
        ];
      ''';

      for (final contentType in [
        'application/javascript; charset=utf-8',
        'application/json; charset=utf-8',
      ]) {
        final a = assessHttpResponse(
          statusCode: 200,
          headers: {
            'server': 'cloudflare',
            'cf-ray': 'abc123-CDG',
            'content-type': contentType,
          },
          body: sourceLikeBody,
        );

        expect(a.pageType, AntiBotPageType.normal, reason: contentType);
        expect(a.challenge, isFalse, reason: contentType);
        expect(a.blocked, isFalse, reason: contentType);
        expect(a.cloudflareInvolved, isTrue, reason: contentType);
      }
    });

    test('cf-mitigated challenge header remains actionable for JavaScript', () {
      final a = assessHttpResponse(
        statusCode: 200,
        headers: {
          'content-type': 'application/javascript',
          'cf-mitigated': 'challenge',
        },
        body: 'const app = true;',
      );
      expect(a.challenge, isTrue);
      expect(a.evidence, contains('header:cf-mitigated=challenge'));
    });

    test('Test 7: a JSON API 403 is never rewritten as Cloudflare', () {
      final a = assessHttpResponse(
        statusCode: 403,
        headers: {'server': 'cloudflare'},
        body: '{"errors":[{"message":"Invalid API key"}]}',
      );
      expect(a.challenge, isFalse);
      expect(a.blocked, isFalse);
      // Message layer agrees with the response layer.
      expect(
        assessErrorMessage('HTTP 403 — access denied').cloudflareInvolved,
        isFalse,
      );
      expect(
        assessErrorMessage('Failed to bypass Cloudflare').cloudflareInvolved,
        isTrue,
      );
    });
  });

  group('Cloudflare detection — bypass URL and WebView pages', () {
    test('Test 8: the bypass URL is the exact failing URL, never the site root',
        () {
      expect(
        resolveBypassUrl('https://imhentai.xxx/api/search?page=1'),
        'https://imhentai.xxx/api/search?page=1',
      );
      expect(resolveBypassUrl('not a url'), isNull);
      expect(resolveBypassUrl('ftp://site.com/x'), isNull);
    });

    test('Test 9: a healthy page without clearance is never “resolved”', () {
      final page = parsePageProbe(
        '{"ok":true,"title":"Home","text":"Welcome to the site"}',
      );
      expect(page.pageType, AntiBotPageType.normal);
      // No cf_clearance cookie → nothing was bypassed, so no “resolved” claim.
      expect(
        canMarkChallengeResolved(
          challengeSeen: false,
          cfClearancePresent: false,
          currentPage: page.pageType,
        ),
        isFalse,
      );
    });

    test('Test 9b: an auto-solved managed challenge still resolves', () {
      // Cloudflare can serve a managed challenge that clears between two
      // probes: the page is already normal while cf_clearance exists. That
      // must resolve, otherwise the source stays stuck on the empty state.
      expect(
        canMarkChallengeResolved(
          challengeSeen: false,
          cfClearancePresent: true,
          currentPage: AntiBotPageType.normal,
        ),
        isTrue,
      );
    });

    test('Test 9c: a French Cloudflare interstitial is a challenge', () {
      // Cloudflare localises the page; the app must not report “no challenge”
      // just because the markers are not English.
      final page = parsePageProbe(
        '{"ok":true,"title":"Un instant…","text":'
        '"Vérification de sécurité en cours. Ce site utilise un service de '
        'sécurité pour se protéger."}',
      );
      expect(page.pageType, AntiBotPageType.challenge);
      expect(page.cloudflareInvolved, isTrue);
    });

    test('Test 10: a real challenge page is detected in the WebView probe', () {
      final page = parsePageProbe(
        '{"ok":true,"title":"Just a moment...","text":"Verify you are human"}',
      );
      expect(page.pageType, AntiBotPageType.challenge);
      expect(
        canMarkChallengeResolved(
          challengeSeen: true,
          cfClearancePresent: true,
          // Still on the challenge page → not resolved.
          currentPage: AntiBotPageType.challenge,
        ),
        isFalse,
      );
    });

    test('Test 11: cf_clearance + challenge cleared → retry is allowed', () {
      expect(
        canMarkChallengeResolved(
          challengeSeen: true,
          cfClearancePresent: true,
          currentPage: AntiBotPageType.normal,
        ),
        isTrue,
      );
      // Challenge seen and cleared, but cookie missing → no “resolved” claim.
      expect(
        canMarkChallengeResolved(
          challengeSeen: true,
          cfClearancePresent: false,
          currentPage: AntiBotPageType.normal,
        ),
        isFalse,
      );
    });

    test('Test 12: extension 403 vs WebView 200 are distinct states', () {
      final api = assessHttpResponse(
        statusCode: 403,
        headers: {'server': 'cloudflare'},
        body: '{"error":"forbidden"}',
      );
      final webViewPage = parsePageProbe(
        '{"ok":true,"title":"Home","text":"Welcome"}',
      );
      // The API was refused…
      expect(api.challenge, isFalse);
      // …but the page loads normally: no challenge to report.
      expect(webViewPage.pageType, AntiBotPageType.normal);
      expect(
        canMarkChallengeResolved(
          challengeSeen: false,
          cfClearancePresent: false,
          currentPage: webViewPage.pageType,
        ),
        isFalse,
      );
    });

    test('a Cloudflare block page in the WebView is not a challenge', () {
      final page = parsePageProbe(
        '{"ok":true,"title":"Attention Required! | Cloudflare",'
        '"text":"You have been blocked"}',
      );
      expect(page.pageType, AntiBotPageType.blocked);
      expect(page.challenge, isFalse);
    });
  });

  group('Cloudflare detection — message heuristics', () {
    test('plain 403/503/timeout messages are not Cloudflare', () {
      for (final msg in [
        'HTTP 403 Forbidden',
        'statusCode: 403',
        '503 Service Unavailable',
        'Connection timeout',
        'Invalid OAuth code_challenge',
      ]) {
        final a = assessErrorMessage(msg);
        expect(a.cloudflareInvolved, isFalse, reason: msg);
        expect(a.challenge, isFalse, reason: msg);
      }
    });

    test('real Cloudflare markers are detected', () {
      expect(assessErrorMessage('Just a moment...').challenge, isTrue);
      expect(assessErrorMessage('Failed to bypass Cloudflare').blocked, isTrue);
      expect(
        assessErrorMessage('Attention Required! | Cloudflare').blocked,
        isTrue,
      );
    });

    test('diagnostic logs never contain query values', () {
      expect(
        redactUrl('https://site.com/api?token=secret&page=1'),
        'https://site.com/api?redacted',
      );
      expect(redactUrl('https://site.com/path'), 'https://site.com/path');
      final line = antiBotLogLine(
        assessment: assessHttpResponse(
          statusCode: 403,
          headers: {'server': 'cloudflare', 'cf-ray': 'abc'},
          body: '',
        ),
        url: 'https://site.com/api?token=secret',
        statusCode: 403,
        headers: {'server': 'cloudflare'},
      );
      expect(line, contains('pageType=unknown'));
      expect(line, isNot(contains('secret')));
    });
  });
}
