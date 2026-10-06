import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/cli/watchtower_cli_plugins.dart';

void main() {
  group('loadWatchtowerCliPluginCatalog', () {
    late Directory root;

    Future<File> writeIndex(Object value) async {
      final index = Directory('${root.path}${Platform.pathSeparator}index');
      await index.create(recursive: true);
      final file = File('${index.path}${Platform.pathSeparator}plugins.json');
      await file.writeAsString(jsonEncode(value));
      return file;
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('watchtower-cli-plugin-');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('loads a valid catalogue and preserves plugin metadata', () async {
      await writeIndex({
        '_lastUpdated': '2026-10-05',
        'plugins': [
          {
            'id': 'com.example.audio',
            'name': 'Example Audio',
            'version': '1.0.0',
            'author': 'Example',
            'description': 'A test plugin',
            'category': 'music-audio-source',
            'runtime': 'javascript',
            'permissions': ['network'],
            'requirements': [
              {'id': 'ffmpeg', 'optional': true},
            ],
            'networkAccess': {
              'allowedDomains': ['example.org'],
            },
            'userConfig': {
              'fields': [
                {'key': 'quality', 'type': 'select'},
              ],
            },
          },
        ],
      });

      final catalog = await loadWatchtowerCliPluginCatalog(root.path);

      expect(catalog.lastUpdated, '2026-10-05');
      expect(catalog.plugins, hasLength(1));
      expect(catalog.plugins.single['id'], 'com.example.audio');
      expect(catalog.failures, isEmpty);
      expect(catalog.toJson()['valid'], isTrue);
    });

    test(
      'reports missing fields, invalid metadata, and duplicate ids',
      () async {
        await writeIndex({
          'plugins': [
            {
              'id': 'com.example.duplicate',
              'name': 'First',
              'version': '1.0.0',
              'author': 'Example',
              'description': 'First entry',
              'category': 'utility',
              'runtime': 'javascript',
              'permissions': 'network',
            },
            {
              'id': 'com.example.duplicate',
              'name': 'Second',
              'version': '1.0.0',
              'author': 'Example',
              'description': 'Second entry',
              'category': 'utility',
              'runtime': 'javascript',
            },
          ],
        });

        final catalog = await loadWatchtowerCliPluginCatalog(root.path);

        expect(catalog.failures, hasLength(2));
        expect(
          catalog.failures.map((failure) => failure['error']),
          contains('duplicate plugin id'),
        );
        expect(
          catalog.failures.map((failure) => failure['field']),
          contains('permissions'),
        );
        expect(catalog.toJson()['valid'], isFalse);
      },
    );

    test('rejects missing and malformed index files', () async {
      await expectLater(
        loadWatchtowerCliPluginCatalog(root.path),
        throwsArgumentError,
      );

      await writeIndex({'items': []});
      await expectLater(
        loadWatchtowerCliPluginCatalog(root.path),
        throwsFormatException,
      );
    });
  });
}
