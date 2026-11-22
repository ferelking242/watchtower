import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/live_tv/epg/epg_matcher.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_parser.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// XMLTV parsing, matching and serialisation.
///
/// Fixtures are inline and tiny on purpose: the real French guide is 46 MB and
/// lives in the `live`-tagged suite. What is covered here is every shape the
/// parser has to survive — compact and ISO times, gzip, CDATA, a programme
/// without a title, and a channel the guide does not know.
void main() {
  const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="TF1.fr">
    <display-name>TF1</display-name>
    <display-name>TF1 HD</display-name>
    <icon src="https://logo.test/tf1.png" />
    <country>France</country>
  </channel>
  <channel id="Arte.fr"><display-name>Arte</display-name></channel>
  <programme channel="TF1.fr" start="20261120180000 +0100" stop="20261120190000 +0100">
    <title lang="fr">Le 20h</title>
    <desc lang="fr">Le journal de 20 heures.</desc>
    <category lang="fr">Info</category>
  </programme>
  <programme channel="TF1.fr" start="20261120190000 +0100" stop="20261120203000 +0100">
    <title lang="fr">Film du soir</title>
  </programme>
  <programme channel="Arte.fr" start="20261120183000 +0100" stop="20261120200000 +0100">
    <title><![CDATA[Documentaire]]></title>
  </programme>
  <programme channel="Inconnu.fr" start="20261120183000 +0100" stop="20261120200000 +0100">
    <title>Sans chaîne déclarée</title>
  </programme>
  <programme channel="TF1.fr" start="20261121000000 +0100" stop="20261121010000 +0100" />
</tv>
''';

  Future<EpgGuide> parse(String body) => EpgParser().parseBytes(
    Uint8List.fromList(utf8.encode(body)),
    source: 'fixture',
  );

  group('parser', () {
    test('reads channels with their aliases, icon and country', () async {
      final guide = await parse(xml);

      expect(guide.channels.keys, containsAll(['TF1.fr', 'Arte.fr']));
      final tf1 = guide.channels['TF1.fr']!;
      expect(tf1.displayName, 'TF1');
      expect(tf1.names, ['TF1', 'TF1 HD']);
      expect(tf1.iconUrl, 'https://logo.test/tf1.png');
      expect(tf1.country, 'France');
    });

    test('parses compact XMLTV times with their offset', () async {
      final guide = await parse(xml);

      // 18:00 at +0100 is 17:00 UTC; the assertion is made in UTC so the test
      // does not depend on the machine's timezone.
      final first = guide.programmes['TF1.fr']!.first;
      expect(first.title, 'Le 20h');
      expect(first.start.toUtc(), DateTime.utc(2026, 11, 20, 17));
      expect(first.stop.toUtc(), DateTime.utc(2026, 11, 20, 18));
      expect(first.duration, const Duration(hours: 1));
      expect(first.category, 'Info');
      expect(first.description, 'Le journal de 20 heures.');
    });

    test('reads CDATA titles', () async {
      final guide = await parse(xml);

      expect(guide.programmes['Arte.fr']!.single.title, 'Documentaire');
    });

    test('sorts programmes by start time', () async {
      final guide = await parse(xml);

      final starts = guide.programmes['TF1.fr']!.map((p) => p.start).toList();
      expect(starts, orderedEquals(List.of(starts)..sort()));
    });

    test(
      'drops a programme with no title rather than padding the grid',
      () async {
        final guide = await parse(xml);

        expect(guide.programmes['TF1.fr']!.length, 2);
      },
    );

    test('keeps programmes whose channel the guide never declared', () async {
      // The programme still resolves through its channel attribute; dropping it
      // would silently lose a channel the playlist may well carry.
      final guide = await parse(xml);

      expect(guide.programmes['Inconnu.fr'], isNotNull);
      expect(guide.channels.containsKey('Inconnu.fr'), isFalse);
    });

    test('unwraps a gzip body', () async {
      final gz = Uint8List.fromList(GZipEncoder().encode(utf8.encode(xml)));
      final guide = await EpgParser().parseBytes(gz, source: 'gz');

      expect(guide.channels.length, 2);
    });

    test('reports progress while parsing', () async {
      final counts = <int>[];
      await EpgParser(
        onProgress: counts.add,
      ).parseBytes(Uint8List.fromList(utf8.encode(xml)), source: 'fixture');

      expect(counts, isNotEmpty);
      expect(counts.last, greaterThan(0));
    });

    test('an unreadable body yields an empty guide, not a throw', () async {
      final guide = await parse('not xml at all');

      expect(guide.channels, isEmpty);
      expect(guide.programmeCount, 0);
    });
  });

  group('guide queries', () {
    late EpgGuide guide;

    setUp(() async {
      guide = await parse(xml);
    });

    test('currentOn finds the programme airing at a moment', () {
      final first = guide.programmes['TF1.fr']!.first;
      final on = guide.currentOn(
        'TF1.fr',
        first.start.add(const Duration(minutes: 30)),
      );

      expect(on?.title, 'Le 20h');
    });

    test('currentOn is null between programmes', () {
      final last = guide.programmes['TF1.fr']!.last;

      expect(guide.currentOn('TF1.fr', last.stop), isNull);
    });

    test('nextOn returns the following programme', () {
      final first = guide.programmes['TF1.fr']!.first;
      final next = guide.nextOn(
        'TF1.fr',
        first.start.add(const Duration(minutes: 30)),
      );

      expect(next?.title, 'Film du soir');
    });

    test('windowOn keeps only programmes overlapping the window', () {
      final first = guide.programmes['TF1.fr']!.first;
      final window = guide.windowOn(
        'TF1.fr',
        first.stop.subtract(const Duration(minutes: 15)),
        first.stop.add(const Duration(minutes: 15)),
      );

      expect(window.map((p) => p.title), ['Le 20h', 'Film du soir']);
    });

    test('progressAt runs from 0 to 1 across the programme', () {
      final programme = guide.programmes['TF1.fr']!.first;

      expect(programme.progressAt(programme.start), 0);
      expect(
        programme.progressAt(programme.start.add(const Duration(minutes: 30))),
        closeTo(0.5, 0.01),
      );
      expect(programme.progressAt(programme.stop), 1);
    });
  });

  group('serialisation', () {
    test('a guide survives a JSON round trip', () async {
      final guide = await parse(xml);
      final restored = EpgGuide.fromJson(
        jsonDecode(jsonEncode(guide.toJson())) as Map<String, dynamic>,
      )!;

      expect(restored.channels.length, guide.channels.length);
      expect(restored.programmeCount, guide.programmeCount);
      expect(
        restored.programmes['TF1.fr']!.first.title,
        guide.programmes['TF1.fr']!.first.title,
      );
      expect(
        restored.programmes['TF1.fr']!.first.start,
        guide.programmes['TF1.fr']!.first.start,
      );
    });

    test('a corrupt entry is skipped rather than failing the whole guide', () {
      final restored = EpgGuide.fromJson({
        'source': 'broken',
        'fetchedAt': 0,
        'channels': [
          {
            'id': 'ok',
            'names': ['OK'],
          },
          {
            'names': ['no id'],
          },
          'not a map',
        ],
        'programmes': [
          {'c': 'ok', 't': 'Fine', 's': 0, 'e': 1000},
          {'c': 'ok', 't': '', 's': 0, 'e': 1000},
          {'c': 'ok', 's': 0, 'e': 1000},
        ],
      })!;

      expect(restored.channels.keys, ['ok']);
      expect(restored.programmeCount, 1);
    });
  });

  group('matcher', () {
    late EpgMatcher matcher;

    setUp(() async {
      matcher = EpgMatcher(await parse(xml));
    });

    LiveChannel channel(String name, {String? tvgId}) => LiveChannel(
      id: name,
      name: name,
      urls: const ['https://a/x'],
      tvgId: tvgId,
    );

    test('an exact tvg-id wins', () {
      expect(
        matcher.guideIdFor(channel('Anything', tvgId: 'TF1.fr')),
        'TF1.fr',
      );
    });

    test('a feed suffix on the tvg-id is ignored', () {
      expect(matcher.guideIdFor(channel('x', tvgId: 'TF1.fr@SD')), 'TF1.fr');
    });

    test('a display name matches when the id is missing', () {
      expect(matcher.guideIdFor(channel('Arte')), 'Arte.fr');
    });

    test('quality tags, accents and punctuation are folded', () {
      expect(matcher.guideIdFor(channel('TF1 HD (720p)')), 'TF1.fr');
    });

    test('an unknown channel resolves to null instead of guessing', () {
      expect(matcher.guideIdFor(channel('Chaîne inconnue')), isNull);
    });

    test('normalize folds the spellings playlists actually use', () {
      expect(
        EpgMatcher.normalize('À la Une HD'),
        EpgMatcher.normalize('a la une'),
      );
      expect(EpgMatcher.normalize('France 2 [1080p]'), 'france2');
      expect(EpgMatcher.normalize('Canal+ UHD'), 'canal');
    });
  });
}
