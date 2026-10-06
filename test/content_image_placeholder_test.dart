import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/media/content_cards.dart';

void main() {
  testWidgets('shows a styled placeholder when a card image is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: ContentImage(url: null),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('content-image-placeholder')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
