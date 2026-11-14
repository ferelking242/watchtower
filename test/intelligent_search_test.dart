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
  });
}
