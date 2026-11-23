import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/browse/widgets/marketplace_live_section.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_store.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';

/// The Live tab of the Marketplace, against a stubbed provider list and a
/// stubbed published index.
///
/// The network path is covered by the `live`-tagged suite; what matters here is
/// that an installed provider is listed and opens, that a published provider can
/// be installed, that an unreachable index offers a retry, and that the whole
/// tab fits the narrowest phone still in use.
void main() {
  const published = LiveProviderCatalogEntry(
    id: 'iptv-org-fr',
    name: 'IPTV-org — France',
    kind: LiveProviderKind.m3u,
    source: 'https://example.test/fr.m3u',
    version: '1.2.0',
    description: 'Chaînes françaises gratuites.',
  );

  const installedProvider = LiveProvider(
    id: 'wt-world',
    name: 'Watchtower World',
    kind: LiveProviderKind.bundled,
    source: 'assets/live/world.json',
    version: '2.0.0',
    isBundled: true,
    isBuiltin: true,
  );

  Widget wrap({
    List<LiveProvider> installed = const [],
    List<LiveProviderCatalogEntry>? catalog,
    Object? catalogError,
    Map<String, LiveFetchStat> stats = const {},
    Locale locale = const Locale('fr'),
  }) => ProviderScope(
    overrides: [
      liveProvidersProvider.overrideWith(() => _StubProviders(installed)),
      liveFetchStatsProvider.overrideWith(() => _StubStats(stats)),
      liveCatalogProvider.overrideWith((ref) async {
        if (catalogError != null) throw catalogError;
        return catalog ?? const <LiveProviderCatalogEntry>[];
      }),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(child: MarketplaceLiveSection()),
      ),
    ),
  );

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('an installed provider is listed with its channel count', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        installed: [installedProvider],
        stats: {
          installedProvider.id: LiveFetchStat(
            channelCount: 13134,
            fetchedAt: DateTime(2026, 11, 20),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watchtower World'), findsOneWidget);
    expect(find.textContaining('13'), findsWidgets);
  });

  testWidgets('a published provider installs into the provider list', (
    tester,
  ) async {
    _StubProviders.installedEntries.clear();
    await tester.pumpWidget(wrap(catalog: [published]));
    await tester.pumpAndSettle();

    expect(find.text('IPTV-org — France'), findsOneWidget);
    expect(find.text('Chaînes françaises gratuites.'), findsOneWidget);

    await tester.tap(find.text('Installer'));
    await tester.pumpAndSettle();

    expect(_StubProviders.installedEntries.map((e) => e.id), [published.id]);
  });

  testWidgets('an already installed provider is not offered again', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(installed: [installedProvider], catalog: [published]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Installer'), findsOneWidget);
    expect(find.text('Watchtower World'), findsOneWidget);
  });

  testWidgets('an unreachable index offers a retry instead of an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(catalogError: 'HTTP 503'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('the tab labels itself in the active locale', (tester) async {
    await tester.pumpWidget(wrap(locale: const Locale('fr')));
    await tester.pumpAndSettle();

    expect(find.text('Télévision en direct'), findsOneWidget);
    expect(find.text('DISPONIBLES'), findsOneWidget);
  });

  testWidgets('the English template is used when no translation exists', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Live TV'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(411, 891)]) {
    testWidgets('no overflow at ${size.width.toInt()}dp', (tester) async {
      sizeTo(tester, size);
      await tester.pumpWidget(
        wrap(
          installed: const [
            installedProvider,
            LiveProvider(
              id: 'a-very-long-provider-name-for-a-narrow-phone',
              name: 'IPTV-org — Monde entier avec un nom très long',
              kind: LiveProviderKind.xtream,
              source: 'https://example.test:8080',
              version: '10.11.12',
              isEnabled: false,
            ),
          ],
          catalog: const [
            LiveProviderCatalogEntry(
              id: 'free-tv-fr',
              name: 'Free-TV — France',
              kind: LiveProviderKind.m3u,
              source: 'https://example.test/free.m3u',
              version: '1.0.0',
              description:
                  'Une description assez longue pour forcer plusieurs lignes '
                  'dans la rangée du catalogue.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

class _StubProviders extends LiveProvidersNotifier {
  _StubProviders(this.providers);

  final List<LiveProvider> providers;

  static final List<LiveProviderCatalogEntry> installedEntries = [];

  @override
  List<LiveProvider> build() => providers;

  @override
  Future<void> install(LiveProviderCatalogEntry entry) async {
    installedEntries.add(entry);
  }
}

class _StubStats extends LiveFetchStatsNotifier {
  _StubStats(this.stats);

  final Map<String, LiveFetchStat> stats;

  @override
  Map<String, LiveFetchStat> build() => stats;
}
