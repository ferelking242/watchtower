import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/onboarding/onboarding_screen.dart';

/// Phone, tablet, and a wide desktop window.
const _sizes = <Size>[Size(360, 800), Size(800, 1200), Size(1440, 900)];

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final size in _sizes) {
    testWidgets('showcase lays out without overflowing at $size', (
      tester,
    ) async {
      await _pumpAt(tester, size);

      expect(find.text('Watchtower'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Run past a window rotation: the lane window swaps lanes mid-flight.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('slogan page lays out without overflowing on a phone', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(360, 800));

    // Swipe to the slogan page.
    // The lanes animate forever, so `pumpAndSettle` would never return.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tout.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  _motionTests();

  testWidgets('slogan page lays out without overflowing on a desktop', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1440, 900));

    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tout.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Regression: the showcase must not animate for a user who asked the platform
/// to reduce motion. This is also the cheapest path for a slow phone.
void _motionTests() {
  testWidgets('reduce-motion stops the showcase animation', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The MediaQuery must sit *below* MaterialApp: MaterialApp inserts its own,
    // which would otherwise hide the flag from the page.
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // A running lane animation registers a transient frame callback; with
    // motion disabled none may remain, which is what keeps a still screen from
    // burning a frame budget forever.
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('Watchtower'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the showcase animates when motion is allowed', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Control: the same screen does drive frames when nothing asked it to stop.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
