import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/catalog_shelf.dart';
import 'package:watchtower/models/catalog_taxonomy.dart';
import 'package:watchtower/services/catalog_shelf_builder.dart';

import 'catalog_taxonomy_test.dart' show FakeEntry;

CatalogShelfSpec _spec({
  String id = 'test',
  List<String> all = const [],
  List<String> any = const [],
  List<String> none = const [],
  bool newOnly = false,
  bool includeNsfw = false,
  CatalogSort sort = CatalogSort.curated,
  int minEntries = kShelfMinEntries,
}) => CatalogShelfSpec(
  id: id,
  title: (_) => id,
  all: all,
  any: any,
  none: none,
  newOnly: newOnly,
  includeNsfw: includeNsfw,
  sort: sort,
  minEntries: minEntries,
);

void main() {
  group('matching', () {
    test('all requires every tag', () {
      final spec = _spec(all: ['read', 'manga']);
      expect(spec.matches(['read', 'manga'], isNew: false), isTrue);
      expect(spec.matches(['read'], isNew: false), isFalse);
    });

    test('any requires at least one tag', () {
      final spec = _spec(any: ['manga', 'manhwa']);
      expect(spec.matches(['manhwa'], isNew: false), isTrue);
      expect(spec.matches(['novel'], isNew: false), isFalse);
    });

    test('none excludes a tag', () {
      final spec = _spec(none: ['game']);
      expect(spec.matches(['read'], isNew: false), isTrue);
      expect(spec.matches(['game'], isNew: false), isFalse);
    });

    test('an adult entry never matches a shelf that did not opt in', () {
      final spec = _spec(all: ['read']);
      expect(
        spec.matches(['read'], isNew: false, isNsfw: true, allowNsfw: true),
        isFalse,
      );
    });

    test('an adult shelf stays closed until the user opts in', () {
      final adult = _spec(all: ['read'], includeNsfw: true);
      expect(adult.matches(['read'], isNew: false, isNsfw: true), isFalse);
      expect(
        adult.matches(['read'], isNew: false, isNsfw: true, allowNsfw: true),
        isTrue,
      );
    });

    test('a non-adult entry matches an adult shelf regardless of opt-in', () {
      final adult = _spec(all: ['read'], includeNsfw: true);
      expect(adult.matches(['read'], isNew: false), isTrue);
    });

    test('newOnly requires the entry to be new', () {
      final spec = _spec(newOnly: true);
      expect(spec.matches(const [], isNew: true), isTrue);
      expect(spec.matches(const [], isNew: false), isFalse);
    });
  });

  group('ordering', () {
    final entries = [
      FakeEntry(
        id: 1,
        name: 'Zulu',
        itemType: 0,
        addedAt: DateTime(2026, 1, 1),
      ),
      FakeEntry(
        id: 2,
        name: 'Alpha',
        itemType: 0,
        addedAt: DateTime(2026, 5, 1),
      ),
      FakeEntry(
        id: 3,
        name: 'Bravo',
        itemType: 0,
        addedAt: DateTime(2026, 4, 1),
        tags: ['featured'],
      ),
      FakeEntry(id: 4, name: 'NoDate', itemType: 0),
    ];
    final builder = CatalogShelfBuilder(entries);

    test('curated puts featured first, then the most recent', () {
      final ordered = builder.entriesFor(_spec(all: ['read']));
      expect(ordered.map((entry) => entry.id).toList(), [3, 2, 1, 4]);
      expect(builder.newestAdded, DateTime(2026, 5, 1));
    });

    test('newest sorts by date and pushes undated entries last', () {
      final ordered = builder.entriesFor(
        _spec(all: ['read'], sort: CatalogSort.newest),
      );
      expect(ordered.map((entry) => entry.id).toList(), [2, 3, 1, 4]);
    });

    test('alphabetical is case-insensitive', () {
      final ordered = builder.entriesFor(
        _spec(all: ['read'], sort: CatalogSort.alphabetical),
      );
      expect(ordered.map((entry) => entry.name).toList(), [
        'Alpha',
        'Bravo',
        'NoDate',
        'Zulu',
      ]);
    });

    test(
      'the order is total, so equal names still order deterministically',
      () {
        final tied = [
          const FakeEntry(id: 9, name: 'Same', itemType: 0),
          const FakeEntry(id: 2, name: 'same', itemType: 0),
        ];
        final ordered = CatalogShelfBuilder(
          tied,
        ).entriesFor(_spec(all: ['read']));
        expect(ordered.map((entry) => entry.id).toList(), [2, 9]);
      },
    );

    test('two builds of the same catalogue produce the same order', () {
      final first = CatalogShelfBuilder(
        entries,
      ).entriesFor(_spec(all: ['read'])).map((entry) => entry.id).toList();
      final second = CatalogShelfBuilder(
        entries.reversed,
      ).entriesFor(_spec(all: ['read'])).map((entry) => entry.id).toList();
      expect(first, second);
    });

    test('limit caps the result without reordering', () {
      final ordered = builder.entriesFor(_spec(all: ['read']), limit: 2);
      expect(ordered.map((entry) => entry.id).toList(), [3, 2]);
    });
  });

  group('adult content', () {
    final entries = [
      const FakeEntry(id: 1, itemType: 0),
      const FakeEntry(id: 2, itemType: 0, isNsfw: true),
    ];
    final adultSpec = _spec(all: ['read'], includeNsfw: true);

    test('is excluded by default', () {
      final builder = CatalogShelfBuilder(entries);
      final ordered = builder.entriesFor(_spec(all: ['read']));
      expect(ordered.map((entry) => entry.id).toList(), [1]);
    });

    test('a normal shelf keeps refusing it after the user opts in', () {
      final builder = CatalogShelfBuilder(entries);
      final ordered = builder.entriesFor(_spec(all: ['read']), showNsfw: true);
      expect(ordered.map((entry) => entry.id).toList(), [1]);
    });

    test('an adult shelf stays closed until the user opts in', () {
      final builder = CatalogShelfBuilder(entries);
      expect(builder.entriesFor(adultSpec).map((entry) => entry.id), [1]);
    });

    test('an adult shelf shows adult entries once the user opts in', () {
      final builder = CatalogShelfBuilder(entries);
      final ordered = builder.entriesFor(adultSpec, showNsfw: true);
      expect(ordered.map((entry) => entry.id).toList(), [1, 2]);
    });
  });

  group('shelves', () {
    final entries = [
      for (var i = 0; i < 6; i++)
        FakeEntry(id: i, name: 'Read $i', itemType: 0),
      for (var i = 10; i < 16; i++)
        FakeEntry(id: i, name: 'Watch $i', itemType: 1),
    ];
    final builder = CatalogShelfBuilder(entries);

    test('drops a shelf below its minimum', () {
      final shelves = builder.shelves([
        _spec(id: 'read', all: ['read']),
        _spec(id: 'manga', all: ['read', 'manga']),
      ]);
      expect(shelves.map((shelf) => shelf.spec.id).toList(), ['read']);
    });

    test('keeps a shelf that reaches its minimum', () {
      final shelves = builder.shelves([
        _spec(id: 'read', all: ['read'], minEntries: 6),
      ]);
      expect(shelves, hasLength(1));
      expect(shelves.single.length, 6);
    });

    test('drops a second shelf that would show the same first cards', () {
      final shelves = builder.shelves([
        _spec(id: 'read', all: ['read']),
        _spec(id: 'read_again', all: ['read']),
        _spec(id: 'watch', all: ['watch']),
      ]);
      expect(shelves.map((shelf) => shelf.spec.id).toList(), ['read', 'watch']);
    });

    test('a single-entry shelf is exempt from the duplicate rule', () {
      // Two one-entry shelves may legitimately point at the same extension.
      final shelves = builder.shelves([
        _spec(id: 'a', all: ['read'], minEntries: 1),
        _spec(id: 'b', all: ['read'], minEntries: 1),
      ]);
      expect(shelves, hasLength(2));
    });

    test('shelves keep the order they were declared in', () {
      final shelves = builder.shelves([
        _spec(id: 'watch', all: ['watch']),
        _spec(id: 'read', all: ['read']),
      ]);
      expect(shelves.map((shelf) => shelf.spec.id).toList(), ['watch', 'read']);
    });
  });

  group('legacy catalogue', () {
    test('an index with no tags is still shelved by catalogue and language', () {
      // The entries declare no tag at all: only the catalogue they live in and
      // their language are available, and that is enough to shelve them.
      final builder = CatalogShelfBuilder([
        for (var i = 0; i < 4; i++)
          FakeEntry(id: 100 + i, itemType: 0, languages: ['fr']),
      ]);
      final french = CatalogShelves.read.firstWhere(
        (shelf) => shelf.id == 'read_french',
      );
      final matched = builder.entriesFor(french);
      expect(matched, hasLength(4));
      expect(
        builder.shelves(CatalogShelves.read).map((shelf) => shelf.spec.id),
        contains('read_popular'),
      );
    });

    test('two shelves that would list the same entries collapse into one', () {
      // Every read source is French, so "Popular to read" and "French sources"
      // are the same list; only the first is rendered.
      final builder = CatalogShelfBuilder([
        for (var i = 0; i < 4; i++)
          FakeEntry(id: 100 + i, itemType: 0, languages: ['fr']),
      ]);
      final ids = builder
          .shelves(CatalogShelves.read)
          .map((shelf) => shelf.spec.id);
      expect(ids, contains('read_popular'));
      expect(ids, isNot(contains('read_french')));
    });

    test('an entry with no metadata is never shelved into a wrong group', () {
      final builder = CatalogShelfBuilder([
        for (var i = 0; i < 4; i++)
          FakeEntry(id: 200 + i, itemType: 0, name: 'Manhwa Scans $i'),
      ]);
      final shelves = builder.shelves(CatalogShelves.read);
      expect(
        shelves.map((shelf) => shelf.spec.id),
        isNot(contains('read_manhwa')),
      );
    });
  });

  group('declared shelves', () {
    test('every shelf id is unique across the declared lists', () {
      final ids = CatalogShelves.byId.keys.toList();
      expect(ids.length, ids.toSet().length);
    });

    test('forYou exposes the discovery groups from the brief', () {
      final ids = CatalogShelves.forYou.map((shelf) => shelf.id).toSet();
      expect(
        ids,
        containsAll([
          'foryou_recommended',
          'foryou_watch_popular',
          'foryou_read_popular',
          'foryou_manga_manhwa',
          'foryou_novels',
          'foryou_new',
          'foryou_multilingual',
        ]),
      );
    });

    test('the watch tab separates the genres the brief lists', () {
      final ids = CatalogShelves.watch.map((shelf) => shelf.id).toSet();
      expect(
        ids,
        containsAll([
          'watch_popular',
          'watch_movies',
          'watch_series',
          'watch_anime',
          'watch_animation',
          'watch_documentary',
          'watch_scifi',
          'watch_fantasy',
          'watch_action',
          'watch_romance',
          'watch_new',
        ]),
      );
    });

    test('the reading shelves cover manga, manhwa, manhua and webtoons', () {
      final ids = CatalogShelves.read.map((shelf) => shelf.id).toSet();
      expect(
        ids,
        containsAll([
          'read_popular',
          'read_manga',
          'read_manhwa',
          'read_manhua',
          'read_webtoon',
          'read_comics',
          'read_novel',
          'read_french',
          'read_english',
          'read_multilingual',
          'read_new',
        ]),
      );
    });

    test(
      'language shelves never carry a content tag they do not filter on',
      () {
        for (final shelf in [...CatalogShelves.read, ...CatalogShelves.novel]) {
          if (!shelf.id.contains('french') &&
              !shelf.id.contains('english') &&
              !shelf.id.contains('multilingual')) {
            continue;
          }
          expect(
            shelf.all,
            contains('read'),
            reason: '${shelf.id} must stay inside the reading catalogue',
          );
        }
      },
    );

    test('every declared tag exists in the vocabulary', () {
      for (final shelf in CatalogShelves.byId.values) {
        for (final tag in [...shelf.all, ...shelf.any, ...shelf.none]) {
          expect(
            CatalogTaxonomy.isKnownTag(tag),
            isTrue,
            reason: '${shelf.id} declares the unknown tag "$tag"',
          );
        }
      }
    });

    test('adult shelves are the only ones that opt into adult content', () {
      final adultIds = CatalogShelves.adult.map((shelf) => shelf.id).toSet();
      expect(adultIds, {'adult_watch', 'adult_read'});
      for (final shelf in CatalogShelves.byId.values) {
        if (adultIds.contains(shelf.id)) {
          expect(
            shelf.includeNsfw,
            isTrue,
            reason: '${shelf.id} is an adult shelf and must opt in',
          );
        } else {
          expect(
            shelf.includeNsfw,
            isFalse,
            reason: '${shelf.id} must not opt into adult content',
          );
        }
      }
    });

    test('every shelf is reachable by id', () {
      for (final shelf in [
        ...CatalogShelves.forYou,
        ...CatalogShelves.watch,
        ...CatalogShelves.read,
        ...CatalogShelves.novel,
        ...CatalogShelves.music,
        ...CatalogShelves.game,
        ...CatalogShelves.adult,
      ]) {
        expect(
          CatalogShelves.byId[shelf.id],
          same(shelf),
          reason: '${shelf.id} is missing from CatalogShelves.byId',
        );
      }
    });
  });
}
