import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('header shows the chevron back + mic, no inline filter/X', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        SharedSearchHeader(
          controller: controller,
          hint: 'Rechercher…',
          onMic: () {},
          onBack: () {},
          onSubmit: (_) {},
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Broken.arrow_left_2), findsOneWidget);
    expect(find.byIcon(Broken.microphone), findsOneWidget);
    // The filter icon and the clear "X" now live outside the field, so the
    // header itself must not render them.
    expect(find.byIcon(Broken.filter), findsNothing);
    expect(find.byIcon(Broken.close_circle), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('handleSearchBack clears the query before leaving', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'naruto');
    addTearDown(controller.dispose);
    var cleared = 0;
    var exited = 0;

    var handled = handleSearchBack(
      controller: controller,
      onClearQuery: () {
        cleared++;
        controller.clear();
      },
      onExit: () => exited++,
    );
    expect(handled, isTrue);
    expect(cleared, 1);
    expect(exited, 0);

    handleSearchBack(
      controller: controller,
      onClearQuery: () => cleared++,
      onExit: () => exited++,
    );
    expect(cleared, 1);
    expect(exited, 1);
  });

  testWidgets('empty state renders the crying-cat Lottie', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SharedSearchEmptyState(
          recentSearches: const ['naruto'],
          hotSearches: const [],
          hotTabs: const [],
          onSearch: (_) {},
          onClearRecents: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('naruto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header defaults to the white used by dark surfaces', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        SharedSearchHeader(
          controller: controller,
          hint: 'Rechercher…',
          onBack: () {},
          onSubmit: (_) {},
          onChanged: (_) {},
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, Colors.white);
    expect(find.byIcon(Broken.microphone), findsNothing);
  });

  testWidgets('header honours the caller colours and a custom leading', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SharedSearchHeader(
            controller: controller,
            hint: 'Rechercher…',
            onBack: () {},
            onSubmit: (_) {},
            onChanged: (_) {},
            foregroundColor: const Color(0xFF123456),
            outlineColor: const Color(0xFFABCDEF),
            leading: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, const Color(0xFF123456));
    // The custom leading replaces the default chevron.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Broken.arrow_left_2), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
