import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/reader/services/page_navigation_service.dart';

/// Drives a *real* [ScrollablePositionedList] so the tests exercise the same
/// path a hardware volume key takes: service -> ScrollOffsetController -> list.
Widget _list({
  required ItemScrollController item,
  required ScrollOffsetController offset,
  required ItemPositionsListener positions,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ScrollablePositionedList.separated(
          scrollDirection: Axis.vertical,
          itemCount: 40,
          itemScrollController: item,
          scrollOffsetController: offset,
          itemPositionsListener: positions,
          itemBuilder: (_, i) => SizedBox(height: 600, child: Text('page $i')),
          separatorBuilder: (_, _) => const SizedBox(height: 6),
        ),
      ),
    );

int _firstIndex(ItemPositionsListener positions) =>
    positions.itemPositions.value.first.index;

void main() {
  late ItemScrollController item;
  late ScrollOffsetController offset;
  late ItemPositionsListener positions;
  late Size viewport;

  PageNavigationService service() => PageNavigationService(
        itemScrollController: item,
        scrollOffsetController: offset,
        extendedController: ExtendedPageController(),
        viewportSize: () => viewport,
        scrollAxis: () => Axis.vertical,
      );

  /// Animations only advance while frames are pumped; a single long pump is
  /// not enough for a driven scroll activity to report its new position.
  Future<void> settleFrames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      _list(item: item, offset: offset, positions: positions),
    );
    await settleFrames(tester);
  }

  setUp(() {
    item = ItemScrollController();
    offset = ScrollOffsetController();
    positions = ItemPositionsListener.create();
    viewport = const Size(400, 800);
  });

  testWidgets('nextPage scrolls the continuous list forward',
      (tester) async {
    await pumpList(tester);
    final before = _firstIndex(positions);
    service().nextPage(
      readerMode: ReaderMode.webtoon,
      currentIndex: 0,
      maxPages: 40,
      animate: true,
    );
    await settleFrames(tester);
    expect(_firstIndex(positions), greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('previousPage scrolls the continuous list backward',
      (tester) async {
    await pumpList(tester);
    // Move down first so there is room to scroll back up.
    item.jumpTo(index: 5);
    await settleFrames(tester);
    final before = _firstIndex(positions);
    service().previousPage(
      readerMode: ReaderMode.webtoon,
      currentIndex: 6,
      animate: true,
    );
    await settleFrames(tester);
    expect(_firstIndex(positions), lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page step with transitions disabled still scrolls',
      (tester) async {
    await pumpList(tester);
    final before = _firstIndex(positions);
    service().nextPage(
      readerMode: ReaderMode.webtoon,
      currentIndex: 0,
      maxPages: 40,
      animate: false,
    );
    await settleFrames(tester);
    expect(tester.takeException(), isNull);
    expect(_firstIndex(positions), greaterThan(before));
  });
}
