import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/catalog_entry.dart';

/// Which catalogue a shelf draws from.
enum CatalogMedium { watch, read, music, game }

/// How a shelf orders its entries.
///
/// Every order is total and stable, so a shelf renders identically on every
/// rebuild and two entries can never swap places on a scroll.
enum CatalogSort {
  /// The documented stand-in for "popular": explicit curation first, then the
  /// most recently added entries.
  ///
  /// The catalogue publishes no usage statistic, so this is deliberately *not*
  /// called popularity and no download count, view count or rating is invented.
  /// It is only ever described to the user as "mis en avant puis récemment
  /// ajouté" (see [CatalogShelfSpec.orderNote]).
  curated,

  /// Most recently added first, entries without a date last.
  newest,

  /// A→Z, case-insensitive.
  alphabetical,
}

/// A named group of catalogue entries: a title, a rule, and an order.
class CatalogShelfSpec {
  /// Stable identifier, used for widget keys and for the "see all" route.
  final String id;

  /// Localised title.
  final String Function(AppLocalizations l10n) title;

  /// Catalogue the shelf draws from, or null for any catalogue.
  final CatalogMedium? medium;

  /// Every one of these tags must be present.
  final List<String> all;

  /// At least one of these tags must be present.
  final List<String> any;

  /// None of these tags may be present.
  final List<String> none;

  /// Restrict to entries added within [kCatalogNewWindow] of the newest
  /// catalogue date. Entries without a date never match.
  final bool newOnly;

  /// Whether adult entries are eligible. Off by default, so every shelf is
  /// safe unless it deliberately asks for adult content.
  final bool includeNsfw;

  final CatalogSort sort;

  /// Below this many entries the shelf is not shown at all, rather than
  /// rendered as a near-empty row.
  final int minEntries;

  const CatalogShelfSpec({
    required this.id,
    required this.title,
    this.medium,
    this.all = const [],
    this.any = const [],
    this.none = const [],
    this.newOnly = false,
    this.includeNsfw = false,
    this.sort = CatalogSort.curated,
    this.minEntries = kShelfMinEntries,
  });

  /// Explains the ordering to the user when it is not obvious from the title.
  ///
  /// Only [CatalogSort.curated] needs one: "newest" and "alphabetical" are
  /// self-describing.
  String? orderNote(AppLocalizations l10n) =>
      sort == CatalogSort.curated ? l10n.catalog_shelf_order_curated : null;

  /// True when [tags] satisfy every condition of this shelf.
  ///
  /// [allowNsfw] is the user's opt-in. An adult entry is eligible only when the
  /// user opted in *and* this shelf declares itself adult-facing, so a shelf
  /// that never asks for adult content cannot leak one in whatever the user
  /// chose, and an adult shelf stays hidden until the user opts in.
  bool matches(
    List<String> tags, {
    required bool isNew,
    bool isNsfw = false,
    bool allowNsfw = false,
  }) {
    if (isNsfw && !(includeNsfw && allowNsfw)) return false;
    if (newOnly && !isNew) return false;
    for (final tag in all) {
      if (!tags.contains(tag)) return false;
    }
    if (any.isNotEmpty && !any.any(tags.contains)) return false;
    for (final tag in none) {
      if (tags.contains(tag)) return false;
    }
    return true;
  }

  /// Comparator implementing [sort] over entries whose tags are already known.
  int compare(
    CatalogEntryView a,
    CatalogEntryView b,
    List<String> tagsA,
    List<String> tagsB,
  ) {
    switch (sort) {
      case CatalogSort.newest:
        final aDate = a.addedAt;
        final bDate = b.addedAt;
        if (aDate == null && bDate != null) return 1;
        if (aDate != null && bDate == null) return -1;
        if (aDate != null && bDate != null) {
          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) return byDate;
        }
      case CatalogSort.curated:
        final aFeatured = tagsA.contains('featured');
        final bFeatured = tagsB.contains('featured');
        if (aFeatured != bFeatured) return aFeatured ? -1 : 1;
        final aDate = a.addedAt;
        final bDate = b.addedAt;
        if (aDate != null && bDate != null) {
          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) return byDate;
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }
      case CatalogSort.alphabetical:
        break;
    }
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    // Name is the final tie-break for every order, and the whole order for
    // `alphabetical`, so the result is a total order.
    if (byName != 0) return byName;
    return a.id.compareTo(b.id);
  }
}

