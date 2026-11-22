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
import 'package:watchtower/modules/live_tv/screens/live_tv_screen.dart';
import 'package:watchtower/modules/live_tv/widgets/broken_menu_icon.dart';

/// Builds the Live TV shell for real.
///
/// The provider layer is unit-tested separately; what matters here is that the
/// shell renders, that the broken hamburger opens a drawer with the module's
/// sections, and that the home filters in memory rather than per keystroke.
void main() {
  const channels = [
    LiveChannel(
      id: 'a',
      name: 'France 24',
      urls: ['https://a/f24.m3u8'],
      group: 'France',
      country: 'France',
      tvgId: 'France24.fr',
    ),
    LiveChannel(
      id: 'b',
      name: 'Eurosport',
      urls: ['https://a/euro.m3u8'],
      group: 'France',
      country: 'France',
    ),
  ];

  /// A guide whose programme is live right now, so the "now" paths render.
  ///
  /// Anchored on `now`, not on the top of the hour: an hour-aligned
  /// programme has already ended when the suite runs past :40, which made
  /// these tests depend on the time of day.
  EpgGuide liveGuide() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 20));
    return EpgGuide(
      channels: const {
        'France24.fr': EpgChannel(
          id: 'France24.fr',
          names: ['France 24', 'France 24 HD'],
        ),
      },
      programmes: {
        'France24.fr': [
          EpgProgramme(
            channelId: 'France24.fr',
            title: 'Le journal',
            start: start,
            stop: start.add(const Duration(hours: 1)),
            category: 'Info',
            description: "L'actualité internationale.",
          ),
        ],
      },
      source: 'test',
      fetchedAt: now,
    );
  }

  Widget wrap(
    Widget child, {
    EpgGuide? guide,
    Set<String> favorites = const {},
  }) => ProviderScope(
    overrides: [
      allLiveChannelsProvider.overrideWith((ref) async => channels),
      if (guide != null)
        epgProvider.overrideWith(() => _StubEpg(guide))
      else
        epgProvider.overrideWith(() => _StubEpg(null)),
      liveFavoritesProvider.overrideWith(() => _StubFavorites(favorites)),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  testWidgets('the home lists every channel from the enabled providers', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pumpAndSettle();

    expect(find.text('France 24'), findsWidgets);
    expect(find.text('Eurosport'), findsWidgets);
    expect(find.text('Top Picks'), findsOneWidget);
  });

  testWidgets('the header carries the broken hamburger, not a stock icon', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(BrokenMenuIcon), findsOneWidget);
  });

  testWidgets('the hamburger opens a drawer with the module sections', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BrokenMenuIcon));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    for (final label in ['Accueil', 'Guide', 'Favoris', 'Réglages']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the drawer switches section and closes', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen(), guide: liveGuide()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BrokenMenuIcon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Fournisseurs'), findsOneWidget);
  });

  testWidgets('search narrows the list in memory', (tester) async {
    await tester.pumpWidget(wrap(const LiveTvScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'euro');
    await tester.pumpAndSettle();

    expect(find.text('Eurosport'), findsWidgets);
    expect(find.text('France 24'), findsNothing);
  });

  testWidgets('an empty catalogue shows the empty state, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allLiveChannelsProvider.overrideWith((ref) async => const []),
          epgProvider.overrideWith(() => _StubEpg(null)),
          liveFavoritesProvider.overrideWith(() => _StubFavorites(const {})),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LiveTvScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune chaîne'), findsOneWidget);
  });

  testWidgets('the home shows what is airing now when a guide is loaded', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LiveTvScreen(), guide: liveGuide()));
    await tester.pumpAndSettle();

    expect(find.text('Le journal'), findsWidgets);
  });

  testWidgets('favourites show only the starred channel', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LiveTvScreen(initialTab: LiveTab.favorites),
        guide: liveGuide(),
        favorites: const {'b'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eurosport'), findsOneWidget);
    expect(find.text('France 24'), findsNothing);
  });

  testWidgets('favourites without a star show the empty state', (tester) async {
    await tester.pumpWidget(
      wrap(const LiveTvScreen(initialTab: LiveTab.favorites)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun favori'), findsOneWidget);
  });

  group('guide', () {
    testWidgets('without a guide, it offers to download one', (tester) async {
      await tester.pumpWidget(wrap(const LiveGuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aucun guide'), findsOneWidget);
      expect(find.text('Télécharger le guide'), findsOneWidget);
    });

    testWidgets('it renders a row per matched channel with its programme', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const LiveGuideScreen(), guide: liveGuide()),
      );
      await tester.pumpAndSettle();

      // Only France 24 has a tvg-id present in the guide; Eurosport is
      // unmatched and must not produce a row.
      expect(find.text('1 chaînes'), findsOneWidget);
      expect(find.text('Le journal'), findsWidgets);
    });

    testWidgets('tapping a programme opens the detail panel', (tester) async {
      await tester.pumpWidget(
        wrap(const LiveGuideScreen(), guide: liveGuide()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Touchez un programme'), findsOneWidget);

      // The grid is wider than the viewport, so the block has to be brought
      // into view before it can receive the tap.
      final block = find.text('Le journal').first;
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      await tester.tap(block);
      await tester.pumpAndSettle();

      expect(find.textContaining('Touchez un programme'), findsNothing);
      expect(find.text('EN DIRECT'), findsOneWidget);
      expect(
        find.textContaining("L'actualité internationale."),
        findsOneWidget,
      );
    });
  });
}

class _StubEpg extends EpgNotifier {
  _StubEpg(this._guide);

  final EpgGuide? _guide;

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
  _StubFavorites(this._initial);

  final Set<String> _initial;

  @override
  Set<String> build() => _initial;

  @override
  Future<void> toggle(String channelId) async {
    final next = Set<String>.from(state);
    if (!next.remove(channelId)) next.add(channelId);
    state = next;
  }
}
