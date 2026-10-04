import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/services/page_url_cache.dart';

/// Régression du crash APK :
/// `RangeError (length): Invalid value: Not in inclusive range 0..58: 62`
///
/// Le crash réel venait de la DÉSÉRIALISATION Isar du record `Settings`
/// (payload du cache de pages embarqué aux préfixes de taille incohérents —
/// cf. `settings_store.dart`), pas d'un désalignement des listes Dart.
/// Les tests ci-dessous garantissent que le codec applicatif
/// (`page_url_cache.dart`) reste tolérant pour TOUS les états d'un cache
/// ancien/partiellement écrit : le lecteur ne lève jamais, garde les données
/// valides et ignore proprement les entrées invalides.
void main() {
  group('cached page URL headers', () {
    test('decodes URLs when the cached headers list is shorter', () {
      // Cas exact du rapport utilisateur : 63 URLs, 59 headers.
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

  group('decodeChapterPageurls — anciens caches corrompus (cas A à I)', () {
    ChapterPageurls entry({List<String>? urls, List<String>? headers}) =>
        ChapterPageurls()
          ..chapterId = 42
          ..urls = urls
          ..headers = headers;

    test('entrée nulle → liste vide, jamais de crash', () {
      expect(decodeChapterPageurls(null), isEmpty);
    });

    test('Cas A : 63 URLs / 59 headers → 63 pages valides', () {
      final e = entry(
        urls: List.generate(63, (i) => 'u$i'),
        headers: List.generate(59, (i) => '{"p":$i}'),
      );
      final pages = decodeChapterPageurls(e);
      expect(pages, hasLength(63));
      expect(pages[58].headers, {'p': 58.toString()});
      expect(pages[59].headers, isNull);
      expect(pages[62].url, 'u62');
    });

    test('Cas B : 59 URLs / 63 headers → 59 pages, headers excédentaires ignorés', () {
      final e = entry(
        urls: List.generate(59, (i) => 'u$i'),
        headers: List.generate(63, (i) => '{"p":$i}'),
      );
      final pages = decodeChapterPageurls(e);
      expect(pages, hasLength(59));
      expect(pages[58].headers, {'p': '58'});
    });

    test('Cas C : 63 URLs / 0 headers (liste vide) → headers absents', () {
      final e = entry(
        urls: List.generate(63, (i) => 'u$i'),
        headers: const [],
      );
      final pages = decodeChapterPageurls(e);
      expect(pages, hasLength(63));
      expect(pages[0].headers, isNull);
    });

    test('Cas D : headers absent → pages sans headers personnalisés', () {
      final e = entry(urls: const ['u0', 'u1']);
      final pages = decodeChapterPageurls(e);
      expect(pages, hasLength(2));
      expect(pages[0].headers, isNull);
    });

    test('Cas E : headers = null explicite → idem', () {
      final e = entry(urls: const ['u0'], headers: null);
      expect(decodeChapterPageurls(e).single.headers, isNull);
    });

    test('Cas F : JSON malformé → page conservée sans headers', () {
      final e = entry(
        urls: const ['u0', 'u1', 'u2'],
        headers: const ['{not json', '"just a string"', '[1, 2]'],
      );
      final pages = decodeChapterPageurls(e);
      expect(pages.map((p) => p.url), ['u0', 'u1', 'u2']);
      expect(pages.every((p) => p.headers == null), isTrue);
    });

    test('Cas G : entrée individuelle malformée (urls null)', () {
      expect(decodeChapterPageurls(entry(urls: null, headers: const ['{}'])),
          isEmpty);
      expect(decodeChapterPageurls(entry(urls: const [])), isEmpty);
    });

    test('Cas H : listes vides → liste vide', () {
      expect(
        decodeChapterPageurls(entry(urls: const [], headers: const [])),
        isEmpty,
      );
    });

    test('Cas I : cache partiellement écrit (une seule entrée)', () {
      final pages = decodeChapterPageurls(
        entry(urls: const ['u0'], headers: const ['{"Referer":"r"}']),
      );
      expect(pages.single.url, 'u0');
      expect(pages.single.headers, {'Referer': 'r'});
    });

    test('chaîne "null" issue de l\'ancien encodeur → headers ignorés', () {
      final pages = decodeChapterPageurls(
        entry(
          urls: const ['u0', 'u1'],
          headers: const ['null', '{"p":1}'],
        ),
      );
      expect(pages[0].headers, isNull);
      expect(pages[1].headers, {'p': '1'});
    });
  });

  group('buildChapterPageurls — invariant d\'alignement', () {
    test('headers alignés quand au moins une page a des headers', () {
      final built = buildChapterPageurls(
        chapterId: 7,
        chapterUrl: 'https://src/ch/1',
        pageUrls: [
          PageUrl('a'),
          PageUrl('b', headers: {'Referer': 'r'}),
          PageUrl('c'),
        ],
      );
      expect(built.urls, hasLength(3));
      expect(built.headers, hasLength(built.urls!.length));
      expect(built.chapterUrl, 'https://src/ch/1');
    });

    test('headers null quand aucune page n\'a de headers', () {
      final built = buildChapterPageurls(
        chapterId: 7,
        pageUrls: [PageUrl('a'), PageUrl('b')],
      );
      expect(built.headers, isNull);
    });

    test('aller-retour encode → decode sans perte', () {
      final pages = [
        PageUrl('a', headers: {'X': '1'}),
        PageUrl('b'),
        PageUrl('c', headers: const {}),
      ];
      final built = buildChapterPageurls(
        chapterId: 9,
        chapterUrl: 'u',
        pageUrls: pages,
      );
      final decoded = decodeChapterPageurls(built);
      expect(decoded, hasLength(3));
      expect(decoded[0].headers, {'X': '1'});
      expect(decoded[1].headers, isEmpty);
      expect(decoded[2].headers, isEmpty);
    });
  });

  group('mergeChapterPageurls — écriture unique et bornée', () {
    test('remplace l\'entrée du chapitre et préserve les autres', () {
      final old = buildChapterPageurls(
        chapterId: 1,
        pageUrls: [PageUrl('old')],
      );
      final other = buildChapterPageurls(
        chapterId: 2,
        pageUrls: [PageUrl('other')],
      );
      final merged = mergeChapterPageurls(
        [old, other],
        chapterId: 1,
        chapterUrl: 'u',
        pageUrls: [PageUrl('new1'), PageUrl('new2')],
      );
      expect(merged, hasLength(2));
      expect(merged.where((e) => e.chapterId == 1).single.urls, ['new1', 'new2']);
      expect(merged.where((e) => e.chapterId == 2).single.urls, ['other']);
    });

    test('entry désalignée existante remplacée, jamais fusionnée telle quelle', () {
      final corrupt = ChapterPageurls()
        ..chapterId = 5
        ..urls = List.generate(63, (i) => 'u$i')
        ..headers = List.generate(59, (i) => '{"p":$i}');
      final merged = mergeChapterPageurls(
        [corrupt],
        chapterId: 5,
        chapterUrl: 'u',
        pageUrls: [PageUrl('fresh')],
      );
      final entry = merged.single;
      expect(entry.urls, ['fresh']);
      // Invariant : headers null OU alignés avec urls.
      expect(
        entry.headers == null || entry.headers!.length == entry.urls!.length,
        isTrue,
      );
    });

    test('borne la taille du cache (éviction FIFO)', () {
      List<ChapterPageurls> cache = const [];
      for (var i = 0; i < kMaxChapterPageCacheEntries + 10; i++) {
        cache = mergeChapterPageurls(
          cache,
          chapterId: i,
          chapterUrl: 'u$i',
          pageUrls: [PageUrl('p$i')],
        );
      }
      expect(cache, hasLength(kMaxChapterPageCacheEntries));
      // Les plus anciens (0..9) sont évincés, le plus récent est en fin.
      expect(cache.first.chapterId, 10);
      expect(cache.last.chapterId, kMaxChapterPageCacheEntries + 9);
    });

    test('cache null existant → une seule entrée', () {
      final merged = mergeChapterPageurls(
        null,
        chapterId: 3,
        chapterUrl: 'u',
        pageUrls: [PageUrl('p')],
      );
      expect(merged, hasLength(1));
    });
  });

  group('cachedPagesUnchanged — détection de no-op', () {
    test('identique → true (écriture sautée)', () {
      final pages = [PageUrl('a'), PageUrl('b', headers: {'X': '1'})];
      final entry = buildChapterPageurls(
        chapterId: 1,
        chapterUrl: 'u',
        pageUrls: pages,
      );
      expect(cachedPagesUnchanged(entry, pages), isTrue);
    });

    test('entrée absente → false', () {
      expect(cachedPagesUnchanged(null, [PageUrl('a')]), isFalse);
    });

    test('URLs différentes → false', () {
      final entry = buildChapterPageurls(
        chapterId: 1,
        pageUrls: [PageUrl('a')],
      );
      expect(cachedPagesUnchanged(entry, [PageUrl('changed')]), isFalse);
    });

    test('headers différentes → false', () {
      final entry = buildChapterPageurls(
        chapterId: 1,
        pageUrls: [PageUrl('a', headers: {'X': '1'})],
      );
      final changed = [PageUrl('a', headers: {'X': '2'})];
      expect(cachedPagesUnchanged(entry, changed), isFalse);
    });

    test('ancien cache désaligné → false (sera réécrit aligné)', () {
      final entry = ChapterPageurls()
        ..chapterId = 1
        ..urls = const ['a', 'b', 'c']
        ..headers = const ['{"X":"1"}'];
      final pages = [PageUrl('a', headers: {'X': '1'}), PageUrl('b'), PageUrl('c')];
      expect(cachedPagesUnchanged(entry, pages), isFalse);
    });
  });

  group('ChapterPageurls.fromJson — normalisation d\'alignement', () {
    test('63 URLs / 59 headers → headers complétés à 63', () {
      final e = ChapterPageurls.fromJson({
        'chapterId': 1,
        'chapterUrl': 'https://src/ch/1',
        'urls': List.generate(63, (i) => 'u$i'),
        'headers': List.generate(59, (i) => '{"p":$i}'),
      });
      expect(e.urls, hasLength(63));
      expect(e.headers, hasLength(63));
      expect(e.headers![62], '{}');
      expect(e.chapterUrl, 'https://src/ch/1');
    });

    test('59 URLs / 63 headers → headers tronqués à 59', () {
      final e = ChapterPageurls.fromJson({
        'chapterId': 1,
        'urls': List.generate(59, (i) => 'u$i'),
        'headers': List.generate(63, (i) => '{"p":$i}'),
      });
      expect(e.urls, hasLength(59));
      expect(e.headers, hasLength(59));
    });

    test('urls vides → headers null', () {
      final e = ChapterPageurls.fromJson({
        'urls': <String>[],
        'headers': <String>['{}'],
      });
      expect(e.urls, isEmpty);
      expect(e.headers, isNull);
    });

    test('urls absentes → headers null', () {
      final e = ChapterPageurls.fromJson({});
      expect(e.urls, isNull);
      expect(e.headers, isNull);
    });

    test('roundtrip toJson → fromJson préserve les données', () {
      final original = buildChapterPageurls(
        chapterId: 12,
        chapterUrl: 'https://src/ch/12',
        pageUrls: [
          PageUrl('a', headers: {'X': '1'}),
          PageUrl('b'),
        ],
      );
      final restored = ChapterPageurls.fromJson(original.toJson());
      expect(restored.chapterId, 12);
      expect(restored.chapterUrl, 'https://src/ch/12');
      expect(restored.urls, original.urls);
      expect(restored.headers, original.headers);
    });
  });
}