/// Minimum number of entries a shelf needs before it is worth rendering.
const int kShelfMinEntries = 3;

/// The shelves each tab is built from.
///
/// The list is data, not code: adding a shelf is adding an entry here, and the
/// same shelf renders identically in every tab that includes it.
class CatalogShelves {
  CatalogShelves._();

  static String _watchPopular(AppLocalizations l) =>
      l.catalog_shelf_watch_popular;
  static String _readPopular(AppLocalizations l) =>
      l.catalog_shelf_read_popular;

  /// Shelf used to order the hero banner. Declared once so the banner and the
  /// "featured" shelf can never drift apart.
  static final CatalogShelfSpec featured = CatalogShelfSpec(
    id: 'featured_order',
    title: (l) => l.catalog_shelf_featured,
    all: const ['featured'],
  );

  /// Shelves that only ever hold adult sources.
  ///
  /// They replace the hard-coded "Midnight World" / "Midnight Library" rows: the
  /// grouping is the same, but it is now declared as data and only rendered
  /// once the user has opted in. `includeNsfw` is what makes them adult-facing,
  /// so nothing else can drift into them.
  static final List<CatalogShelfSpec> adult = [
    CatalogShelfSpec(
      id: 'adult_watch',
      title: (l) => l.catalog_shelf_adult_watch,
      medium: CatalogMedium.watch,
      all: const ['watch'],
      includeNsfw: true,
    ),
    CatalogShelfSpec(
      id: 'adult_read',
      title: (l) => l.catalog_shelf_adult_read,
      medium: CatalogMedium.read,
      all: const ['read'],
      includeNsfw: true,
    ),
  ];

  /// Shelves for the Watch tab, in display order.
  static final List<CatalogShelfSpec> watch = [
    CatalogShelfSpec(
      id: 'watch_popular',
      title: _watchPopular,
      medium: CatalogMedium.watch,
      all: const ['watch'],
      minEntries: 4,
    ),
    CatalogShelfSpec(
      id: 'watch_new',
      title: (l) => l.catalog_shelf_new_watch,
      medium: CatalogMedium.watch,
      all: const ['watch'],
      newOnly: true,
      sort: CatalogSort.newest,
    ),
    CatalogShelfSpec(
      id: 'watch_movies',
      title: (l) => l.catalog_shelf_movies,
      medium: CatalogMedium.watch,
      all: const ['watch', 'movies'],
    ),
    CatalogShelfSpec(
      id: 'watch_series',
      title: (l) => l.catalog_shelf_series,
      medium: CatalogMedium.watch,
      all: const ['watch', 'series'],
    ),
    CatalogShelfSpec(
      id: 'watch_anime',
      title: (l) => l.catalog_shelf_anime,
      medium: CatalogMedium.watch,
      all: const ['watch', 'anime'],
    ),
    CatalogShelfSpec(
      id: 'watch_animation',
      title: (l) => l.catalog_shelf_animation,
      medium: CatalogMedium.watch,
      all: const ['watch', 'animation'],
    ),
    CatalogShelfSpec(
      id: 'watch_documentary',
      title: (l) => l.catalog_shelf_documentaries,
      medium: CatalogMedium.watch,
      all: const ['watch', 'documentary'],
    ),
    CatalogShelfSpec(
      id: 'watch_scifi',
      title: (l) => l.catalog_shelf_science_fiction,
      medium: CatalogMedium.watch,
      all: const ['watch', 'science-fiction'],
    ),
    CatalogShelfSpec(
      id: 'watch_fantasy',
      title: (l) => l.catalog_shelf_fantasy,
      medium: CatalogMedium.watch,
      all: const ['watch', 'fantasy'],
    ),
    CatalogShelfSpec(
      id: 'watch_action',
      title: (l) => l.catalog_shelf_action_adventure,
      medium: CatalogMedium.watch,
      all: const ['watch'],
      any: const ['action', 'adventure'],
    ),
    CatalogShelfSpec(
      id: 'watch_romance',
      title: (l) => l.catalog_shelf_romance_mystery,
      medium: CatalogMedium.watch,
      all: const ['watch'],
      any: const ['romance', 'mystery'],
    ),
  ];

