import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/cli/watchtower_cli_catalog.dart';
import 'package:watchtower/models/manga.dart' show ItemType;

void main() {
  group('Watchtower CLI catalog discovery', () {
    test('the French source path overrides stale index language metadata', () {
      expect(
        watchtowerCliSourceLanguage({
          'lang': 'en',
        }, '/tmp/extensions/src/watch/fr/adkami.js'),
        'fr',
      );
    });

    test('a multi-language directory uses the indexed language', () {
      expect(
        watchtowerCliSourceLanguage(
          {'lang': 'en'},
          '/tmp/extensions/src/watch/multi/tv5monde.js',
          sourceCode: 'const watchtowerSources = [{"langs":["fr"]}];',
        ),
        'fr',
      );
    });

    test('source category discovery handles regular and NSFW paths', () {
      expect(
        watchtowerCliSourceTypeFromPath(
          '/tmp/extensions/src/watch/fr/adkami.js',
        ),
        'watch',
      );
      expect(
        watchtowerCliSourceTypeFromPath(
          r'C:\extensions\src\nsfw\watch\fr\example.js',
        ),
        'watch',
      );
      expect(
        watchtowerCliSourceTypeFromPath('/tmp/extensions/src/assets/icon.svg'),
        isNull,
      );
    });

    test(
      'an unindexed source with a constant URL is parsed without evaluation',
      () {
        const sourceCode = '''
const BASE_URL = "https://tropistream.fr";
const watchtowerSources = [{
  "name": "TropiStream",
  "langs": ["fr"],
  "ids": { "fr": 756891223 },
  "baseUrl": BASE_URL,
  "apiUrl": BASE_URL,
  "iconUrl": "https://tropistream.fr/tropi.png",
  "typeSource": "single",
  "version": "3.0.2"
}];
class DefaultExtension {}
''';

        final metadata = watchtowerCliMetadataForUnindexedSource(
          relativePath: 'src/watch/fr/tropistream.js',
          sourceCode: sourceCode,
          type: 'watch',
          language: 'fr',
        );

        expect(metadata['id'], 756891223);
        expect(metadata['name'], 'TropiStream');
        expect(metadata['lang'], 'fr');
        expect(metadata['baseUrl'], 'https://tropistream.fr');
        expect(metadata['apiUrl'], 'https://tropistream.fr');
        expect(metadata['itemType'], ItemType.anime.index);
        expect(metadata['version'], '3.0.2');
      },
    );
  });
}
