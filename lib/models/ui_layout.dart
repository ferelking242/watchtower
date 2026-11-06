// lib/models/ui_layout.dart
// Declarative UI layout model. Replaces getCustomLists() return values.
// Extensions ship a JSON file; this model parses it. Flutter renders it.

import 'package:watchtower/models/layout_component_registry.dart';

/// Root layout for an extension. Loaded once from disk; cached in LayoutRegistry.
class UiLayout {
  final int schemaVersion;
  final HomeLayout home;
  final BrowseLayout? browse;
  final DetailLayout? detail;
  final PlayerLayout? player;

  const UiLayout({
    required this.schemaVersion,
    required this.home,
    this.browse,
    this.detail,
    this.player,
  });

  factory UiLayout.fromJson(Map<String, dynamic> json) => UiLayout(
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    home: HomeLayout.fromJson(
      (json['home'] as Map<String, dynamic>?) ?? const {},
    ),
    browse: json['browse'] != null
        ? BrowseLayout.fromJson(json['browse'] as Map<String, dynamic>)
        : null,
    detail: json['detail'] != null
        ? DetailLayout.fromJson(json['detail'] as Map<String, dynamic>)
        : null,
    player: json['player'] != null
        ? PlayerLayout.fromJson(json['player'] as Map<String, dynamic>)
        : null,
  );

  /// No custom home sections — extension uses standard Popular/Latest/Search.
  static const UiLayout empty = UiLayout(
    schemaVersion: 1,
    home: HomeLayout(sections: []),
  );
}

/// Home screen layout: ordered list of sections.
class HomeLayout {
  final List<UiSection> sections;
  const HomeLayout({required this.sections});

  factory HomeLayout.fromJson(Map<String, dynamic> json) => HomeLayout(
    sections: ((json['sections'] as List<dynamic>?) ?? [])
        .map((e) => UiSection.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Browse screen layout overrides.
class BrowseLayout {
  final SectionPresentation? popular;
  final SectionPresentation? latest;
  final SearchLayout? search;

  const BrowseLayout({this.popular, this.latest, this.search});

  factory BrowseLayout.fromJson(Map<String, dynamic> json) => BrowseLayout(
    popular: json['popular'] != null
        ? SectionPresentation.fromJson(json['popular'] as Map<String, dynamic>)
        : null,
    latest: json['latest'] != null
        ? SectionPresentation.fromJson(json['latest'] as Map<String, dynamic>)
        : null,
    search: json['search'] != null
        ? SearchLayout.fromJson(json['search'] as Map<String, dynamic>)
        : null,
  );
}

class SectionPresentation {
  final String component;
  final String? cardComponent;
  final int? columns;
  final String? cardStyle;

  const SectionPresentation({
    required this.component,
    this.cardComponent,
    this.columns,
    this.cardStyle,
  });

  factory SectionPresentation.fromJson(Map<String, dynamic> json) =>
      SectionPresentation(
        component: json['component'] as String? ?? 'grid',
        cardComponent: json['cardComponent'] as String?,
        columns: (json['columns'] as num?)?.toInt(),
        cardStyle: json['cardStyle'] as String?,
      );
}

class SearchLayout {
  final SectionPresentation? results;
  final String? filters;
  final bool searchPreview;
  final List<SearchTabLayout> tabs;

  const SearchLayout({
    this.results,
    this.filters,
    this.searchPreview = false,
    this.tabs = const [],
  });

  factory SearchLayout.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'];
    if (rawTabs != null && rawTabs is! List) {
      throw const FormatException('browse.search.tabs must be an array');
    }

    final tabs = <SearchTabLayout>[];
    final ids = <String>{};
    for (final rawTab in (rawTabs as List?) ?? const []) {
      if (rawTab is! Map) {
        throw const FormatException('each browse.search tab must be an object');
      }
      final tab = SearchTabLayout.fromJson(Map<String, dynamic>.from(rawTab));
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(tab.id) ||
          tab.title.trim().isEmpty ||
          !ids.add(tab.id)) {
        throw const FormatException(
          'search tabs need unique ids and non-empty titles',
        );
      }
      if (tab.source != 'search' && tab.source != 'custom') {
        throw FormatException('unknown search tab source "${tab.source}"');
      }
      tabs.add(tab);
    }

    return SearchLayout(
      results: json['results'] != null
          ? SectionPresentation.fromJson(
              json['results'] as Map<String, dynamic>,
            )
          : null,
      filters: json['filters'] as String?,
      searchPreview: json['searchPreview'] == true,
      tabs: List.unmodifiable(tabs),
    );
  }
}

/// A search category declared by an extension's browse.search.tabs layout.
class SearchTabLayout {
  /// Stable ID; custom tabs are passed to getCustomList as search_tab:<id>:…
  final String id;
  final String title;

