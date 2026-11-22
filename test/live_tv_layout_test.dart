import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/live_tv/data/live_favorites_store.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_providers.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_guide_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_settings_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_tv_screen.dart';
import 'package:watchtower/modules/live_tv/widgets/broken_menu_icon.dart';

/// Layout of the Live TV screens on the narrowest phones still in use.
///
/// Every header row here mixes a fixed icon, a flexible label and a trailing
/// action, which is exactly the shape that silently overflows once a channel
/// name or a localised label grows. A `RenderFlex overflowed` is reported as a
/// test failure, so these run as plain assertions with no golden files.
void main() {
  const channels = [
    LiveChannel(
      id: 'a',
      name: 'France 24',
      urls: ['https://a/1'],
      country: 'France',
      tvgId: 'F24.fr',
      language: 'fra',
    ),
    LiveChannel(
      id: 'b',
      name: 'Eurosport 1 Extra Long Channel Name For A Narrow Phone',
      urls: ['https://a/2'],
      country: 'France',
    ),
  ];

  EpgGuide guide() {
    // Anchored on `now`: an hour-aligned programme has already ended when
    // the suite runs past :40.
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 20));
    return EpgGuide(
      channels: const {
        'F24.fr': EpgChannel(id: 'F24.fr', names: ['France 24']),
      },
      programmes: {
        'F24.fr': [
          EpgProgramme(
            channelId: 'F24.fr',
            title: 'Le journal international de la nuit',
            start: start,
            stop: start.add(const Duration(hours: 2)),
            category: 'Info',
            description:
                'Une description assez longue pour forcer plusieurs lignes '
                'dans le panneau de détail du guide.',
          ),
        ],
      },
      source: 'epgshare01',
      fetchedAt: now,
    );
  }

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      allLiveChannelsProvider.overrideWith((ref) async => channels),
      epgProvider.overrideWith(() => _StubEpg(guide())),
      liveFavoritesProvider.overrideWith(_StubFavorites.new),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  for (final size in const [Size(320, 568), Size(360, 640), Size(411, 891)]) {
    testWidgets('no overflow on the home tabs at ${size.width.toInt()}dp', (
      tester,
    ) async {
      sizeTo(tester, size);
      await tester.pumpWidget(wrap(const LiveTvScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Accueil');

      for (final tab in ['Guide', 'Favoris', 'Réglages']) {
        await tester.tap(find.byType(BrokenMenuIcon));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  testWidgets('the guide detail panel fits a 320dp phone', (tester) async {
    sizeTo(tester, const Size(320, 568));
    await tester.pumpWidget(wrap(const LiveGuideScreen()));
    await tester.pumpAndSettle();

    final block = find.text('Le journal international de la nuit').first;
    await tester.ensureVisible(block);
    await tester.pumpAndSettle();
    await tester.tap(block);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('EN DIRECT'), findsOneWidget);
  });

  testWidgets('the settings list fits a 320dp phone', (tester) async {
    sizeTo(tester, const Size(320, 568));
    await tester.pumpWidget(wrap(const LiveSettingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _StubEpg extends EpgNotifier {
  _StubEpg(this._guide);

  final EpgGuide _guide;

  @override
  EpgState build() => EpgState(guide: _guide, sourceUrl: 'test://guide');

  @override
  Future<void> load(EpgSource source) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> clear() async {}
}

class _StubFavorites extends LiveFavoritesNotifier {
  @override
  Set<String> build() => const {'a'};
}