  /// Shelves for the Manga tab, in display order.
  static final List<CatalogShelfSpec> read = [
    CatalogShelfSpec(
      id: 'read_popular',
      title: _readPopular,
      medium: CatalogMedium.read,
      all: const ['read'],
      minEntries: 4,
    ),
    CatalogShelfSpec(
      id: 'read_new',
      title: (l) => l.catalog_shelf_new_read,
      medium: CatalogMedium.read,
      all: const ['read'],
      newOnly: true,
      sort: CatalogSort.newest,
    ),
    CatalogShelfSpec(
      id: 'read_manga',
      title: (l) => l.catalog_shelf_manga,
      medium: CatalogMedium.read,
      all: const ['read', 'manga'],
    ),
    CatalogShelfSpec(
      id: 'read_manhwa',
      title: (l) => l.catalog_shelf_manhwa,
      medium: CatalogMedium.read,
      all: const ['read', 'manhwa'],
    ),
    CatalogShelfSpec(
      id: 'read_manhua',
      title: (l) => l.catalog_shelf_manhua,
      medium: CatalogMedium.read,
      all: const ['read', 'manhua'],
    ),
    CatalogShelfSpec(
      id: 'read_webtoon',
      title: (l) => l.catalog_shelf_webtoons,
      medium: CatalogMedium.read,
      all: const ['read', 'webtoon'],
    ),
    CatalogShelfSpec(
      id: 'read_comics',
      title: (l) => l.catalog_shelf_comics,
      medium: CatalogMedium.read,
      all: const ['read', 'comics'],
    ),
    CatalogShelfSpec(
      id: 'read_novel',
      title: (l) => l.catalog_shelf_novels,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
    ),
    CatalogShelfSpec(
      id: 'read_french',
      title: (l) => l.catalog_shelf_french,
      medium: CatalogMedium.read,
      all: const ['read', 'french'],
    ),
    CatalogShelfSpec(
      id: 'read_english',
      title: (l) => l.catalog_shelf_english,
      medium: CatalogMedium.read,
      all: const ['read', 'english'],
    ),
    CatalogShelfSpec(
      id: 'read_multilingual',
      title: (l) => l.catalog_shelf_multilingual,
      medium: CatalogMedium.read,
      all: const ['read', 'multilingual'],
    ),
  ];

  /// Shelves for the Novels tab: the reading shelves, minus the formats a novel
  /// catalogue never contains, plus the novel-only genres.
  static final List<CatalogShelfSpec> novel = [
    CatalogShelfSpec(
      id: 'novel_popular',
      title: _readPopular,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
      minEntries: 4,
    ),
    CatalogShelfSpec(
      id: 'novel_new',
      title: (l) => l.catalog_shelf_new_read,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
      newOnly: true,
      sort: CatalogSort.newest,
    ),
    CatalogShelfSpec(
      id: 'novel_french',
      title: (l) => l.catalog_shelf_french,
      medium: CatalogMedium.read,
      all: const ['read', 'novel', 'french'],
    ),
    CatalogShelfSpec(
      id: 'novel_english',
      title: (l) => l.catalog_shelf_english,
      medium: CatalogMedium.read,
      all: const ['read', 'novel', 'english'],
    ),
    CatalogShelfSpec(
      id: 'novel_multilingual',
      title: (l) => l.catalog_shelf_multilingual,
      medium: CatalogMedium.read,
      all: const ['read', 'novel', 'multilingual'],
    ),
    CatalogShelfSpec(
      id: 'novel_fantasy',
      title: (l) => l.catalog_shelf_fantasy,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
      any: const ['fantasy', 'science-fiction'],
    ),
    CatalogShelfSpec(
      id: 'novel_romance',
      title: (l) => l.catalog_shelf_romance_mystery,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
      any: const ['romance', 'mystery'],
    ),
    CatalogShelfSpec(
      id: 'novel_action',
      title: (l) => l.catalog_shelf_action_adventure,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
      any: const ['action', 'adventure'],
    ),
  ];

