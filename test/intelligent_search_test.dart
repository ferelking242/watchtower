import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/intelligent_search.dart';

void main() {
  group('normalizeTitle', () {
    test('folds case, diacritics and punctuation', () {
      expect(normalizeTitle('Shingeki no Kyojin!'), 'shingeki no kyojin');
      expect(normalizeTitle('École  des  Héros'), 'ecole des heros');
    });
  });

  group('titleMatches', () {
    test('exact, prefix and substring matches', () {
      expect(titleMatches('Naruto', 'Naruto'), isTrue);
      expect(titleMatches('naruto', 'Naruto Shippuden'), isTrue);
      expect(titleMatches('shingeki', 'Shingeki no Kyojin'), isTrue);
    });

    test('absorbs typos but keeps unrelated titles out', () {
      expect(titleMatches('Narufo', 'Naruto'), isTrue);
      expect(titleMatches('Naruto', 'One Piece'), isFalse);
      // A very short query must not match a long title by accident (a shared
      // bigram is not enough).
      expect(titleMatches('art', 'Naruto'), isFalse);
    });

    test('word-order independent multi-token match', () {
      expect(titleMatches('kyojin shingeki', 'Shingeki no Kyojin'), isTrue);
      // A typo in one token of a multi-token query still matches.
      expect(titleMatches('shingeki no kiojin', 'Shingeki no Kyojin'), isTrue);
    });

    test('matches ampersand against the spelled-out "and"', () {
      expect(titleMatches('fate and destiny', 'Fate & Destiny'), isTrue);
      expect(titleMatches('fate & destiny', 'Fate & Destiny'), isTrue);
    });
  });

  group('titleMatchScore', () {
    test('orders an exact title above a loose one', () {
      final exact = titleMatchScore('naruto', 'Naruto');
      final loose = titleMatchScore('naruto', 'Naruto Shippuden');
      expect(exact, greaterThan(loose));
      expect(loose, greaterThan(0));
    });

    test('an unrelated title scores zero', () {
      expect(titleMatchScore('naruto', 'One Piece'), 0);
    });

    test('a synonym only matches once the query is expanded', () {
      // "attaque des titans" is French; a source that only knows the romaji
      // name is reached through `intelligentQueryVariants`, not the raw
      // matcher — this is exactly the "intelligent retry" behaviour.
      expect(titleMatches('attaque des titans', 'Shingeki no Kyojin'), isFalse);
      final variants = intelligentQueryVariants('attaque des titans')
          .map(normalizeTitle)
          .toList();
      expect(variants, contains('shingeki no kyojin'));
      expect(variants.any((v) => titleMatches(v, 'Shingeki no Kyojin')), isTrue);
    });
  });

  group('intelligentQueryVariants', () {
    test('expands a known title into its alternative names', () {
      final variants = intelligentQueryVariants(
        'attaque des titans',
      ).map(normalizeTitle).toSet();
      expect(variants, contains('shingeki no kyojin'));
      expect(variants, contains('attack on titan'));
      expect(variants, contains('attaque des titans'));
    });

    test('strips leading articles', () {
      expect(
        intelligentQueryVariants('the promised neverland').map(normalizeTitle),
        contains('promised neverland'),
      );
    });

    test('is empty for an empty query', () {
      expect(intelligentQueryVariants('   '), isEmpty);
    });

    test('a single short token does not pull in a whole synonym group', () {
      // "one" must not expand to "one piece" (and vice versa is fine, but the
      // short side must stay quiet).
      final variants =
          intelligentQueryVariants('one').map(normalizeTitle).toSet();
      expect(variants, isNot(contains('one piece')));
    });

    test('a full multi-token query expands to its group', () {
      final variants = intelligentQueryVariants('my hero academia')
          .map(normalizeTitle)
          .toSet();
      expect(variants, contains('boku no hero academia'));
    });
  });
}
