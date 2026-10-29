import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/router/back_navigation.dart';

/// Builds a router with three top-level pages that are reached with `go()`,
/// mirroring how the dock and the overflow menu navigate.
GoRouter _router({String initial = '/WatchtowerHome'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/WatchtowerHome',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('settings')),
      ),
      GoRoute(
        path: '/downloadQueue',
        builder: (_, _) => const Scaffold(body: Text('queue')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('onboarding')),
      ),
    ],
  );
}

void main() {
  group('BackHistory', () {
    test('leaves the app from the default tab', () {
      final h = BackHistory()..record('/settings')..record('/WatchtowerHome');
      expect(h.backTarget('/WatchtowerHome', '/WatchtowerHome'), isNull);
    });

    test('returns to the previous tab from a go()-reached page', () {
      final h = BackHistory()..record('/WatchtowerHome')..record('/settings');
      expect(h.backTarget('/settings', '/WatchtowerHome'), '/WatchtowerHome');
    });

    test('falls back to the default tab without history', () {
      expect(
        BackHistory().backTarget('/downloadQueue', '/WatchtowerHome'),
        '/WatchtowerHome',
      );
    });

    test('does not ping-pong after returning to the previous tab', () {
      final h = BackHistory()..record('/WatchtowerHome')..record('/settings');
      expect(h.backTarget('/settings', '/WatchtowerHome'), '/WatchtowerHome');
      // The router.go() that follows is observed as a pop and pops the stack.
      h.record('/WatchtowerHome');
      expect(h.entries, ['/WatchtowerHome']);
      expect(h.backTarget('/WatchtowerHome', '/WatchtowerHome'), isNull);
    });

    test('keeps distinct history for three tabs', () {
      final h = BackHistory()
        ..record('/WatchtowerHome')
        ..record('/settings')
        ..record('/downloadQueue');
      expect(h.backTarget('/downloadQueue', '/WatchtowerHome'), '/settings');
    });
  });

  testWidgets('back from a go()-reached page returns to the previous tab', (
    tester,
  ) async {
    final router = _router();
    final dispatcher = WatchtowerBackDispatcher(
      router: () => router,
      defaultLocation: () => '/WatchtowerHome',
    );
    addTearDown(dispatcher.detach);

    await tester.pumpWidget(
      MaterialApp.router(
        backButtonDispatcher: dispatcher,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
      ),
    );

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    final handled = await dispatcher.didPopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('back from the default tab is left to the platform', (
    tester,
  ) async {
    final router = _router();
    final dispatcher = WatchtowerBackDispatcher(
      router: () => router,
      defaultLocation: () => '/WatchtowerHome',
    );
    addTearDown(dispatcher.detach);

    await tester.pumpWidget(
      MaterialApp.router(
        backButtonDispatcher: dispatcher,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(await dispatcher.didPopRoute(), isFalse);
  });

  testWidgets('back pops a pushed page before using the fallback', (
    tester,
  ) async {
    final router = _router();
    final dispatcher = WatchtowerBackDispatcher(
      router: () => router,
      defaultLocation: () => '/WatchtowerHome',
    );
    addTearDown(dispatcher.detach);

    await tester.pumpWidget(
      MaterialApp.router(
        backButtonDispatcher: dispatcher,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
      ),
    );

    router.go('/settings');
    await tester.pumpAndSettle();
    router.push('/downloadQueue');
    await tester.pumpAndSettle();
    expect(find.text('queue'), findsOneWidget);

    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    // Now the settings page has nothing to pop: the fallback takes over.
    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('onboarding is a one-way gate', (tester) async {
    final router = _router(initial: '/onboarding');
    final dispatcher = WatchtowerBackDispatcher(
      router: () => router,
      defaultLocation: () => '/WatchtowerHome',
    );
    addTearDown(dispatcher.detach);

    await tester.pumpWidget(
      MaterialApp.router(
        backButtonDispatcher: dispatcher,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(await dispatcher.didPopRoute(), isFalse);
  });
}
