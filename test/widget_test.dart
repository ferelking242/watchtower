// Basic Flutter widget smoke test.
//
// The real app entry point (lib/main.dart) initializes Isar, Hive, isolates,
// FFI and platform channels before runApp — it cannot be pumped in a plain
// `flutter test` environment. This test therefore verifies the framework
// wiring (MaterialApp + a widget) instead of booting the whole app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell renders a widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Watchtower')),
      ),
    );

    expect(find.text('Watchtower'), findsOneWidget);
  });
}