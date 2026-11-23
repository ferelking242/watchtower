import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/browse/marketplace_screen.dart';
import 'package:watchtower/modules/browse/widgets/marketplace_live_section.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';

/// The Live tab inside the real Marketplace screen.
///
/// [MarketplaceLiveSection] is tested on its own, but the wiring is where a tab
/// can go wrong: an off-by-one in the icon/label lists, a tab index that still
/// matches catalogue entries, or a body branch that never renders. The screen
/// reaches the network and Isar in `initState`, and both fail in the test
/// harness, so this also pins down that the Live tab still renders when the
/// catalogue itself is unreachable.
void main() {
  /// The screen keeps a repeating banner timer and a live catalogue refresh, so
  /// `pumpAndSettle` never settles. Bounded pumps are enough to reach a frame
  /// where the tab body is built.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Widget wrap() => ProviderScope(
    overrides: [
      // The real screen reads this from Isar, which the harness does not open.
      showNSFWStateProvider.overrideWithValue(false),
      liveProvidersProvider.overrideWith(_EmptyProviders.new),
      liveCatalogProvider.overrideWith(
        (ref) async => const <LiveProviderCatalogEntry>[],
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MarketplaceScreen(),
    ),
  );

  testWidgets('the tab bar exposes a Live tab that opens its own section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await settle(tester);

    // The tab bar is a horizontal list, so the last tab is not built until it
    // is scrolled into view.
    final liveTab = find.text('Live');
    await tester.dragUntilVisible(
      liveTab,
      find.byType(ListView).first,
      const Offset(-200, 0),
    );
    await settle(tester);
    expect(liveTab, findsOneWidget);

    await tester.tap(liveTab);
    await settle(tester);

    expect(find.byType(MarketplaceLiveSection), findsOneWidget);
  });

  testWidgets('the Live tab never lists catalogue extensions', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await settle(tester);
    final liveTab = find.text('Live');
    await tester.dragUntilVisible(
      liveTab,
      find.byType(ListView).first,
      const Offset(-200, 0),
    );
    await settle(tester);
    await tester.tap(liveTab);
    await settle(tester);

    // The catalogue-wide empty state belongs to the content tabs; the Live tab
    // renders its own section instead.
    expect(find.byType(MarketplaceLiveSection), findsOneWidget);
    expect(find.text('No extension available'), findsNothing);
  });
}

class _EmptyProviders extends LiveProvidersNotifier {
  @override
  List<LiveProvider> build() => const [];
}
