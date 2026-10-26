import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/modules/media/catalog_filter_sheet.dart';
import 'package:watchtower/modules/media/overlay_filter_menu.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

/// Renders [child] on a solid background and returns the raw RGBA pixels.
Future<ByteData> _capture(
  WidgetTester tester,
  GlobalKey key, {
  required Size size,
}) async {
  late ByteData data;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
  });
  return data;
}

int _px(ByteData data, int width, int x, int y) =>
    data.getUint32((y * width + x) * 4);

void main() {
  testWidgets('overlay caret is visible against a solid app bar', (
    tester,
  ) async {
    const int width = 400;
    const int height = 800;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              actions: [
                AdaptiveOverlayMenuButton(
                  menuWidth: 300,
                  trigger: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Broken.filter),
                  ),
                  contentBuilder: (close) =>
                      const SizedBox(height: 200, child: Text('menu')),
                ),
                const SizedBox(width: 40),
              ],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Broken.filter));
    await tester.pumpAndSettle();

    final caretFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.size == const Size(14, 7),
    );
    expect(caretFinder, findsOneWidget);
    final caretBox = tester.renderObject<RenderBox>(caretFinder);
    final caretTopLeft = caretBox.localToGlobal(Offset.zero);

    final data = await _capture(tester, key, size: const Size(400, 800));

    // The caret points down/up toward the trigger; sample along its slanted
    // edges. Before the fix these pixels were identical to the bar background
    // because the caret only re-painted the same translucent fill.
    final background = _px(data, width, 10, 10);
    var distinct = 0;
    for (var dy = 0; dy < 7; dy++) {
      for (var dx = 0; dx < 14; dx++) {
        final x = caretTopLeft.dx.round() + dx;
        final y = caretTopLeft.dy.round() + dy;
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        if (_px(data, width, x, y) != background) distinct++;
      }
    }
    expect(
      distinct,
      greaterThan(6),
      reason: 'caret edges must contrast with the background',
    );
  });

  testWidgets('AdaptiveOverlayMenu renders popup items and reports selection', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AdaptiveOverlayMenu<int>(
                icon: const Icon(Broken.more_2),
                onSelected: (value) => selected = value,
                itemBuilder: (_) => [
                  const PopupMenuItem<int>(value: 1, child: Text('Premier')),
                  const PopupMenuDivider(),
                  const PopupMenuItem<int>(value: 2, child: Text('Second')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Broken.more_2));
    await tester.pumpAndSettle();

    expect(find.text('Premier'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(AdaptiveOverlayDivider), findsOneWidget);

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  testWidgets('ExtensionFilterOverlay toggles a checkbox filter in place', (
    tester,
  ) async {
    final filters = <dynamic>[
      CheckBoxFilter('genre', 'Aventure', 'adventure', 'CheckBox'),
      SelectFilter(
        'category',
        'Catégorie',
        0,
        [
          SelectFilterOption('Tout', '', 'SelectOption'),
          SelectFilterOption('Action', 'action', 'SelectOption'),
        ],
        'SelectFilter',
      ),
    ];
    List<dynamic>? applied;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AdaptiveOverlayMenuButton(
            menuWidth: 300,
            trigger: const Text('open'),
            contentBuilder: (close) => ExtensionFilterOverlay(
              filterList: filters,
              onChanged: (value) => applied = value,
              close: close,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aventure'));
    await tester.pumpAndSettle();
    expect((filters.first as CheckBoxFilter).state, isTrue);
    expect(applied, isNotNull);

    // Select filter drills into a sub-level then selects an option.
    await tester.tap(find.text('Catégorie'));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect((filters[1] as SelectFilter).state, 1);
    // Back at the root level after selecting.
    expect(find.text('Catégorie'), findsOneWidget);
  });

  testWidgets('CatalogFilterOverlay applies layout and reports state', (
    tester,
  ) async {
    final initial = CatalogFilterState();
    CatalogFilterState? applied;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AdaptiveOverlayMenuButton(
            menuWidth: 300,
            trigger: const Text('open'),
            contentBuilder: (close) => CatalogFilterOverlay(
              initial: initial,
              typeOptions: const [CatalogTypeOption('Film', 'movie')],
              sortOptions: const [CatalogSortOption('Populaire', 'popular')],
              genreOptions: const ['Action', 'Drame'],
              close: close,
              onChanged: (value) => applied = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Affichage'), findsOneWidget);

    await tester.tap(find.text('Affichage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.layout, CatalogLayout.list);
  });
}
