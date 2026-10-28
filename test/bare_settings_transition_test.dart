import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/settings/settings_subpage_route.dart';

void main() {
  test('keeps Bare Browser timing, curve and covered routes', () {
    expect(bareSettingsDuration, const Duration(milliseconds: 280));
    expect(bareSettingsBehindShift, 0.24);
    expect(bareSettingsBehindAlpha, 0.7);
    expect(bareSettingsCurve.transform(0), 0);
    expect(bareSettingsCurve.transform(1), 1);
    expect(
      bareSettingsRoutes,
      containsAll(['settings', 'general', 'downloads', 'about']),
    );
    expect(bareSettingsRoutes, isNot(contains('Library')));
  });

  test('the settings subpage route uses the Bare duration', () {
    final route = settingsSubpageRoute<void>(const SizedBox());
    expect(route, isA<PageRouteBuilder<void>>());
    final pageRoute = route as PageRouteBuilder<void>;
    expect(pageRoute.transitionDuration, bareSettingsDuration);
    expect(pageRoute.reverseTransitionDuration, bareSettingsDuration);
  });

  Widget harness({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => bareSettingsTransitions(
          context,
          animation,
          secondaryAnimation,
          const SizedBox(key: Key('page'), width: 100, height: 100),
        ),
      ),
    );
  }

  testWidgets('a new page comes in from the right', (tester) async {
    await tester.pumpWidget(
      harness(
        animation: const AlwaysStoppedAnimation<double>(0),
        secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
      ),
    );
    final offScreen = tester.getTopLeft(find.byKey(const Key('page'))).dx;
    expect(offScreen, greaterThan(0));

    await tester.pumpWidget(
      harness(
        animation: const AlwaysStoppedAnimation<double>(1),
        secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
      ),
    );
    final atRest = tester.getTopLeft(find.byKey(const Key('page'))).dx;
    expect(atRest, 0);
  });

  testWidgets('a covered page moves left and fades', (tester) async {
    await tester.pumpWidget(
      harness(
        animation: const AlwaysStoppedAnimation<double>(1),
        secondaryAnimation: const AlwaysStoppedAnimation<double>(1),
      ),
    );

    final behind = tester.getTopLeft(find.byKey(const Key('page'))).dx;
    expect(behind, lessThan(0));

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const Key('page')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, closeTo(bareSettingsBehindAlpha, 0.001));
  });

  testWidgets('the search bar rises away and fades as a page slides in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const BareSearchBarTransition(
                  child: SizedBox(key: Key('bar'), width: 100, height: 40),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(),
                    ),
                  ),
                  child: const Text('push'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    double barTop() => tester.getTopLeft(find.byKey(const Key('bar'))).dy;
    double barOpacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(const Key('bar')),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    // Nothing on top: the bar sits where it is, fully opaque.
    expect(barTop(), 0);
    expect(barOpacity(), 1);

    // Mid-slide the bar has already left: moved up and faded out.
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(barTop(), lessThan(0));
    expect(barOpacity(), lessThan(0.5));

    // Let the transition finish so no timers are left pending.
    await tester.pumpAndSettle();
  });
}
