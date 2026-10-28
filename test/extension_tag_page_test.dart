import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';

void main() {
  List<MManga> tagItems() => List.generate(
    6,
    (index) => MManga(
      name: 'Tag $index',
      link: 'https://example.test/tag/$index',
      imageUrl: 'https://example.test/tag/$index.jpg',
      collectionId: 'search_tag_$index',
    ),
  );

  Future<void> pumpScreen(WidgetTester tester, {String? seeAllPage}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TmdbMoviesListScreen.extension(
            title: 'Tags',
            source: Source(name: 'Test', itemType: ItemType.manga),
            sectionId: 'tags',
            initialExtensionItems: tagItems(),
            cardStyle: 'tag',
            seeAllPage: seeAllPage,
          ),
        ),
      ),
    );
    // A fixed number of frames instead of pumpAndSettle: the shimmer
    // placeholders animate indefinitely, so settling would never finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a tag see-all page lays its covers out two per row', (
    tester,
  ) async {
    await pumpScreen(tester, seeAllPage: 'tags');

    expect(find.byType(TagCard), findsNWidgets(6));
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    // Two per row regardless of width — the point is that the covers stay
    // large, so this must not follow the poster grid's column count.
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('without the hint the tag cards keep the compact poster grid', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(TagCard), findsNWidgets(6));
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    // The rail presentation follows the poster grid's column count (3 at
    // 400px); only the see-all page overrides it to two large columns.
    expect(delegate.crossAxisCount, 3);
  });
}
