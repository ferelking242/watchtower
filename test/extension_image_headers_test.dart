import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/media/extension_image_headers.dart';

void main() {
  testWidgets('cards resolve the headers installed by the enclosing scope', (
    tester,
  ) async {
    Map<String, String>? seen;
    await tester.pumpWidget(
      ExtensionImageHeaders(
        headers: const {
          'Referer': 'https://www.harimanga.co.uk/',
          'User-Agent': 'WT-test',
        },
        child: Builder(
          builder: (context) {
            seen = ExtensionImageHeaders.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    // This is what makes every nested ContentImage send the Referer a
    // hotlink-protected CDN requires; without the scope they fall back to
    // headerless requests and the CDN answers 403.
    expect(seen, {
      'Referer': 'https://www.harimanga.co.uk/',
      'User-Agent': 'WT-test',
    });
  });

  testWidgets('a screen without the scope resolves no headers', (
    tester,
  ) async {
    Map<String, String>? seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = ExtensionImageHeaders.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(seen, isNull);
  });

  testWidgets('an empty header map is reported as absent', (tester) async {
    Map<String, String>? seen;
    await tester.pumpWidget(
      ExtensionImageHeaders(
        headers: const {},
        child: Builder(
          builder: (context) {
            seen = ExtensionImageHeaders.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen, isNull);
  });
}
