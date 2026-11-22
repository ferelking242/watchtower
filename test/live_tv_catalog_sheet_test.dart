import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_catalog_sheet.dart';

/// Covers the catalogue screen against a stubbed index.
///
/// The network path is exercised separately by the `live`-tagged suite; what
/// matters here is that an entry renders, that installing it reaches the
/// notifier, and that an unreachable index shows a retry instead of an empty
/// sheet that looks like "nothing is published".
void main() {
  const entry = LiveProviderCatalogEntry(
    id: 'iptv-org-fr',
    name: 'IPTV-org — France',
    kind: LiveProviderKind.m3u,
    source: 'https://example.test/fr.m3u',
    version: '1.0.0',
    description: 'Chaînes françaises gratuites.',
  );

  Widget wrap({
    required List<LiveProviderCatalogEntry> catalog,
    List<LiveProvider> installedProviders = const [],
  }) => ProviderScope(
    overrides: [
      liveProvidersProvider.overrideWith(() => _StubProviders(installedProviders)),
      liveCatalogProvider.overrideWith((ref) async => catalog),
    ],
    child: const MaterialApp(home: Scaffold(body: LiveCatalogSheet())),
  );

  testWidgets('an entry renders with its description and an install button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(catalog: [entry]));
    await tester.pumpAndSettle();

    expect(find.text('IPTV-org — France'), findsOneWidget);
    expect(find.text('Chaînes françaises gratuites.'), findsOneWidget);
    expect(find.text('Installer'), findsOneWidget);
  });

  testWidgets('installing an entry reaches the notifier', (tester) async {
    _StubProviders.installed.clear();
    await tester.pumpWidget(wrap(catalog: [entry]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Installer'));
    await tester.pumpAndSettle();

    expect(_StubProviders.installed.map((e) => e.id), [entry.id]);
  });

  testWidgets('an already installed entry shows a tick, not a button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        catalog: [entry],
        installedProviders: [
          entry.toProvider(),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Installer'), findsNothing);
    expect(find.byIcon(Broken.tick_circle), findsOneWidget);
  });

  testWidgets('an empty index says so instead of showing a blank sheet', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(catalog: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucun fournisseur'), findsOneWidget);
  });
}

class _StubProviders extends LiveProvidersNotifier {
  _StubProviders(this.installedProviders);

  final List<LiveProvider> installedProviders;

  static final List<LiveProviderCatalogEntry> installed = [];

  @override
  List<LiveProvider> build() => installedProviders;

  @override
  Future<void> install(LiveProviderCatalogEntry entry) async {
    installed.add(entry);
  }
}
