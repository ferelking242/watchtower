import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/media/content_cards.dart';

void main() {
  testWidgets('PosterCard renders an item without rating or description', (
    tester,
  ) async {
    const item = ContentItem(key: 'k', title: 'Sans note');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterCard(item: item, onTap: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sans note'), findsOneWidget);
  });

  testWidgets('PosterCard renders a rating pill only when a rating exists', (
    tester,
  ) async {
    const item = ContentItem(key: 'k', title: 'Noté', rating: 7.5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterCard(item: item, onTap: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('7.5'), findsOneWidget);
  });
}
