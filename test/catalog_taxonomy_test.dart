import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/catalog_entry.dart';
import 'package:watchtower/models/catalog_taxonomy.dart';

/// Minimal [CatalogEntryView] used to exercise the taxonomy and the shelf
/// builder without the Marketplace screen.
class FakeEntry implements CatalogEntryView {
  @override
  final int id;
  @override
  final String name;
  @override
  final List<String> tags;
  @override
  final int itemType;
  @override
  final List<String> languages;
  @override
  final DateTime? addedAt;
  @override
  final bool isNsfw;

  const FakeEntry({
    required this.id,
    this.name = 'Entry',
    this.tags = const [],
    this.itemType = 0,
    this.languages = const [],
    this.addedAt,
    this.isNsfw = false,
  });
}

void main() {
  group('vocabulary', () {
    test('every axis of the vocabulary is covered by allTags', () {
      expect(CatalogTaxonomy.allTags.toSet(), {
        ...CatalogTaxonomy.contentTags,
        ...CatalogTaxonomy.genreTags,
        ...CatalogTaxonomy.languageTags,
        ...CatalogTaxonomy.curationTags,
      });
    });

    test('allTags has no duplicate', () {
      expect(
        CatalogTaxonomy.allTags.length,
        CatalogTaxonomy.allTags.toSet().length,
      );
    });

    test('every genre and language tag is a known tag', () {
      for (final tag in [
        ...CatalogTaxonomy.genreTags,
        ...CatalogTaxonomy.languageTags,
      ]) {
        expect(CatalogTaxonomy.isKnownTag(tag), isTrue, reason: tag);
      }
    });
  });

  group('filterKnown', () {
    test('drops unknown tags', () {
      expect(
        CatalogTaxonomy.filterKnown(['manga', 'not-a-real-tag', 'french']),
        ['manga', 'french'],
      );
    });

    test('an index written by a newer build does not break an older one', () {
      // The tag is valid in a future vocabulary but unknown here.
      final tags = CatalogTaxonomy.filterKnown(['watch', 'holo-deck']);
      expect(tags, ['watch']);
    });

    test('orders tags by the vocabulary, not by the input', () {
      expect(CatalogTaxonomy.filterKnown(['french', 'manga', 'read']), [
        'read',
        'manga',
        'french',
      ]);
    });

    test('normalises case and whitespace', () {
      expect(CatalogTaxonomy.filterKnown([' Manga ', 'FRENCH']), [
        'manga',
        'french',
      ]);
    });

    test('tolerates an empty list', () {
      expect(CatalogTaxonomy.filterKnown(const []), isEmpty);
    });
  });

  group('languageTagFor', () {
    test('maps regional codes to the base language', () {
      expect(CatalogTaxonomy.languageTagFor('fr-CA'), 'french');
      expect(CatalogTaxonomy.languageTagFor('pt-BR'), 'portuguese');
      expect(CatalogTaxonomy.languageTagFor('zh-TW'), 'chinese');
    });

    test('maps "all" to multilingual', () {
      expect(CatalogTaxonomy.languageTagFor('all'), 'multilingual');
    });

    test('returns null for an unknown code instead of guessing', () {
      expect(CatalogTaxonomy.languageTagFor('xx'), isNull);
      expect(CatalogTaxonomy.languageTagFor(''), isNull);
    });
  });

  group('itemTypeToContent', () {
    test('maps each published index to its content tag', () {
      expect(CatalogTaxonomy.itemTypeToContent[0], 'read');
      expect(CatalogTaxonomy.itemTypeToContent[1], 'watch');
      expect(CatalogTaxonomy.itemTypeToContent[2], 'read');
      expect(CatalogTaxonomy.itemTypeToContent[3], 'music');
      expect(CatalogTaxonomy.itemTypeToContent[4], 'game');
      expect(CatalogTaxonomy.itemTypeToContent[7], 'watch');
    });
  });

  group('effectiveTags', () {
    test('uses the declared tags when the index publishes them', () {
      const entry = FakeEntry(
        id: 1,
        tags: ['read', 'manhwa', 'korean'],
        itemType: 0,
        languages: ['ko'],
      );
      expect(effectiveTags(entry), containsAll(['read', 'manhwa', 'korean']));
    });

    test('adds the catalogue content tag even when the index omits it', () {
      const entry = FakeEntry(id: 1, tags: ['manhwa'], itemType: 0);
      expect(effectiveTags(entry), containsAll(['read', 'manhwa']));
    });

    test('derives tags for a legacy index that publishes none', () {
      // No tags at all: the catalogue and the declared languages are the only
      // facts available, and they are enough to shelve the entry.
      const entry = FakeEntry(id: 1, itemType: 0, languages: ['fr']);
      expect(effectiveTags(entry), ['read', 'french']);
    });

    test('never derives a tag from the extension name', () {
      // The name says "manhwa", but nothing in the entry's data does, so it
      // must not be shelved as manhwa.
      const entry = FakeEntry(id: 1, name: 'Manhwa Kingdom', itemType: 0);
      expect(effectiveTags(entry), ['read']);
      expect(effectiveTags(entry), isNot(contains('manhwa')));
    });

    test('a legacy entry with no metadata yields no tags, not a wrong one', () {
      const entry = FakeEntry(id: 1, itemType: 99);
      expect(effectiveTags(entry), isEmpty);
    });

    test('an unknown language code contributes no language tag', () {
      const entry = FakeEntry(id: 1, itemType: 1, languages: ['xx']);
      expect(effectiveTags(entry), ['watch']);
    });

    test('is deterministic regardless of the order languages are declared', () {
      const a = FakeEntry(id: 1, itemType: 0, languages: ['en', 'fr']);
      const b = FakeEntry(id: 2, itemType: 0, languages: ['fr', 'en']);
      expect(effectiveTags(a), effectiveTags(b));
    });
  });

  group('new-entry window', () {
    final reference = DateTime(2026, 6, 1);

    test('an entry inside the window is new', () {
      final entry = FakeEntry(id: 1, addedAt: DateTime(2026, 5, 1));
      expect(isNewEntry(entry, reference), isTrue);
    });

    test('an entry older than the window is not new', () {
      final entry = FakeEntry(id: 1, addedAt: DateTime(2024, 1, 1));
      expect(isNewEntry(entry, reference), isFalse);
    });

    test('an entry with no date is never claimed as new', () {
      const entry = FakeEntry(id: 1);
      expect(isNewEntry(entry, reference), isFalse);
    });

    test('with no catalogue reference nothing is new', () {
      final entry = FakeEntry(id: 1, addedAt: DateTime(2026, 5, 1));
      expect(isNewEntry(entry, null), isFalse);
    });

    test('newestAddedAt ignores entries without a date', () {
      final entries = [
        const FakeEntry(id: 1),
        FakeEntry(id: 2, addedAt: DateTime(2026, 1, 1)),
        FakeEntry(id: 3, addedAt: DateTime(2026, 5, 1)),
      ];
      expect(newestAddedAt(entries), DateTime(2026, 5, 1));
    });

    test('newestAddedAt is null when no entry declares a date', () {
      expect(newestAddedAt([const FakeEntry(id: 1)]), isNull);
    });
  });
}
