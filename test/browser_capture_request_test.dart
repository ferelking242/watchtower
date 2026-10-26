import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/browser_capture.dart';

/// The browser performs the request itself, so the headers an extension passes
/// are translated into a page-level `fetch()`. A forbidden header makes the
/// engine reject the whole request with a TypeError, which would look like a
/// network failure — and the bridge has to carry the request to the root
/// isolate unchanged.
void main() {
  group('browser fetch headers', () {
    test('drops the headers only the engine may set', () {
      final sanitized = browserFetchHeaders({
        'User-Agent': 'Mozilla/5.0',
        'cookie': 'cf_clearance=abc',
        'Referer': 'https://missav.ws/',
        'Origin': 'https://missav.ws',
        'Host': 'missav.ws',
        'Content-Length': '42',
        'Accept': 'text/html',
      });

      expect(sanitized, {'Accept': 'text/html'});
    });

    test('keeps the headers an extension legitimately sends', () {
      final sanitized = browserFetchHeaders({
        'Accept': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
        'X-Requested-With': 'XMLHttpRequest',
      });

      expect(sanitized, {
        'Accept': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
        'X-Requested-With': 'XMLHttpRequest',
      });
    });

    test('ignores empty names and empty values', () {
      expect(browserFetchHeaders({'': 'x', 'X-Empty': ''}), isEmpty);
      expect(browserFetchHeaders(null), isEmpty);
    });
  });

  group('browser request bridge payload', () {
    test('a request survives the isolate hop', () {
      const request = BrowserCaptureRequest(
        url: 'https://missav.ws/en/new?sort=views',
        sourceId: 1900000218,
        headers: {'Accept': 'text/html'},
        timeout: Duration(seconds: 9),
        solveTimeout: Duration(seconds: 6),
      );

      final decoded = BrowserCaptureRequest.fromMap(
        Map<String, dynamic>.from(request.toMap()),
      );

      expect(decoded.url, request.url);
      expect(decoded.sourceId, request.sourceId);
      expect(decoded.headers, request.headers);
      expect(decoded.timeout, request.timeout);
      expect(decoded.solveTimeout, request.solveTimeout);
    });

    test('a result survives the isolate hop', () {
      const result = BrowserCaptureResult(
        body: '<html>ok</html>',
        finalUrl: 'https://missav.ws/en',
        statusCode: 200,
      );

      final decoded = BrowserCaptureResult.fromMap(
        Map<String, dynamic>.from(result.toMap()),
      );

      expect(decoded.body, result.body);
      expect(decoded.finalUrl, result.finalUrl);
      expect(decoded.statusCode, result.statusCode);
    });
  });
}