  /// `search` uses the extension's normal search() method; `custom` uses
  /// getCustomList so extensions can run a category-specific query.
  final String source;

  /// Optional result kind used to keep broad search fallbacks in their tab.
  final String? resultType;

  const SearchTabLayout({
    required this.id,
    required this.title,
    this.source = 'custom',
    this.resultType,
  });

  factory SearchTabLayout.fromJson(Map<String, dynamic> json) =>
      SearchTabLayout(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        source: json['source'] as String? ?? 'custom',
        resultType: json['resultType'] as String?,
      );
}

class DetailLayout {
  final String? hero;
  final String? episodeList;
  final bool showRecommendations;

  const DetailLayout({
    this.hero,
    this.episodeList,
    this.showRecommendations = true,
  });

  factory DetailLayout.fromJson(Map<String, dynamic> json) => DetailLayout(
    hero: json['hero'] as String?,
    episodeList: json['episodeList'] as String?,
    showRecommendations: json['showRecommendations'] as bool? ?? true,
  );
}

class PlayerLayout {
  /// 'standard' | 'feed' (TikTok-style vertical reel)
  final String mode;

  const PlayerLayout({required this.mode});

  factory PlayerLayout.fromJson(Map<String, dynamic> json) =>
      PlayerLayout(mode: json['mode'] as String? ?? 'standard');

  bool get isFeed => mode == 'feed';
}

/// One home section declared by the layout JSON.
class UiSection {
  /// Unique id — passed as listId to getCustomList(id, page).
  final String id;

  /// Visual component:
  /// 'banner' | 'carousel' | 'ranked' | 'compactRow' | 'categoryPills' |
  /// 'creatorRow' | 'grid' | 'newHot' | 'feed' plus the reusable curated
  /// presentations: 'spotlight', 'doubleFeature', 'editorialSplit',
  /// 'landscapeStacked', 'backdropWide', 'metadataPoster', 'statusPoster',
  /// 'discoverGrid', 'studioExplorer', 'universeExplorer' and
  /// 'collectionTimeline'.
  final String component;

  final String? title;
  final String? icon;

  /// 'primary' | 'secondary' | 'tertiary' | 'error' | '#RRGGBB' hint
  final String? accent;

  /// Optional presentation hints consumed by the generic home renderer.
  /// The extension chooses these values; Flutter only maps them to widgets.
  final int? columns;
  final int? rows;
  final String? cardStyle;
  final String? cardComponent;
  final String? episodeComponent;
  final String? chapterComponent;
  final String? gridOrder;
  final String? scrollDirection;

  /// Presentation hint for the "see all" page this section opens. `tags`
  /// switches that page to a two-column grid of large, cover-first tag cards,
  /// which is what a tag index needs; extensions that don't set it keep the
  /// default three-column poster grid. The page itself is generic — any
  /// extension can ask for it through this single field.
  final String? seeAllPage;
  final UiMonthSelector? monthSelector;

  /// Free-form parameters for gallery components (see
  /// `GalleryComponentPalette`). They let a section tune a card without a new
  /// `component` id: number of items, columns, period, reading direction…
  final Map<String, dynamic> params;

