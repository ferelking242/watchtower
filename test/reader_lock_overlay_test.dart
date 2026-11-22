import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/manga/reader/widgets/reader_lock_overlay.dart';

void main() {
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required VoidCallback onUnlock,
    String? tooltip,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            // Stand-in for the page view: it counts taps, and the lock must
            // make sure none of them ever arrive.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => fail('a locked screen must not forward taps'),
                child: const SizedBox.expand(),
              ),
            ),
            ReaderLockOverlay(onUnlock: onUnlock, tooltip: tooltip),
          ],
        ),
      ),
    );
  }

  testWidgets('a tap on the locked screen turns nothing', (tester) async {
    var unlocks = 0;
    await pumpOverlay(tester, onUnlock: () => unlocks++);

    await tester.tapAt(const Offset(40, 80));
    // Let the double-tap recognizer's timer expire, otherwise the test ends
    // with a pending timer (the barrier claims double taps too).
    await tester.pump(const Duration(milliseconds: 400));

    expect(unlocks, 0);
  });

  testWidgets('a swipe on the locked screen turns nothing', (tester) async {
    var unlocks = 0;
    await pumpOverlay(tester, onUnlock: () => unlocks++);

    await tester.dragFrom(const Offset(20, 300), const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 400));

    expect(unlocks, 0);
  });

  testWidgets('the floating padlock unlocks', (tester) async {
    var unlocks = 0;
    await pumpOverlay(tester, onUnlock: () => unlocks++);

    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pump();

    expect(unlocks, 1);
  });

  testWidgets('the padlock carries the unlock tooltip when given', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      onUnlock: () {},
      tooltip: 'Déverrouiller l\u2019écran',
    );

    expect(find.byTooltip('Déverrouiller l\u2019écran'), findsOneWidget);
  });
}
