import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/settings/advanced/providers/ui_scale_provider.dart';
import 'package:watchtower/ui/widgets/desktop_shortcuts.dart';

GoRouter _router({String initial = '/WatchtowerHome'}) => GoRouter(
  initialLocation: initial,
  routes: [
    for (final r in DesktopShortcuts.sectionRoutes)
      GoRoute(path: r, builder: (_, _) => Scaffold(body: Text('page $r'))),
    GoRoute(
      path: '/globalSearch',
      builder: (_, _) => const Scaffold(body: Text('page /globalSearch')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: Text('page /settings')),
    ),
    GoRoute(
      path: '/fieldPage',
      builder: (_, _) => const Scaffold(body: TextField(autofocus: true)),
    ),
    GoRoute(
      path: '/animePlayerView',
      builder: (_, _) => const Scaffold(body: Text('player')),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            DesktopShortcuts(router: router, child: child!),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // The shortcuts must only be armed on keyboard platforms. The override is set
  // and cleared inside each test body because the binding checks that no
  // foundation debug variable was left changed when the body returns.
  const desktop = TargetPlatform.windows;

  testWidgets('number keys jump to the matching section', (tester) async {
    debugDefaultTargetPlatformOverride = desktop;
    final router = _router();
    await _pump(tester, router);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, DesktopShortcuts.sectionRoutes[2]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Ctrl+K opens the global search', (tester) async {
    debugDefaultTargetPlatformOverride = desktop;
    final router = _router();
    await _pump(tester, router);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/globalSearch');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a keypress inside a text field is not hijacked', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = desktop;
    final router = _router(initial: '/fieldPage');
    await _pump(tester, router);

    // The field has focus; typing a digit must land in the field and the router
    // must stay put.
    await tester.enterText(find.byType(TextField), '3');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/fieldPage');
    expect(find.text('3'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('is disabled on a touch platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final router = _router();
    await _pump(tester, router);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/WatchtowerHome');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a number key does not leave the full-screen player', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = desktop;
    final router = _router(initial: '/animePlayerView');
    await _pump(tester, router);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/animePlayerView');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Ctrl +/-/0 change the UI scale', (tester) async {
    debugDefaultTargetPlatformOverride = desktop;
    final router = _router();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              DesktopShortcuts(router: router, child: child!),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(uiScaleProvider), 1.0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(container.read(uiScaleProvider), greaterThan(1.0));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(container.read(uiScaleProvider), 1.0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(container.read(uiScaleProvider), greaterThan(1.0));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(container.read(uiScaleProvider), 1.0);

    debugDefaultTargetPlatformOverride = null;
  });
}
