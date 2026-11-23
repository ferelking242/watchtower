import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/browse/marketplace_tabs.dart';

/// Guards the tab bar's single source of truth.
///
/// The icons and the captions used to be two hand-maintained lists; adding a
/// tab to one and not the other threw a `RangeError` while building the bar,
/// which no test caught because the screen is not pumped in the suite. Every
/// property below is now derived from [MarketplaceTab], so these assertions are
/// cheap insurance that the derivation stays total.
void main() {
  testWidgets('every tab has a distinct icon and a non-empty caption', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final icons = MarketplaceTab.values.map((tab) => tab.icon).toList();
    expect(icons.toSet(), hasLength(MarketplaceTab.values.length));

    final labels = MarketplaceTab.values.map((tab) => tab.label(l10n)).toList();
    expect(labels.every((label) => label.trim().isNotEmpty), isTrue);
    expect(labels.toSet(), hasLength(MarketplaceTab.values.length));
  });

  test('the Live tab is the last one, after every content tab', () {
    expect(marketplaceLiveTabIndex, MarketplaceTab.values.length - 1);
    expect(MarketplaceTab.values[marketplaceLiveTabIndex], MarketplaceTab.live);
  });

  test('the content tabs keep their historical positions', () {
    // Existing code and deep links select tabs by index, so the order is part
    // of the contract: inserting Live in the middle would silently reroute
    // every one of those call sites.
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.forYou), 0);
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.watch), 1);
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.manga), 2);
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.music), 3);
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.games), 4);
    expect(MarketplaceTab.values.indexOf(MarketplaceTab.novels), 5);
  });
}
