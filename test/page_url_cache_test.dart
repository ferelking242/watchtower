import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/page_url_cache.dart';

void main() {
  group('cached page URL headers', () {
    test('decodes URLs when the cached headers list is shorter', () {
      final urls = List.generate(
        63,
        (index) => 'https://example.test/$index',
      );
      final headers = List.generate(
        59,
        (index) => '{"X-Page":"$index"}',
      );

      final pages = decodeCachedPageUrls(urls: urls, headers: headers);

      expect(pages, hasLength(63));
      expect(pages[58].headers, {'X-Page': '58'});
      expect(pages[59].headers, isNull);
      expect(pages[62].url, 'https://example.test/62');
      expect(pages[62].headers, isNull);
    });

    test('ignores malformed or non-map cached header values', () {
      final pages = decodeCachedPageUrls(
        urls: const ['page-0', 'page-1', 'page-2'],
        headers: const ['{"Referer":"https://example.test"}', '{bad', 'null'],
      );

      expect(pages[0].headers, {'Referer': 'https://example.test'});
      expect(pages[1].headers, isNull);
      expect(pages[2].headers, isNull);
    });

    test('encodes mixed headers with one stored entry per URL', () {
      final pages = [
        PageUrl('page-0'),
        PageUrl('page-1', headers: {'Referer': 'https://example.test'}),
        PageUrl('page-2'),
      ];

      final headers = encodeCachedPageHeaders(pages);
      final decoded = decodeCachedPageUrls(
        urls: pages.map((page) => page.url).toList(),
        headers: headers,
      );

      expect(headers, hasLength(pages.length));
      expect(headers![0], '{}');
      expect(decoded[0].headers, isEmpty);
      expect(decoded[1].headers, {'Referer': 'https://example.test'});
      expect(decoded[2].headers, isEmpty);
    });

    test('leaves the optional header list absent when no page has headers', () {
      expect(
        encodeCachedPageHeaders([PageUrl('page-0'), PageUrl('page-1')]),
        isNull,
      );
    });
  });
}
