import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('header shows the broken back + filter icons and no divider', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        SharedSearchHeader(
          controller: controller,
          hint: 'Rechercher…',
          activeFilterCount: 2,
          onBack: () {},
          onFilter: () {},
          onSubmit: (_) {},
          onChanged: (_) {},
          onClear: () {},
        ),
      ),
    );

    expect(find.byIcon(Broken.arrow_left), findsOneWidget);
    expect(find.byIcon(Broken.filter), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
    expect(find.text('2'), findsOneWidget);
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
}
