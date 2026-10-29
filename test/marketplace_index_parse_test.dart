import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/catalog_taxonomy.dart';
import 'package:watchtower/modules/browse/marketplace_screen.dart';

/// Builds one raw index entry with the fields the parser requires.
Map<String, dynamic> _raw({
  required int id,
  required String name,
  int itemType = 1,
  int sourceCodeLanguage = 1,
  String lang = 'en',
  List<String>? tags,
}) => {
  'id': id,
  'name': name,
  'itemType': itemType,
  'sourceCodeLanguage': sourceCodeLanguage,
  'lang': lang,
  'version': '1.0.0',
  'iconUrl': 'https://example.test/$id.png',
  if (tags != null) 'tags': tags,
};

List<Map<String, dynamic>> _parse(List<Map<String, dynamic>> entries) =>
    parseMarketplaceIndex({
      'body': jsonEncode(entries),
      'url': 'https://example.test/index/watch.json',
    });

void main() {
  group('parseMarketplaceIndex de-duplication', () {
    test('keeps both entries when two sources share a display name', () {
      // `SpankBang` really ships `spankbang.js` and `spankbang_new.js`; the
      // older name-keyed rule dropped one of them from the whole Marketplace.
      final parsed = _parse([
        _raw(id: 1900000181, name: 'SpankBang'),
        _raw(id: 1900001484, name: 'SpankBang'),
      ]);

      expect(parsed, hasLength(2));
      expect(
        parsed.map((e) => e['id']),
        containsAll(<int>[1900000181, 1900001484]),
      );
    });

    test('collapses a repeated id, which would alias two catalogue rows', () {
      final parsed = _parse([
        _raw(id: 42, name: 'First'),
        _raw(id: 42, name: 'Second'),
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single['name'], 'First');
    });

    test('keeps same-named entries that differ only in language', () {
      final parsed = _parse([
        _raw(id: 1, name: 'AnimeSongLyrics', lang: 'en'),
        _raw(id: 2, name: 'AnimeSongLyrics', lang: 'fr'),
      ]);

      expect(parsed, hasLength(2));
    });
  });

  group('parseMarketplaceIndex malformed metadata', () {
    test('skips an entry with no numeric id', () {
      final parsed = _parse([
        {'name': 'No id', 'itemType': 1, 'sourceCodeLanguage': 1},
        _raw(id: 7, name: 'Valid'),
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single['name'], 'Valid');
    });

    test('skips an entry with no string name', () {
      final parsed = _parse([
        {'id': 8, 'name': 1234, 'itemType': 1, 'sourceCodeLanguage': 1},
        _raw(id: 9, name: 'Valid'),
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single['name'], 'Valid');
    });

    test('skips an entry whose sourceCodeLanguage is out of range', () {
      final parsed = _parse([
        _raw(id: 10, name: 'Bad compat', sourceCodeLanguage: 9),
        _raw(id: 11, name: 'Valid'),
      ]);

      expect(parsed, hasLength(1));
      expect(parsed.single['name'], 'Valid');
    });

    test('keeps an entry that declares no tags at all', () {
      final parsed = _parse([_raw(id: 12, name: 'Untagged')]);

      expect(parsed, hasLength(1));
      expect(parsed.single['tags'], isEmpty);
    });

    test('ignores non-string members of a tags list', () {
      final parsed = _parse([
        {
          ..._raw(id: 13, name: 'Mixed tags'),
          'tags': ['watch', 42, null, 'multilingual'],
        },
      ]);

      expect(parsed.single['tags'], <String>['watch', 'multilingual']);
    });

    test('keeps the raw itemType beyond the app enum (subtitles use 7)', () {
      final parsed = _parse([_raw(id: 14, name: 'Kitsunekko', itemType: 7)]);

      expect(parsed.single['itemType'], 7);
      // contentType still has to stay inside ItemType.values for the UI.
      expect(parsed.single['contentType'], lessThan(5));
    });

    test('returns nothing for a body that is not a JSON list', () {
      expect(parseMarketplaceIndex({'body': '{"a":1}', 'url': 'u'}), isEmpty);
      expect(parseMarketplaceIndex({'body': 'not json', 'url': 'u'}), isEmpty);
      expect(parseMarketplaceIndex({'body': '', 'url': 'u'}), isEmpty);
    });

    test('skips non-object members of the list', () {
      final parsed = parseMarketplaceIndex({
        'body': jsonEncode(['nope', 5, _raw(id: 15, name: 'Valid')]),
        'url': 'u',
      });

      expect(parsed, hasLength(1));
      expect(parsed.single['name'], 'Valid');
    });

    test('one malformed entry never blanks the rest of the catalogue', () {
      final parsed = _parse([
        _raw(id: 16, name: 'A'),
        {'id': 'not-a-number', 'name': 'B'},
        _raw(id: 17, name: 'C'),
        {'name': 'D'},
        _raw(id: 18, name: 'E'),
      ]);

      expect(parsed.map((e) => e['name']), <String>['A', 'C', 'E']);
    });
  });
  group('subtitles catalogue (itemType 7)', () {
    // The repository publishes `index/subtitles.json` alongside the six other
    // catalogues, but the Marketplace only ever fetched five of them, so the
    // subtitle sources were silently absent from the whole app.
    test('every published catalogue index is actually loaded', () {
      expect(kMarketplaceIndexPaths, contains('index/subtitles.json'));
      expect(
        kMarketplaceIndexPaths.toSet(),
        hasLength(kMarketplaceIndexPaths.length),
        reason: 'no catalogue may be listed twice',
      );
    });

    test('itemType 7 keeps its raw value instead of clamping to manga', () {
      final parsed = _parse([
        _raw(id: 7000000001, name: 'Kitsunekko', itemType: 7, lang: 'multi'),
      ]);
      expect(parsed.single['itemType'], 7);
    });

    test('a subtitle entry is shelved as watch, not manga', () {
      final parsed = _parse([
        _raw(
          id: 7000000001,
          name: 'Kitsunekko',
          itemType: 7,
          lang: 'multi',
          tags: const ['watch', 'multilingual'],
        ),
      ]);
      final entry = parsed.single;
      expect(
        CatalogTaxonomy.itemTypeToContent[entry['itemType'] as int],
        'watch',
      );
    });
  });
}