  final bool seeAll;
  final bool paginated;
  final bool requiresAuth;

  const UiSection({
    required this.id,
    required this.component,
    this.title,
    this.icon,
    this.accent,
    this.columns,
    this.rows,
    this.cardStyle,
    this.cardComponent,
    this.episodeComponent,
    this.chapterComponent,
    this.gridOrder,
    this.scrollDirection,
    this.seeAllPage,
    this.monthSelector,
    this.params = const {},
    this.seeAll = false,
    this.paginated = false,
    this.requiresAuth = false,
  });

  factory UiSection.fromJson(Map<String, dynamic> json) => UiSection(
    id: json['id'] as String,
    component: json['component'] as String? ?? 'carousel',
    title: json['title'] as String?,
    icon: json['icon'] as String?,
    accent: json['accent'] as String?,
    columns: (json['columns'] as num?)?.toInt(),
    rows: (json['rows'] as num?)?.toInt(),
    cardStyle: json['cardStyle'] as String?,
    cardComponent: json['cardComponent'] as String?,
    episodeComponent: json['episodeComponent'] as String?,
    chapterComponent: json['chapterComponent'] as String?,
    gridOrder: json['gridOrder'] as String?,
    scrollDirection: json['scrollDirection'] as String?,
    seeAllPage: json['seeAllPage'] as String?,
    monthSelector: json['monthSelector'] is Map
        ? UiMonthSelector.fromJson(
            Map<String, dynamic>.from(json['monthSelector'] as Map),
          )
        : null,
    params: json['params'] is Map
        ? Map<String, dynamic>.from(json['params'] as Map)
        : const {},
    seeAll: json['seeAll'] as bool? ?? false,
    paginated: json['paginated'] as bool? ?? false,
    requiresAuth: json['requiresAuth'] as bool? ?? false,
  );

  // ── Legacy bridge ─────────────────────────────────────────────────────────
  // Source home renderers still use Map<String,dynamic> internally. Component
  // aliases and their legacy layouts are kept in LayoutComponentRegistry.
  Map<String, dynamic> toLegacyMap() => {
    'id': id,
    'component': component,
    'layout': _toLegacyLayout(component),
    'name': title,
    'icon': icon,
    'color': accent,
    if (columns != null) 'columns': columns,
    if (rows != null) 'rows': rows,
    if (cardStyle != null) 'cardStyle': cardStyle,
    if (cardComponent != null) 'cardComponent': cardComponent,
    if (episodeComponent != null) 'episodeComponent': episodeComponent,
    if (chapterComponent != null) 'chapterComponent': chapterComponent,
    if (gridOrder != null) 'gridOrder': gridOrder,
    if (scrollDirection != null) 'scrollDirection': scrollDirection,
    if (seeAllPage != null) 'seeAllPage': seeAllPage,
    if (monthSelector != null) 'monthSelector': monthSelector!.toJson(),
    if (params.isNotEmpty) 'params': params,
    if (seeAll) 'seeAll': id,
  };

  static String _toLegacyLayout(String component) =>
      LayoutComponentRegistry.legacyLayoutFor(component) ?? 'spotlight';
}

/// Optional month picker configuration for a section whose custom-list ID
/// includes the selected YYYY-MM value.
class UiMonthSelector {
  final String listIdPrefix;
  final String? initialMonth;
  final int monthsBack;

  const UiMonthSelector({
    required this.listIdPrefix,
    this.initialMonth,
    this.monthsBack = 36,
  });

  factory UiMonthSelector.fromJson(Map<String, dynamic> json) =>
      UiMonthSelector(
        listIdPrefix: json['listIdPrefix'] as String? ?? 'month_',
        initialMonth: json['initialMonth'] as String?,
        monthsBack: (json['monthsBack'] as num?)?.toInt() ?? 36,
      );

  Map<String, dynamic> toJson() => {
    'listIdPrefix': listIdPrefix,
    if (initialMonth != null) 'initialMonth': initialMonth,
    'monthsBack': monthsBack,
  };
}
