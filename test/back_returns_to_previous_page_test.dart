import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/router/back_navigation.dart';

/// Mirrors the real shell: the `ShellRoute` builder wraps its child in
/// `PopScope(canPop: false)` exactly like `MainScreen`, and the dock/menu
/// destinations are siblings reached with `go()`. Back must retrace the visit
/// order, not jump to the default tab.
GoRouter _shellRouter({String initial = '/WatchtowerHome'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final target =
                WatchtowerBackDispatcher.active?.backTargetFor(
                  state.uri.toString(),
                ) ??
                '/WatchtowerHome';
            context.go(target);
          },
          child: Scaffold(body: child),
        ),
        routes: [
          GoRoute(
            path: '/WatchtowerHome',
            builder: (_, _) => const Text('home'),
          ),
          GoRoute(path: '/browse', builder: (_, _) => const Text('browse')),
          GoRoute(
            path: '/statistics',
            builder: (_, _) => const Text('statistics'),
          ),
          GoRoute(
            path: '/downloadQueue',
            builder: (_, _) => const Text('queue'),
          ),
        ],
      ),
    ],
  );
}

Future<WatchtowerBackDispatcher> _pump(WidgetTester tester, GoRouter router) async {
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
  return dispatcher;
}

void main() {
  testWidgets('back returns to the page the user came from, not the hub', (
    tester,
  ) async {
    final router = _shellRouter();
    await _pump(tester, router);

    // Hub → Browse → Download queue, all with go() from the dock/menu.
    router.go('/browse');
    await tester.pumpAndSettle();
    router.go('/downloadQueue');
    await tester.pumpAndSettle();
    expect(find.text('queue'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('browse'),
      findsOneWidget,
      reason: 'back from the queue must return to Browse, not the hub',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('back from a page opened from statistics returns to statistics', (
    tester,
  ) async {
    final router = _shellRouter();
    await _pump(tester, router);

    router.go('/statistics');
    await tester.pumpAndSettle();
    router.go('/downloadQueue');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('statistics'), findsOneWidget);
  });

  testWidgets('back on the default tab has no target, so the app exits', (
    tester,
  ) async {
    final router = _shellRouter();
    final dispatcher = await _pump(tester, router);

    // With nothing before the default tab there is no page to return to; the
    // shell's PopScope is what turns that into `SystemNavigator.pop()`.
    expect(dispatcher.backTargetFor('/WatchtowerHome'), isNull);
  });
}
