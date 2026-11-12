import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

double _widthFactor(WidgetTester tester) {
  final box = tester.widget<FractionallySizedBox>(
    find.byType(FractionallySizedBox),
  );
  return box.widthFactor!;
}

Widget _host(
  double? value, {
  bool paused = false,
  bool failed = false,
  bool active = true,
  double height = 4,
}) => MaterialApp(
  home: Scaffold(
    body: MbGradientProgressBar(
      value: value,
      paused: paused,
      failed: failed,
      active: active,
      height: height,
    ),
  ),
);

void main() {
  testWidgets('eases a small target move instead of snapping', (tester) async {
    await tester.pumpWidget(_host(0.2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.2, 0.01));

    await tester.pumpWidget(_host(0.25));
    await tester.pump(const Duration(milliseconds: 80));
    final mid = _widthFactor(tester);
    expect(mid, greaterThan(0.2));
    expect(mid, lessThan(0.25));

    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.25, 0.01));
  });

  testWidgets('a resume jump lands immediately, no left→right replay', (
    tester,
  ) async {
    // Counters read 0, then the resumed transfer reports the on-disk offset.
    await tester.pumpWidget(_host(0.0));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(_host(0.44));
    // One frame: the bar must already sit at the resume point, not race there.
    await tester.pump();
    expect(_widthFactor(tester), closeTo(0.44, 0.001));
  });

  testWidgets('a backwards move snaps instead of easing down', (tester) async {
    await tester.pumpWidget(_host(0.6));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(_host(0.3));
    await tester.pump();
    expect(_widthFactor(tester), closeTo(0.3, 0.001));
  });

  testWidgets('sub-pixel counter noise does not move the bar', (tester) async {
    await tester.pumpWidget(_host(0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_widthFactor(tester), closeTo(0.5, 0.0001));

    await tester.pumpWidget(_host(0.501));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_widthFactor(tester), closeTo(0.5, 0.0001));
  });

  testWidgets('pulse band travels while the transfer is active', (
    tester,
  ) async {
    await tester.pumpWidget(_host(0.6));
    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<Positioned>(find.byType(Positioned)).left!;
    await tester.pump(const Duration(milliseconds: 300));
    final second = tester.widget<Positioned>(find.byType(Positioned)).left!;
    expect(second, isNot(equals(first)));
  });

  testWidgets('the fill ripples (wave painter) while active', (tester) async {
    await tester.pumpWidget(_host(0.6));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: find.byType(MbGradientProgressBar),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('a paused row keeps the pulse + wave on the saved position', (
    tester,
  ) async {
    // Pausing must not freeze the bar: the saved position is the resume marker,
    // so the pulse travels from the left up to it and the fill ripples.
    await tester.pumpWidget(_host(0.4, paused: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Positioned), findsOneWidget);

    final first = tester.widget<Positioned>(find.byType(Positioned)).left!;
    await tester.pump(const Duration(milliseconds: 300));
    final second = tester.widget<Positioned>(find.byType(Positioned)).left!;
    expect(second, isNot(equals(first)));
  });

  testWidgets('a failed row stays static (no pulse)', (tester) async {
    await tester.pumpWidget(_host(0.4, failed: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('an inactive row does not animate its bar', (tester) async {
    await tester.pumpWidget(_host(0.4, active: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('indeterminate value keeps the sweeping indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets('supports the thicker MovieBox-style queue bar', (tester) async {
    await tester.pumpWidget(_host(0.4, height: 5));
    final bar = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(MbGradientProgressBar),
        matching: find.byType(SizedBox),
      ),
    );

    expect(bar.height, 5);
  });

  testWidgets('queue thumbnail uses MovieBox landscape proportions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MbThumb(
            imageUrl: null,
            customBytes: null,
            itemType: ItemType.anime,
            badge: 'TV',
            isVideo: true,
          ),
        ),
      ),
    );
    // The badge is padded with its own SizedBox, so several are nested under
    // MbThumb: the first descendant is the ClipRRect's frame.
    final thumbnail = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(MbThumb),
            matching: find.byType(SizedBox),
          )
          .first,
    );

    expect(thumbnail.width, 106);
    expect(thumbnail.height, 64);
  });

  testWidgets('media thumbnail can use its larger landscape size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MbThumb(
            imageUrl: null,
            customBytes: null,
            itemType: ItemType.anime,
            badge: 'TV',
            isVideo: true,
            width: 120,
            height: 68,
          ),
        ),
      ),
    );
    // The badge is padded with its own SizedBox, so several are nested under
    // MbThumb: the first descendant is the ClipRRect's frame.
    final thumbnail = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(MbThumb),
            matching: find.byType(SizedBox),
          )
          .first,
    );

    expect(thumbnail.width, 120);
    expect(thumbnail.height, 68);
  });

  testWidgets('grouped row action is larger and has no overflow menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MbRowActions(
            isComplete: false,
            hasFailed: false,
            isPaused: false,
            onPauseResume: () {},
            onRetry: () {},
            onOpen: () {},
          ),
        ),
      ),
    );

    expect(find.byType(PopupMenuButton), findsNothing);
    final button = tester.widget<Container>(
      find.descendant(
        of: find.byType(MbRowActions),
        matching: find.byType(Container),
      ),
    );
    expect(button.constraints?.maxWidth, 30);
    expect(button.constraints?.maxHeight, 30);
  });
}
