import 'dart:async';

import 'package:flixquest/services/home_widget_deep_link.dart';
import 'package:flixquest/services/home_widget_navigation_service.dart';
import 'package:flixquest/services/in_app_messaging_service.dart';
import 'package:flixquest/services/media_link_navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const source = (language: 'en', useProxy: false, proxy: '');
const channel = MethodChannel('dev.beamlak.flixquest/media_links');

Widget app() => MaterialApp(
      navigatorKey: InAppMessagingService.navigatorKey,
      home: const Scaffold(body: Text('Home')),
    );

Route<void> page(String label) => MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Text(label)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    HomeWidgetNavigationService.configure(source: () => source);
  });

  testWidgets(
      'cold launch waits for full data and survives a delayed navigator',
      (tester) async {
    final ready = Completer<Route<void>>();
    HomeWidgetTarget? received;
    HomeWidgetNavigationService.configure(
      source: () => source,
      prepare: (target, settings) {
        received = target;
        expectSync(settings, source);
        return ready.future;
      },
    );
    final uri = HomeWidgetDeepLink.episode(
      seriesId: 1396,
      seasonNumber: 4,
      episodeNumber: 13,
      seriesName: 'Breaking Bad',
      posterPath: '/poster.jpg',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expectSync(call.method, 'drainLinks');
      return [uri.toString()];
    });
    var initialized = false;
    final initialization =
        MediaLinkNavigationService.initialize().then((_) => initialized = true);
    await tester.pump();
    expect(initialized, isFalse);
    final episode = received as HomeWidgetEpisodeTarget;
    expect(episode.seriesId, 1396);
    expect(episode.seasonNumber, 4);
    expect(episode.episodeNumber, 13);
    expect(episode.seriesName, 'Breaking Bad');
    expect(episode.posterPath, '/poster.jpg');
    ready.complete(page('Episode with full data'));
    await initialization;
    // The first readiness frame can occur before the MaterialApp exists.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Episode with full data'), findsOneWidget);
  });

  testWidgets('warm taps keep the current page until ready; latest tap wins',
      (tester) async {
    final first = Completer<Route<void>>();
    final second = Completer<Route<void>>();
    var count = 0;
    HomeWidgetNavigationService.configure(
      source: () => source,
      prepare: (_, __) => ++count == 1 ? first.future : second.future,
    );
    await tester.pumpWidget(app());
    final a =
        HomeWidgetNavigationService.handle(HomeWidgetDeepLink.movie(id: 1));
    final b = HomeWidgetNavigationService.handle(HomeWidgetDeepLink.tv(id: 2));
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    second.complete(page('Series'));
    await b;
    await tester.pumpAndSettle();
    first.complete(page('Old movie'));
    await a;
    await tester.pumpAndSettle();
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Old movie'), findsNothing);
    await HomeWidgetNavigationService.handle(HomeWidgetDeepLink.home);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a repeated tap while loading still opens its destination',
      (tester) async {
    final ready = Completer<Route<void>>();
    HomeWidgetNavigationService.configure(
      source: () => source,
      prepare: (_, __) => ready.future,
    );
    await tester.pumpWidget(app());
    final uri = HomeWidgetDeepLink.movie(id: 3);
    final first = HomeWidgetNavigationService.handle(uri);
    final second = HomeWidgetNavigationService.handle(uri);
    ready.complete(page('Movie'));
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(find.text('Movie'), findsOneWidget);
    InAppMessagingService.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
