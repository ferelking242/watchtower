import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_badges.dart';

/// The badge contract is shared by every extension: a source publishes short
/// tokens, the app decides how they look. These tests pin the parsing so a
/// new token cannot silently change an existing card.
void main() {
  group('MediaBadge token parsing', () {
    test('parses language, censorship, subtitle and dub tokens', () {
      final badges = MediaBadge.parseAll([
        'lang:ja',
        'uncensored',
        'sub:en',
        'dub:fr',
      ]);

      expect(badges.map((badge) => badge.kind), [
        MediaBadgeKind.language,
        MediaBadgeKind.uncensored,
        MediaBadgeKind.subtitle,
        MediaBadgeKind.dub,
      ]);
      expect(badges[0].code, 'ja');
      expect(badges[2].code, 'en');
      expect(badges[3].code, 'fr');
    });

    test('censored and leak stay distinct', () {
      final censored = MediaBadge.parse('censored');
      final leak = MediaBadge.parse('leak');
      expect(censored?.kind, MediaBadgeKind.censored);
      expect(leak?.kind, MediaBadgeKind.leak);
    });

    test('ignores unknown, empty and duplicate tokens', () {
      final badges = MediaBadge.parseAll([
        'lang:ja',
        '',
        null,
        'sponsored',
        'lang:ja',
        'sub',
      ]);
      expect(badges, hasLength(1));
      expect(badges.single.kind, MediaBadgeKind.language);
    });

    test('a language token without a value is dropped, not rendered empty', () {
      expect(MediaBadge.parse('lang:'), isNull);
      expect(MediaBadge.parse('sub:'), isNull);
    });
  });

  group('ContentItem badges', () {
    test('carries the badges published by the extension', () {
      final item = ContentItem.fromManga(
        MManga(
          name: 'Sample',
          link: 'https://example.test/en/sample',
          badges: const ['lang:ja', 'uncensored'],
        ),
      );
      expect(item.badges, ['lang:ja', 'uncensored']);
    });

    test('an extension without badges yields an empty list', () {
      final item = ContentItem.fromManga(
        MManga(name: 'Sample', link: 'https://example.test/en/sample'),
      );
      expect(item.badges, isEmpty);
    });
  });

  group('MManga serialisation', () {
    test('badges survive a JSON round-trip', () {
      final restored = MManga.fromJson({
        'name': 'Sample',
        'link': 'https://example.test/en/sample',
        'genre': ['Drama'],
        'badges': ['lang:ja', 'sub:en'],
        'status': 0,
      });
      expect(restored.badges, ['lang:ja', 'sub:en']);
      expect(restored.toJson()['badges'], ['lang:ja', 'sub:en']);
    });

    test('a missing field is null, not an empty list', () {
      final restored = MManga.fromJson({'name': 'Sample'});
      expect(restored.badges, isNull);
      expect(restored.status, Status.unknown);
    });
  });
}
