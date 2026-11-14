import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/utils/isar_batch.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// These helpers replace the per-row `IsarLink` / backlink reads that ran one
/// synchronous Isar query per visible card on the UI isolate. The contract that
/// must hold is exact equivalence with those links, only batched.

Manga _manga(
  int id, {
  required String name,
  String source = 'src',
  String lang = 'en',
  int? sourceId,
  ItemType itemType = ItemType.manga,
}) => Manga(
  id: id,
  source: source,
  author: '',
  artist: '',
  genre: const [],
  imageUrl: '',
  lang: lang,
  link: '',
  name: name,
  status: Status.unknown,
  description: '',
  sourceId: sourceId,
  itemType: itemType,
);

Chapter _chapter(int id, int mangaId, String name) =>
    Chapter(id: id, mangaId: mangaId, name: name);

void main() {
  late MockIsar mock;

  setUp(() {
    mock = MockIsar();
    app.isar = mock;
  });

  group('loadMangasByIds', () {
    test('resolves every requested id and drops missing ones', () {
      mock.seed<Manga>(1, _manga(1, name: 'A'));
      mock.seed<Manga>(2, _manga(2, name: 'B'));

      final byId = loadMangasByIds([1, 2, 999]);

      expect(byId.keys.toSet(), {1, 2});
      expect(byId[1]!.name, 'A');
      expect(byId[2]!.name, 'B');
    });

    test('ignores null ids and duplicates', () {
      mock.seed<Manga>(1, _manga(1, name: 'A'));
      final byId = loadMangasByIds([1, null, 1]);
      expect(byId.keys.toList(), [1]);
    });

    test('empty input yields an empty map', () {
      expect(loadMangasByIds(const <int?>[]), isEmpty);
    });
  });

  group('loadChaptersByIds', () {
    test('resolves chapters by their primary key', () {
      mock.seed<Chapter>(10, _chapter(10, 1, 'c1'));
      mock.seed<Chapter>(11, _chapter(11, 1, 'c2'));

      final byId = loadChaptersByIds([10, 11, 404]);

      expect(byId.keys.toSet(), {10, 11});
      expect(byId[10]!.name, 'c1');
    });
  });

  group('loadChaptersByMangaIds', () {
    test('groups chapters under their mangaId', () {
      mock.seed<Chapter>(10, _chapter(10, 1, 'c1'));
      mock.seed<Chapter>(11, _chapter(11, 1, 'c2'));
      mock.seed<Chapter>(12, _chapter(12, 2, 'c3'));

      final byManga = loadChaptersByMangaIds([1, 2]);

      expect(byManga[1]!.map((c) => c.name), ['c1', 'c2']);
      expect(byManga[2]!.map((c) => c.name), ['c3']);
    });

    test('returns nothing for manga with no chapters', () {
      final byManga = loadChaptersByMangaIds([7]);
      expect(byManga[7], isNull);
    });

    test('empty input yields an empty map', () {
      expect(loadChaptersByMangaIds(const <int?>[]), isEmpty);
    });

    test('chunks a very large id list without losing rows', () {
      const total = 1200; // > the 500-per-chunk batch size.
      for (var i = 0; i < total; i++) {
        mock.seed<Chapter>(1000 + i, _chapter(1000 + i, i, 'c$i'));
      }
      final byManga = loadChaptersByMangaIds(
        List<int>.generate(total, (i) => i),
      );
      expect(byManga.length, total);
      expect(byManga[0]!.single.name, 'c0');
      expect(byManga[total - 1]!.single.name, 'c${total - 1}');
    });

    test('large id sets group through the range walk', () {
      // Above `_kIndexSeekThreshold` the helper switches from one `anyOf`
      // index seek per id to a single `mangaIdBetween` walk. Grouping and
      // per-manga order must stay identical to the per-manga backlink.
      const mangaCount = 40; // > the 25-id threshold.
      for (var m = 0; m < mangaCount; m++) {
        for (var c = 0; c < 5; c++) {
          mock.seed<Chapter>(
            m * 10 + c,
            _chapter(m * 10 + c, m, 'm$m-c$c'),
          );
        }
      }
      final byManga = loadChaptersByMangaIds(
        List<int>.generate(mangaCount, (i) => i),
      );
      expect(byManga.length, mangaCount);
      for (var m = 0; m < mangaCount; m++) {
        expect(
          byManga[m]!.map((c) => c.name),
          ['m$m-c0', 'm$m-c1', 'm$m-c2', 'm$m-c3', 'm$m-c4'],
        );
      }
    });

    test('range walk ignores ids outside the requested set', () {
      // Chapters exist for manga 0..40, but only a sparse subset is requested;
      // the range walk must not leak the in-between manga into the result.
      for (var m = 0; m < 41; m++) {
        mock.seed<Chapter>(m, _chapter(m, m, 'm$m'));
      }
      final byManga = loadChaptersByMangaIds([0, 40, 3, 17, 29, 8, 33, 12, 25, 1, 39, 2, 7, 11, 19, 21, 23, 27, 31, 35, 37, 5, 9, 13, 15, 20]);
      expect(byManga.keys.toSet(), {0, 40, 3, 17, 29, 8, 33, 12, 25, 1, 39, 2, 7, 11, 19, 21, 23, 27, 31, 35, 37, 5, 9, 13, 15, 20});
      expect(byManga[4], isNull);
    });
  });

  group('libraryRowsFor', () {
    test('matches on name + source + lang and keeps sourceId fallback', () {
      final a = _manga(1, name: 'Naruto', source: 'MangaDex', lang: 'en');
      final b = _manga(
        2,
        name: 'Naruto',
        source: 'MangaDex',
        lang: 'en',
        sourceId: 5,
      );
      final byKey = <String, List<Manga>>{
        'Naruto\u0000MangaDex\u0000en': [a, b],
      };

      final rows = libraryRowsFor(
        byKey,
        name: 'Naruto',
        source: 'MangaDex',
        lang: 'en',
        sourceId: 5,
      );

      // `a` has a null sourceId -> matches any source; `b` matches exactly 5.
      expect(rows.map((m) => m.id), [1, 2]);
    });

    test('a non-matching sourceId is excluded', () {
      final b = _manga(
        2,
        name: 'Naruto',
        source: 'MangaDex',
        lang: 'en',
        sourceId: 9,
      );
      final byKey = <String, List<Manga>>{
        'Naruto\u0000MangaDex\u0000en': [b],
      };

      final rows = libraryRowsFor(
        byKey,
        name: 'Naruto',
        source: 'MangaDex',
        lang: 'en',
        sourceId: 5,
      );

      expect(rows, isEmpty);
    });

    test('null name, empty map and unknown key all return empty', () {
      expect(
        libraryRowsFor(null, name: null, source: 's', lang: 'en', sourceId: 1),
        isEmpty,
      );
      expect(
        libraryRowsFor(
          const {},
          name: 'X',
          source: 's',
          lang: 'en',
          sourceId: 1,
        ),
        isEmpty,
      );
    });
  });
}