  static final List<CatalogShelfSpec> music = [
    CatalogShelfSpec(
      id: 'music_popular',
      title: _watchPopular,
      medium: CatalogMedium.music,
      all: const ['music'],
      minEntries: 2,
    ),
  ];

  static final List<CatalogShelfSpec> game = [
    CatalogShelfSpec(
      id: 'game_all',
      title: (l) => l.catalog_shelf_games,
      medium: CatalogMedium.game,
      all: const ['game'],
      minEntries: 1,
    ),
  ];

  /// Shelves of the "Pour vous" discovery page, in display order.
  ///
  /// The page mixes curated picks with the most useful per-medium shelves. Only
  /// the shelves that actually hold entries are rendered, so the page never
  /// shows an empty group.
  static final List<CatalogShelfSpec> forYou = [
    CatalogShelfSpec(
      id: 'foryou_recommended',
      title: (l) => l.catalog_shelf_recommended,
      minEntries: 4,
    ),
    CatalogShelfSpec(
      id: 'foryou_featured',
      title: (l) => l.catalog_shelf_featured,
      all: const ['featured'],
    ),
    CatalogShelfSpec(
      id: 'foryou_watch_popular',
      title: _watchPopular,
      medium: CatalogMedium.watch,
      all: const ['watch'],
    ),
    CatalogShelfSpec(
      id: 'foryou_read_popular',
      title: _readPopular,
      medium: CatalogMedium.read,
      all: const ['read'],
    ),
    CatalogShelfSpec(
      id: 'foryou_manga_manhwa',
      title: (l) => l.catalog_shelf_manga_manhwa,
      medium: CatalogMedium.read,
      all: const ['read'],
      any: const ['manga', 'manhwa', 'manhua'],
    ),
    CatalogShelfSpec(
      id: 'foryou_webtoons',
      title: (l) => l.catalog_shelf_webtoons,
      medium: CatalogMedium.read,
      all: const ['read', 'webtoon'],
    ),
    CatalogShelfSpec(
      id: 'foryou_novels',
      title: (l) => l.catalog_shelf_novels,
      medium: CatalogMedium.read,
      all: const ['read', 'novel'],
    ),
    CatalogShelfSpec(
      id: 'foryou_scifi_fantasy',
      title: (l) => l.catalog_shelf_scifi_fantasy,
      any: const ['science-fiction', 'fantasy'],
    ),
    CatalogShelfSpec(
      id: 'foryou_new',
      title: (l) => l.catalog_shelf_new,
      newOnly: true,
      sort: CatalogSort.newest,
    ),
    CatalogShelfSpec(
      id: 'foryou_multilingual',
      title: (l) => l.catalog_shelf_multilingual,
      all: const ['multilingual'],
    ),
    CatalogShelfSpec(
      id: 'foryou_music',
      title: (l) => l.catalog_shelf_music,
      medium: CatalogMedium.music,
      all: const ['music'],
      minEntries: 2,
    ),
  ];

  /// Shelves for the catalogue tab a medium belongs to.
  static List<CatalogShelfSpec> forMedium(CatalogMedium medium) =>
      switch (medium) {
        CatalogMedium.watch => watch,
        CatalogMedium.read => read,
        CatalogMedium.music => music,
        CatalogMedium.game => game,
      };

  /// Every shelf, by id, for "see all" navigation.
  static final Map<String, CatalogShelfSpec> byId = {
    for (final shelf in [
      ...forYou,
      ...watch,
      ...read,
      ...novel,
      ...music,
      ...game,
      ...adult,
    ])
      shelf.id: shelf,
  };
}
