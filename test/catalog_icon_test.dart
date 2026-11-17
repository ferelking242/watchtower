import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';
import 'package:flutter/material.dart';

/// The catalogue publishes one logo per plugin, and every catalogue card
/// renders it through [CatalogIcon]. These tests pin the contract that broke in
/// production: a card without a published logo must still render (initials
/// fallback), and one with a logo must request it.
void main() {
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
