import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/catalog_shelf.dart';
import 'package:watchtower/modules/browse/catalog_category_page.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';

import 'catalog_taxonomy_test.dart' show FakeEntry;

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

CatalogShelfSpec _spec({int minEntries = 3}) => CatalogShelfSpec(
  id: 'test_shelf',
  title: (_) => 'Test shelf',
  minEntries: minEntries,
);

List<FakeEntry> _entries(int count) => [
  for (var i = 0; i < count; i++)
    FakeEntry(id: i, name: 'Extension number $i', itemType: 0),
];

Widget _card(BuildContext context, entry) => CatalogCard(
  entry: entry,
  tags: const ['read'],
  status: CatalogCardStatus.available,
  onTap: () {},
  onInstall: () {},
);

void main() {
  group('CatalogShelfGrid', () {
    testWidgets('lays out two columns and two rows on a phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(CatalogShelfGrid(entries: _entries(8), cardBuilder: _card)),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(grid.scrollDirection, Axis.horizontal);

      // The block is exactly two rows tall, so a second row is visible.
      expect(
        tester.getSize(find.byType(CatalogShelfGrid)).height,
        CatalogCardMetrics.shelfHeight,
      );
    });

    testWidgets('keeps two columns on a wide screen without stretching cards', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(CatalogShelfGrid(entries: _entries(8), cardBuilder: _card)),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      // Still a two-row grid; the extra width shows more columns rather than
      // wider cards.
      expect(delegate.crossAxisCount, 2);
      expect(
        delegate.mainAxisExtent,
        lessThanOrEqualTo(CatalogCardMetrics.maxCardWidth),
      );
      expect(
        delegate.mainAxisExtent,
        greaterThanOrEqualTo(CatalogCardMetrics.minCardWidth),
      );
    });

    testWidgets('renders nothing for an empty shelf', (tester) async {
      await tester.pumpWidget(
        _host(CatalogShelfGrid(entries: const [], cardBuilder: _card)),
      );
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('a long name is truncated instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final long = FakeEntry(
        id: 1,
        name:
            'An extremely long extension name that cannot possibly fit '
            'inside a single catalogue card without being clipped',
        itemType: 0,
      );

      await tester.pumpWidget(
        _host(CatalogShelfGrid(entries: [long], cardBuilder: _card)),
      );

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(long.name));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 2);
    });

    testWidgets('the horizontal grid does not fight a vertical scroll parent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          ListView(
            children: [
              const SizedBox(height: 400),
              CatalogShelfGrid(entries: _entries(8), cardBuilder: _card),
            ],
          ),
        ),
      );

      // A vertical drag must scroll the page, not be swallowed by the grid.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CatalogShelfHeader', () {
    testWidgets('offers see all when a callback is given', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          CatalogShelfHeader(
            spec: _spec(),
            count: 12,
            onSeeAll: () => tapped++,
          ),
        ),
      );

      expect(find.text('Test shelf'), findsOneWidget);
      await tester.tap(find.text('See all'));
      expect(tapped, 1);
    });

    testWidgets('omits see all when there is no callback', (tester) async {
      await tester.pumpWidget(
        _host(CatalogShelfHeader(spec: _spec(), count: 3)),
      );
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('explains the curated order', (tester) async {
      await tester.pumpWidget(
        _host(CatalogShelfHeader(spec: _spec(), count: 3)),
      );
      expect(
        find.text('Featured first, then most recently added'),
        findsOneWidget,
      );
    });
  });

  group('CatalogCategoryPage', () {
    testWidgets('lists every entry of the shelf it was opened from', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CatalogCategoryPage(
            spec: _spec(minEntries: 1),
            entries: _entries(7),
            cardBuilder: _card,
          ),
        ),
      );

      expect(find.text('Test shelf'), findsOneWidget);
      expect(find.byType(CatalogCard), findsWidgets);
      // The count is shown in the app bar.
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('shows the empty state rather than a blank page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CatalogCategoryPage(
            spec: _spec(minEntries: 0),
            entries: const [],
            cardBuilder: _card,
          ),
        ),
      );
      expect(
        find.text('No extension matches this selection yet.'),
        findsOneWidget,
      );
    });
  });

  group('CatalogCard', () {
    testWidgets('shows an install action for an available entry', (
      tester,
    ) async {
      var installed = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 200,
            height: 200,
            child: CatalogCard(
              entry: const FakeEntry(id: 1, name: 'Source', itemType: 0),
              tags: const ['read', 'manga'],
              status: CatalogCardStatus.available,
              onTap: () {},
              onInstall: () => installed++,
            ),
          ),
        ),
      );

      expect(find.text('Source'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(installed, 1);
    });

    testWidgets('shows a busy indicator instead of the action while busy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            height: 200,
            child: CatalogCard(
              entry: FakeEntry(id: 1, name: 'Source', itemType: 0),
              tags: [],
              status: CatalogCardStatus.available,
              busy: true,
              onTap: _noop,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('caps the tag row at two chips', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            height: 200,
            child: CatalogCard(
              entry: FakeEntry(id: 1, name: 'Source', itemType: 0),
              tags: ['read', 'manga', 'action', 'romance'],
              status: CatalogCardStatus.available,
              onTap: _noop,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Manga'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Romance'), findsNothing);
    });

    testWidgets('prefers the featured badge over the tag row', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            height: 200,
            child: CatalogCard(
              entry: FakeEntry(id: 1, name: 'Source', itemType: 0),
              tags: ['read', 'featured', 'manga'],
              status: CatalogCardStatus.available,
              onTap: _noop,
            ),
          ),
        ),
      );

      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Manga'), findsNothing);
    });
  });
}

void _noop() {}
