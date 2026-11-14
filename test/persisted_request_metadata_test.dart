import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/http/persisted_request_metadata.dart';

void main() {
  group('sanitizePersistedUrl', () {
    test('leaves a plain URL untouched (no trailing ?#)', () {
      expect(
        sanitizePersistedUrl('https://example.test/62'),
        'https://example.test/62',
      );
    });

    test('drops sensitive query parameters but keeps the rest', () {
      expect(
        sanitizePersistedUrl('https://example.test/62?token=abc&page=2'),
        'https://example.test/62?page=2',
      );
      expect(
        sanitizePersistedUrl('https://example.test/62?auth=1&page=2&sig=z'),
        'https://example.test/62?page=2',
      );
    });

    test('removes the fragment', () {
      expect(
        sanitizePersistedUrl('https://example.test/62#frag'),
        'https://example.test/62',
      );
    });

    test('removes embedded credentials', () {
      expect(
        sanitizePersistedUrl('https://user:pass@host.test/1'),
        'https://host.test/1',
      );
    });

    test('preserves an explicit port', () {
      expect(
        sanitizePersistedUrl('https://host.test:8443/p?token=x'),
        'https://host.test:8443/p',
      );
    });

    test('never re-emits a sensitive-only query', () {
      expect(
        sanitizePersistedUrl('https://example.test/62?token=x'),
        'https://example.test/62',
      );
    });

    test('handles relative values and malformed input', () {
      expect(sanitizePersistedUrl('u0'), 'u0');
      expect(sanitizePersistedUrl('https://src/ch/1'), 'https://src/ch/1');
      expect(sanitizePersistedUrl('http://[bad'), '');
    });
  });

  group('cacheKeyUrl', () {
    test('drops rotating CDN credentials and expiry stamps', () {
      expect(
        cacheKeyUrl('https://cdn.test/c.jpg?token=abc&expires=1700000000&w=400'),
        cacheKeyUrl('https://cdn.test/c.jpg?token=xyz&expires=1700009999&w=400'),
      );
    });

    test('keeps query parameters that identify a distinct resource', () {
      expect(
        cacheKeyUrl('https://cdn.test/c.jpg?w=200'),
        isNot(cacheKeyUrl('https://cdn.test/c.jpg?w=800')),
      );
    });

    test('returns the raw URL when nothing is stripped', () {
      expect(
        cacheKeyUrl('https://cdn.test/c.jpg?w=200'),
        'https://cdn.test/c.jpg?w=200',
      );
      expect(cacheKeyUrl('https://cdn.test/c.jpg'), 'https://cdn.test/c.jpg');
    });

    test('handles a URL whose query is only credentials', () {
      expect(
        cacheKeyUrl('https://cdn.test/c.jpg?token=abc'),
        'https://cdn.test/c.jpg',
      );
    });
  });

  group('sanitizePersistedHeaders', () {
    test('removes authentication headers', () {
      final headers = sanitizePersistedHeaders({
        'Authorization': 'Bearer x',
        'Cookie': 'a=b',
        'Accept': 'text/html',
        'X-Api-Key': 'k',
      });
      expect(headers, {'Accept': 'text/html'});
    });
  });
}
