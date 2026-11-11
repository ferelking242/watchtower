import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

Widget _host({VoidCallback? onTap, bool isVideo = true}) => MaterialApp(
  home: Scaffold(
    body: MbThumb(
      imageUrl: null,
      customBytes: null,
      itemType: isVideo ? ItemType.anime : ItemType.manga,
      badge: 'SRC',
      isVideo: isVideo,
      onTap: onTap,
    ),
  ),
);

void main() {
  testWidgets('tapping the poster fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onTap: () => taps++));

    await tester.tap(find.byType(MbThumb));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tapping the centered play glyph also opens the episode', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(onTap: () => taps++));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a poster without onTap stays inert', (tester) async {
    await tester.pumpWidget(_host());
    // No GestureDetector is inserted when the thumbnail is not tappable.
    expect(find.byType(GestureDetector), findsNothing);
  });
}
