import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/repositories.dart';
import 'package:flutter/material.dart';

/// The plugin catalogue publishes one logo per plugin. These tests pin the two
/// contract that broke in production: every known repository must carry a
/// distinct icon URL, and a repository without one must still render.
void main() {
  group('MetadataPluginRepository iconUrl', () {
    test('is optional and survives a round-trip through JSON', () {
      final withoutIcon = MetadataPluginRepository.fromJson({
        'name': 'spotube-plugin-spotify',
        'owner': 'ferelking242',
        'description': 'Spotify metadata',
        'repoUrl': 'https://github.com/ferelking242/spotube-plugin-spotify',
        'topics': <String>['spotube-plugin'],
      });
      expect(withoutIcon.iconUrl, isNull);

      final withIcon = MetadataPluginRepository.fromJson({
        'name': 'spotube-plugin-deezer',
        'owner': 'ferelking242',
        'description': 'Deezer metadata',
        'repoUrl': 'https://github.com/ferelking242/spotube-plugin-deezer',
        'topics': <String>['spotube-plugin'],
        'iconUrl': 'https://example.test/deezer.png',
      });
      expect(withIcon.iconUrl, 'https://example.test/deezer.png');
      expect(withIcon.toJson()['iconUrl'], 'https://example.test/deezer.png');
    });

    test('a repository without an icon still serialises', () {
      final repo = MetadataPluginRepository(
        name: 'legacy-plugin',
        owner: 'ferelking242',
        description: 'No icon published',
        repoUrl: 'https://github.com/ferelking242/legacy-plugin',
        topics: const <String>['spotube-plugin'],
      );
      expect(repo.toJson()['iconUrl'], isNull);
    });
  });

  group('known plugin repositories', () {
    test('every known repository declares a distinct icon', () async {
      final notifier = MetadataPluginRepositoriesNotifier();
      final page = await notifier.fetch(0, 50);
      final repos = page.items;

      expect(repos, isNotEmpty);

      final urls = <String>[];
      for (final repo in repos) {
        expect(
          repo.iconUrl,
          isNotNull,
          reason: '${repo.name} must publish its own logo',
        );
        expect(repo.iconUrl, startsWith('http'));
        urls.add(repo.iconUrl!);
      }

      // Two plugins sharing a logo is exactly the bug that made Deezer display
      // the Spotify mark; distinct URLs are the cheap guard against a relapse.
      expect(urls.toSet().length, urls.length);
    });

    test('icons are served from the extensions catalogue', () async {
      final notifier = MetadataPluginRepositoriesNotifier();
      final page = await notifier.fetch(0, 50);
      for (final repo in page.items) {
        expect(
          repo.iconUrl,
          contains('watchtower-extensions'),
          reason: '${repo.name} must not depend on a third-party host',
        );
      }
    });
  });

  group('CatalogIcon', () {
    testWidgets('renders initials when no icon URL is published', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogIcon(
              name: 'Deezer Audio',
              iconUrl: null,
              size: 48,
              tint: Colors.purple,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('DA'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('requests the network image when an icon URL exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogIcon(
              name: 'Spotify',
              iconUrl: 'https://example.test/spotify.png',
              size: 48,
              tint: Colors.green,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        'https://example.test/spotify.png',
      );
    });

    testWidgets('falls back to initials when the image fails to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogIcon(
              name: 'Flac',
              iconUrl: 'https://example.test/missing.png',
              size: 48,
              tint: Colors.teal,
            ),
          ),
        ),
      );

      // The test HTTP client fails every request, so the error builder runs.
      await tester.pump();
      expect(find.text('F'), findsOneWidget);
    });
  });
}
