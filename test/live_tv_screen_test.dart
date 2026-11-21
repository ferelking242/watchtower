import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_channels_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_tv_screen.dart';

/// Builds the Live TV screens for real.
///
/// The provider layer is unit-tested; this covers what those tests cannot:
/// that the screen actually renders, that a provider row exposes its toggle,
/// and that the channel browser filters in memory rather than per keystroke.
void main() {
  late LiveProvider provider;

  setUp(() {
    provider = const LiveProvider(
      id: 'iptv-pro',
      name: 'IPTV Pro',
      kind: LiveProviderKind.m3u,
      source: 'https://example.test/list.m3u',
      version: '1.2.0',
      isBuiltin: true,
    );
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [liveProvidersProvider.overrideWith(_StubProviders.new)],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  testWidgets('the provider list renders every provider', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pump();

    expect(find.text('IPTV Pro'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('a provider row shows its version', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pump();

    expect(find.textContaining('v1.2.0'), findsOneWidget);
  });

  testWidgets('toggling a provider calls the notifier', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pump();

    final toggle = tester.widget<Switch>(find.byType(Switch).first);
    expect(toggle.value, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(_StubProviders.toggledIds, contains('iptv-pro'));
  });

  testWidgets('the add button opens the provider form', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pump();

    await tester.tap(find.byIcon(Broken.add));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un fournisseur'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Ajouter'), findsOneWidget);
  });

  testWidgets('the form rejects a source that is not an http url', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pump();
    await tester.tap(find.byIcon(Broken.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Ma liste');
    await tester.enterText(find.byType(TextFormField).last, 'ftp://nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();

    expect(find.textContaining('http://'), findsOneWidget);
  });

  testWidgets('the channel browser filters in memory as the user types', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveChannelsProvider.overrideWith((ref, id) async => const [
            LiveChannel(
              id: 'a',
              name: 'France 24',
              urls: ['https://a/f24.m3u8'],
              group: 'News',
            ),
            LiveChannel(
              id: 'b',
              name: 'Eurosport',
              urls: ['https://a/euro.m3u8'],
              group: 'Sport',
            ),
          ]),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LiveChannelsScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('France 24'), findsOneWidget);
    expect(find.text('Eurosport'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'euro');
    await tester.pumpAndSettle();

    expect(find.text('Eurosport'), findsOneWidget);
    expect(find.text('France 24'), findsNothing);
  });

  testWidgets('the group chips narrow the list to one group', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveChannelsProvider.overrideWith((ref, id) async => const [
            LiveChannel(
              id: 'a',
              name: 'France 24',
              urls: ['https://a/f24.m3u8'],
              group: 'News',
            ),
            LiveChannel(
              id: 'b',
              name: 'Eurosport',
              urls: ['https://a/euro.m3u8'],
              group: 'Sport',
            ),
          ]),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LiveChannelsScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sport'));
    await tester.pumpAndSettle();

    expect(find.text('Eurosport'), findsOneWidget);
    expect(find.text('France 24'), findsNothing);
  });

  testWidgets('an empty playlist shows the empty state, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveChannelsProvider.overrideWith((ref, id) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LiveChannelsScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('aucune chaîne'), findsOneWidget);
  });
}

class _StubProviders extends LiveProvidersNotifier {
  static final List<String> toggledIds = [];

  @override
  List<LiveProvider> build() {
    toggledIds.clear();
    return [
      const LiveProvider(
        id: 'iptv-pro',
        name: 'IPTV Pro',
        kind: LiveProviderKind.m3u,
        source: 'https://example.test/list.m3u',
        version: '1.2.0',
        isBuiltin: true,
      ),
    ];
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    toggledIds.add(id);
    state = [
      for (final provider in state)
        provider.id == id ? provider.copyWith(isEnabled: enabled) : provider,
    ];
  }

  @override
  Future<void> remove(String id) async {}
}
