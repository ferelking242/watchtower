import 'package:flutter/widgets.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';

/// Position of the Live tab in the Marketplace tab bar.
///
/// The screen keeps its selected tab as an `int`, so this is the single place
/// that maps the enum back to an index; a test asserts the two agree.
int get marketplaceLiveTabIndex =>
    MarketplaceTab.values.indexOf(MarketplaceTab.live);

/// The Marketplace tabs, in display order.
///
/// The screen used to keep two parallel lists — one of icons, one of captions —
/// which meant adding a tab in one place and forgetting the other produced a
/// `RangeError` at runtime instead of a compile error. Everything is derived
/// from this single list, so the two can no longer drift apart.
enum MarketplaceTab {
  forYou(Broken.category),
  watch(Broken.video),
  manga(Broken.bookmark),
  music(Broken.musicnote),
  games(Broken.game),
  novels(Broken.book_1),

  /// Live TV providers. They are published in their own index and are not
  /// catalogue entries, so this tab renders its own section.
  live(Broken.radio);

  const MarketplaceTab(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    forYou => l10n.catalog_tab_for_you,
    watch => l10n.catalog_tab_watch,
    manga => l10n.catalog_tab_manga,
    music => l10n.catalog_tab_music,
    games => l10n.catalog_tab_games,
    novels => l10n.catalog_tab_novels,
    live => l10n.catalog_tab_live,
  };
}
