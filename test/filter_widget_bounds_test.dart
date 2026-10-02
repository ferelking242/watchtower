import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';

void main() {
  testWidgets('stale selection indices do not crash filter rendering', (
    tester,
  ) async {
    final options = List<dynamic>.generate(
      59,
      (index) => SelectFilterOption(
        'Option $index',
        '$index',
        'SelectOption',
      ),
    );
    final filters = <dynamic>[
      SelectFilter('category', 'Category', 62, options, 'SelectFilter'),
      SortFilter(
        'sort',
        'Sort',
        SortState(62, true, 'SortState'),
        options,
        'SortFilter',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterWidget(
            filterList: filters,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Option 58'), findsOneWidget);
    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}