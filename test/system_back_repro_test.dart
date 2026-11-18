import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/router/back_navigation.dart';

/// Faithful reproduction of the real shell: a ShellRoute whose builder renders
/// the app shell with `PopScope(canPop: false, onPopInvoked: go(home))`, the
/// same shape as `MainScreen`. The inner pages are reached with `go()` from the
/// dock/menu, exactly like `/settings` and `/statistics`.
GoRouter _shellRouter({String initial = '/WatchtowerHome'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final current = state.uri.toString();
            if (current != '/WatchtowerHome') {
              context.go('/WatchtowerHome');
            }
          },
          child: Scaffold(body: child),
        ),
        routes: [
          GoRoute(
            path: '/WatchtowerHome',
            builder: (_, _) => const Text('home'),
          ),
        ],
      ),
      // Settings and statistics live OUTSIDE the shell, exactly like the real
      // `_genericRoute(name: "settings")` / `_genericRoute(name: "statistics")`.
      GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
      GoRoute(path: '/statistics', builder: (_, _) => const Text('statistics')),
    ],
  );
}

void main() {
  testWidgets(
    'on Android 13+ the shell keeps handling back on a go()-reached page',
    (tester) async {
      // The engine only forwards back presses to the framework while
      // `SystemNavigator.setFrameworkHandlesBack(true)` is in effect. The value
      // comes from MaterialApp's NavigationNotification: when the top page is
      // the only route (settings/statistics live outside the shell), the
      // default handler flips it to false and the OS closes the app.
      final backHandled = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            backHandled.add(call.arguments as bool);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final router = _shellRouter();
      final dispatcher = WatchtowerBackDispatcher(
        router: () => router,
        defaultLocation: () => '/WatchtowerHome',
      );
      addTearDown(dispatcher.detach);

      await tester.pumpWidget(
        MaterialApp.router(
          backButtonDispatcher: dispatcher,
          onNavigationNotification: onWatchtowerNavigationNotification,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          routeInformationProvider: router.routeInformationProvider,
        ),
      );
      await tester.pumpAndSettle();

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);

      // After settling on /settings the engine must still forward back presses
      // to the framework, otherwise the OS closes the app.
      expect(
        backHandled.isNotEmpty && backHandled.last,
        isTrue,
        reason:
            'setFrameworkHandlesBack(false) on /settings makes Android close '
            'the app instead of running WatchtowerBackDispatcher',
      );
    },
  );

  testWidgets('system back on a go()-reached shell page must not close the app', (
    tester,
  ) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final router = _shellRouter();
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

    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    platformCalls.clear();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      platformCalls.where((m) => m == 'SystemNavigator.pop'),
      isEmpty,
      reason: 'back from /settings must navigate, not close the app',
    );
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('system back on /statistics must not close the app', (
    tester,
  ) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final router = _shellRouter();
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

    router.go('/statistics');
    await tester.pumpAndSettle();
    expect(find.text('statistics'), findsOneWidget);

    platformCalls.clear();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      platformCalls.where((m) => m == 'SystemNavigator.pop'),
      isEmpty,
      reason: 'back from /statistics must navigate, not close the app',
    );
    expect(find.text('home'), findsOneWidget);
  });
}
