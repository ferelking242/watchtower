import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Some extensions do not store a real URL in a chapter's `url`: MKissa stores
/// the JSON token `{"mangaId":…,"chapterString":…,"chapType":"sub"}` and parses
/// it back inside `getPageList`. `getUrlWithoutDomain` used to call `Uri.parse`
/// unconditionally, which throws on such a token (the first `:` is read as a
/// bogus scheme) and crashed the whole download with a FormatException.
void main() {
  group('getUrlWithoutDomain', () {
    test('strips the domain of a real URL', () {
      expect(
        'https://mkissa.to/manga/some-title'.getUrlWithoutDomain,
        '/manga/some-title',
      );
    });

    test('keeps the query and fragment of a real URL', () {
      expect(
        'https://host.tld/path?a=1&b=2#frag'.getUrlWithoutDomain,
        '/path?a=1&b=2#frag',
      );
    });

    test('returns an opaque chapter token unchanged instead of throwing', () {
      const token =
          '{"mangaId":"3jBuzqhAhPqoc3no2",'
          '"chapterString":"74","chapType":"sub"}';
      expect(token.getUrlWithoutDomain, token);
    });

    test('returns a bare identifier unchanged', () {
      expect('plain-chapter-id'.getUrlWithoutDomain, 'plain-chapter-id');
    });
  });
}
