import 'package:flutter/material.dart';

import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/collection_cards.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/episode_cards.dart';
import 'package:watchtower/modules/media/home_hero_cards.dart';
import 'package:watchtower/modules/media/landscape_cards.dart';
import 'package:watchtower/modules/media/manga_chapter_cards.dart';
import 'package:watchtower/modules/media/manga_genre_cards.dart';
import 'package:watchtower/modules/media/manga_reader_cards.dart';
import 'package:watchtower/modules/media/manga_stats_cards.dart';
import 'package:watchtower/modules/media/manga_universe_cards.dart';
import 'package:watchtower/modules/media/manga_volume_cards.dart';
import 'package:watchtower/modules/media/media_content_sections.dart';
import 'package:watchtower/modules/media/ranking_cards.dart';
import 'package:watchtower/modules/media/rich_media_cards.dart';
import 'package:watchtower/modules/media/streaming_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart'
    as manga_home;
import 'package:watchtower/modules/widgets/component_library.dart';

/// Data boundary handed to every gallery component.
class GalleryComponentContext {
  const GalleryComponentContext({
    required this.componentId,
    required this.items,
    required this.onOpen,
    this.title,
    this.accent,
    this.params = const {},
    this.onSeeAll,
  });

  final String componentId;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final String? title;
  final Color? accent;
  final Map<String, dynamic> params;
  final VoidCallback? onSeeAll;

  GalleryComponentFamily? get family =>
      GalleryComponentCatalog.resolve(componentId)?.renderer;

  String? text(String key) {
    final value = params[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  int? number(String key) {
    final value = params[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? decimal(String key) {
    final value = params[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool flag(String key, {bool fallback = false}) {
    final value = params[key];
    if (value is bool) return value;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
  }

  /// Effective section title: explicit param wins over the layout title.
  String? get header => text('title') ?? title;
}

/// Renders every component documented by the developer gallery from
/// provider-neutral [ContentItem] data.
///
/// Each catalog id maps to the *real* production widget (not a stand-in):
/// `MovieDetailsCard`, `MangaChapterCard`, `TopMoviesCard`, `MangaReaderCard`…
/// The renderer also owns the responsive plumbing — a row or a grid with a
/// configurable number of columns/rows — so the same component behaves on
/// phone and on desktop and never overflows its section.
class GalleryComponentRenderer {
  GalleryComponentRenderer._();

  /// A single card for [ctx] (used by the grid renderer path).
  static Widget card(GalleryComponentContext ctx) {
    final items = limited(ctx);
    if (items.isEmpty) return const SizedBox.shrink();
    return _perItem(ctx, items, 0);
  }

  /// A horizontal rail of cards for the current component family.
  static Widget rail(GalleryComponentContext ctx) => section(ctx);

  /// The main entry point: renders the whole section (header + row/grid).
  static Widget section(GalleryComponentContext ctx) =>
      Builder(builder: (context) => _section(context, ctx));

  static Widget _section(BuildContext context, GalleryComponentContext ctx) {
    final items = limited(ctx);
    if (items.isEmpty) return const SizedBox.shrink();

    // Composite widgets already render their own title and every item.
    final whole = _wholeCard(context, ctx, items);
    if (whole != null) return _fullWidth(context, ctx, whole);

    final child = ctx.text('layout') == 'grid'
        ? _grid(context, ctx, items)
        : _row(context, ctx, items);
    return _header(ctx, child);
  }

  /// Full-width spotlight used by the extension renderer.
  static Widget spotlight(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
  ) => manga_home.MangaSpotlightCard(
    item: items[index],
    onTap: () => ctx.onOpen(index),
    height: ctx.decimal('height') ?? 230,
  );

  /// Full-width banner used by the extension renderer.
  static Widget banner(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => manga_home.MangaBannerCard(item: item, onTap: () => ctx.onOpen(index));

  // ── Layout plumbing ──────────────────────────────────────────────────────

  static List<ContentItem> limited(GalleryComponentContext ctx) {
    final limit = ctx.number('items');
    final items = ctx.items;
    if (limit == null || limit <= 0 || limit >= items.length) return items;
    return items.sublist(0, limit);
  }

  static Widget _header(GalleryComponentContext ctx, Widget child) {
    final title = ctx.header;
    if (title == null || title.trim().isEmpty) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: ctx.onSeeAll == null ? null : 'Tout voir',
          onAction: ctx.onSeeAll,
        ),
        child,
      ],
    );
  }

  /// A composite card keeps its designed width; on narrow screens it can be
  /// scrolled horizontally instead of being squeezed (which truncated it).
  static Widget _fullWidth(
    BuildContext context,
    GalleryComponentContext ctx,
    Widget child,
  ) {
    // Responsive sections and grids must consume the section width; only
    // fixed-width composite cards are allowed to scroll horizontally.
    if (ctx.flag('fill') || _isResponsive(ctx)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        child: child,
      ),
    );
  }

  /// Sections that size themselves to the available width (grids, swipe
  /// pagers, multi-column rails) instead of keeping a fixed card width.
  static bool _isResponsive(GalleryComponentContext ctx) {
    const responsiveIds = {
      'media-grid',
      'media-ranked',
      'media-landscape',
      'three-column-swipe',
      'series-grid',
      'manga-genres',
      'manga-top3',
      'manga-ranking',
      'manga-trending-list',
      'manga-collection-showcase',
      'manga-scan-group',
      'manga-spotlight',
      'manga-banner',
      'manga-latest-update',
      'manga-vote',
      'home-hero-banner',
    };
    if (responsiveIds.contains(ctx.componentId)) return true;
    return switch (ctx.family) {
      GalleryComponentFamily.grid ||
      GalleryComponentFamily.swipe ||
      GalleryComponentFamily.ranked ||
      GalleryComponentFamily.landscape => true,
      _ => false,
    };
  }

  static Widget _row(
    BuildContext context,
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) {
    final spacing = ctx.decimal('spacing') ?? 12;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.pagePadding(context),
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            // A horizontal viewport hands unbounded width to its children, so
            // each card is bound explicitly. Cards that overflow inside an
            // unbounded row (modals, previews) then lay out correctly.
            SizedBox(
              width: ctx.decimal('width') ?? _cardWidth(ctx.componentId),
              child: _perItem(ctx, items, i),
            ),
          ],
        ],
      ),
    );
  }

  /// Default bounded width for a per-item card, so a horizontal rail never
  /// feeds an unbounded constraint to a flex widget.
  static double _cardWidth(String id) => switch (id) {
    'movie-detail' || 'interactive-movie' => 220,
    'hover-movie' => 230,
    'expanded-movie' || 'expandable-movie' => 250,
    'movie-quick-view' => 280,
    'movie-details' || 'media-quick-view' => 300,
    'movie-details-modal' || 'media-details-modal' => 320,
    'movie-preview' || 'poster' => 120,
    'poster-card-compact' || 'ranked-card' => 110,
    'media-preview' || 'media-progress' => 300,
    'continue-watching' || 'watch-progress' => 300,
    'continue-watching-item' ||
    'now-playing' ||
    'episode-progress' ||
    'season-episode' => 380,
    'resume-watching' ||
    'up-next' ||
    'next-episode' ||
    'episode-thumbnail' ||
    'up-next-compact' => 240,
    'watch-again' => 200,
    'episode' || 'episode-list-item' => 330,
    'season' => 280,
    'series-episode' => 400,
    'progress-media' ||
    'progress-media-card-percent' ||
    'progress-media-card-chip' => 400,
    'collection' || 'universe' || 'category-card' || 'cast' => 420,
    'movie-collection' ||
    'franchise' ||
    'saga' ||
    'studio' ||
    'network' ||
    'genre' ||
    'actor' ||
    'director' ||
    'character' ||
    'related-media' => 400,
    'featured' => 340,
    'spotlight-card' => 300,
    'compact-episode' || 'latest-episode' => 340,
    'episode-preview' || 'season-banner' || 'series-banner' => 420,
    'season-detail' ||
    'manga-chapter-group' ||
    'manga-chapter-range' ||
    'manga-chapter-next' => 260,
    'featured-episode' => 200,
    'next-episode-hero' => 380,
    'manga-chapter' || 'manga-chapter-volume' => 280,
    'manga-new-chapter' => 320,
    'manga-chapter-progress' => 300,
    'manga-volume' => 150,
    'manga-format' => 120,
    'manga-special-edition' ||
    'manga-collection-tracker' ||
    'manga-reader' ||
    'manga-page-strip' ||
    'manga-reading-progress' ||
    'manga-reader-chapter-list' ||
    'manga-reader-history' ||
    'manga-double-page' ||
    'manga-reader-settings' => 320,
    'manga-page' ||
    'manga-page-preview' ||
    'manga-reading-mode' ||
    'manga-chapter-navigation' ||
    'manga-quick-access' ||
    'manga-reader-floating' => 380,
    'manga-reading-direction' => 300,
    'manga-update-row' || 'manga-resume' || 'manga-reader-floating-card' => 330,
    'manga-featured' => 168,
    'manga-genre' => 118,
    'manga-vote' => 320,
    'manga-latest-update' => 300,
    'manga-banner' => 640,
    'manga-spotlight' => 560,
    'manga-page-progress' => 280,
    'home-hero-banner' => 640,
    'home-mini-player-card' => 420,
    'landscape' || 'landscape-discovery' => 220,
    'home-spotlight-rail' => 340,
    'tag' => 260,
    'app-genre-tile' => 260,
    'discovery' || 'animated-discovery' => 120,
    _ => 260,
  };

  static Widget _grid(
    BuildContext context,
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) {
    // Grids adapt to the device unless the section overrides the count.
    final defaultColumns = AppUI.mediaGridColumns(context);
    final columns = (ctx.number('columns') ?? defaultColumns)
        .clamp(1, 8)
        .toInt();
    final rows = ctx.number('rows');
    final spacing = ctx.decimal('spacing') ?? 12;
    final visible = rows == null
        ? items
        : items.take((columns * rows).clamp(1, 60)).toList(growable: false);
    final rowCount = (visible.length / columns).ceil();
    final horizontal = AppUI.pagePadding(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final rawCell =
            (available - horizontal * 2 - spacing * (columns - 1)) / columns;
        final cell = rawCell.isFinite && rawCell > 0 ? rawCell : 120.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 6),
          child: Column(
            children: [
              for (var r = 0; r < rowCount; r++) ...[
                if (r > 0) SizedBox(height: spacing),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) SizedBox(width: spacing),
                      Expanded(
                        child: r * columns + c < visible.length
                            ? _perItemWithWidth(
                                ctx,
                                visible,
                                r * columns + c,
                                cell,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Grid cells must obey the section width, so the card is told the exact
  /// available width instead of its own design default.
  static Widget _perItemWithWidth(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
    double width,
  ) {
    final scoped = GalleryComponentContext(
      componentId: ctx.componentId,
      items: ctx.items,
      onOpen: ctx.onOpen,
      title: ctx.title,
      accent: ctx.accent,
      params: {...ctx.params, 'width': width},
      onSeeAll: ctx.onSeeAll,
    );
    return _perItem(scoped, items, index);
  }

  // ── Composite (whole-section) cards ──────────────────────────────────────

  /// Returns a widget that consumes the whole item list, or `null` when the
  /// component is rendered one card per item.
  static Widget? _wholeCard(
    BuildContext context,
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) {
    final id = ctx.componentId;
    final title = ctx.header ?? 'Catalogue';
    final w = ctx.decimal('width');
    VoidCallback? seeAll = ctx.onSeeAll;

    switch (id) {
      // ── Ranking panels ──
      case 'top-movies':
        return TopMoviesCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-series':
        return TopSeriesCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-anime':
        return TopAnimeCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-by-genre':
        return TopByGenreCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-by-country':
        return TopByCountryCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'global-ranking':
        return GlobalRankingCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-rated-ranking':
        return TopRatedRankingCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'trending-ranking':
        return TrendingRankingCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-by-decade':
        return TopByDecadeCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'must-watch':
        return MustWatchCard(
          items: _rank(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );

      // ── Collection rails ──
      case 'similar-media':
        return SimilarMediaCard(items: _entries(ctx, items), width: w ?? 430);
      case 'trending-card':
        return TrendingCard(
          items: _entries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'popular-card':
        return PopularCard(
          items: _entries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'top-rated':
        return TopRatedCard(
          items: _entries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'ranked-media':
        return RankedMediaCard(
          items: _entries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'numbered':
        return NumberedCard(items: _entries(ctx, items), width: w ?? 400);
      case 'recommendation':
        return RecommendationCard(
          items: _entries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'carousel-card':
        return CarouselCard(
          universes: _entries(ctx, items),
          width: w ?? 420,
          onPrevious: () {},
          onNext: () {},
        );

      // ── Episode / season panels ──
      case 'episode-list-item':
        return EpisodeListItem(
          episodes: _episodes(ctx, items),
          width: w ?? 330,
        );
      case 'episode-list':
        return EpisodeListCard(
          episodes: _episodes(ctx, items),
          width: w ?? 340,
        );
      case 'series-episode-list':
        return SeriesEpisodeListCard(
          episodes: _episodes(ctx, items),
          width: w ?? 340,
        );
      case 'episode-carousel':
        return EpisodeCarousel(
          episodes: _episodes(ctx, items),
          width: w ?? 420,
          onPrevious: () {},
          onNext: () {},
        );
      case 'season-selector':
        return SeasonSelectorCard(
          seasons: _seasons(ctx, items),
          episodes: _episodes(ctx, items),
          width: w ?? 420,
          onSeasonSelected: (_) {},
        );
      case 'series-grid':
        return SeriesGridCard(seasons: _seasons(ctx, items), width: w ?? 400);

      // ── Manga chapter / volume panels ──
      case 'manga-chapter-release':
        return MangaChapterReleaseCard(
          items: _chapters(ctx, items),
          width: w ?? 300,
          onSeeAll: seeAll,
        );
      case 'manga-chapter-list':
        return MangaChapterListCard(
          items: _chapters(ctx, items),
          width: w ?? 300,
          onSeeAll: seeAll,
        );
      case 'manga-latest-release':
        return MangaLatestReleaseCard(
          items: _chapters(ctx, items),
          width: w ?? 300,
          onSeeAll: seeAll,
        );
      case 'manga-release-timeline':
        return MangaReleaseTimelineCard(
          items: _chapters(ctx, items),
          width: w ?? 340,
          onSeeAll: seeAll,
        );
      case 'manga-chapter-timeline':
        return MangaChapterTimelineCard(
          items: _chapters(ctx, items),
          width: w ?? 300,
          onSeeAll: seeAll,
        );
      case 'manga-chapter-badge':
        return MangaChapterBadge(badges: _badges(ctx, items), width: w ?? 330);
      case 'manga-volume-list':
        return MangaVolumeListCard(
          items: _volumes(ctx, items),
          width: w ?? 170,
        );
      case 'manga-volume-preview':
        return MangaVolumePreviewCard(
          items: _volumes(ctx, items),
          width: w ?? 420,
          onViewCollection: () {},
        );
      case 'manga-upcoming-volume':
        return MangaUpcomingVolumeCard(
          items: _volumes(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-chapter-search':
        return MangaChapterSearchCard(
          width: w ?? 300,
          recent: _titles(items),
          onSearch: (_) {},
        );

      // ── Manga genre / stats panels ──
      case 'manga-genres':
        return MangaGenresCard(
          items: _genreEntries(ctx, items),
          width: w ?? 400,
          title: title,
          columns: ctx.number('columns') ?? 2,
          onSeeAll: seeAll,
        );
      case 'manga-demographics':
        return MangaDemographicsCard(
          items: _genreEntries(ctx, items),
          width: w ?? 400,
          onSeeAll: seeAll,
        );
      case 'manga-themes':
        return MangaThemesCard(
          items: _genreEntries(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-universe-showcase':
        return MangaUniverseShowcaseCard(
          items: _showcase(ctx, items),
          width: w ?? 430,
          title: title,
          onSeeAll: seeAll,
        );
      case 'manga-tags':
        return MangaTagsCard(
          tags: _tags(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-languages':
        return MangaLanguagesCard(
          languages: _langs(ctx, items),
          teams: _teams(ctx, items),
          statusRows: _statusRows(ctx, items),
          width: w ?? 430,
        );
      case 'manga-publishers':
        return MangaPublishersCard(
          publishers: _publishers(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-language-news':
        return MangaLanguageNewsCard(
          entries: _langs(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-global-stats':
        return MangaGlobalStatsCard(
          tiles: _statTiles(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-stats-grid':
        return MangaStatsGridCard(
          tiles: _statTiles(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-status':
        return MangaStatusCard(
          items: _statusTuples(items),
          width: w ?? 400,
          onSeeAll: seeAll,
        );
      case 'manga-frequency':
        return MangaFrequencyCard(
          items: _freqTuples(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-popularity':
        return MangaPopularityCard(
          items: _rankEntries(items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-category-ranking':
        return MangaCategoryRankingCard(
          items: _rankEntries(items),
          width: w ?? 400,
          onSeeAll: seeAll,
        );
      case 'manga-followers':
        return MangaFollowersCard(
          items: _relations(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-reports':
        return MangaReportsCard(
          items: _statRows(items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-serialization':
        return MangaSerializationCard(
          items: _showcase(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-item-stats':
        return MangaItemStatsCard(
          title: items.first.title,
          statusLabel: ctx.text('subtitle') ?? items.first.badge,
          rows: _statRows(items),
          coverUrl: items.first.posterUrl,
          width: w ?? 420,
        );
      case 'manga-edition-language':
        return MangaEditionLanguageCard(
          rows: _editionRows(items),
          width: w ?? 320,
          onSeeAll: seeAll,
        );

      // ── Manga universe panels ──
      case 'manga-relation-type':
        return MangaRelationTypeCard(
          items: _relationEntries(ctx, items),
          width: w ?? 430,
          columns: ctx.number('columns') ?? 4,
          onSeeAll: seeAll,
        );
      case 'manga-universe-timeline':
        return MangaUniverseTimelineCard(
          title: items.first.title,
          backdropUrl: items.first.backdropUrl,
          series: _relationEntries(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-linked-series':
        return MangaLinkedSeriesCard(
          items: _relationEntries(ctx, items),
          width: w ?? 360,
          columns: ctx.number('columns') ?? 3,
          onSeeAll: seeAll,
        );
      case 'manga-relation-list':
        return MangaRelationListCard(
          items: _relationEntries(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-same-universe':
        return MangaSameUniverseCard(
          title: items.first.title,
          backdropUrl: items.first.backdropUrl,
          entries: _relationEntries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );
      case 'manga-universe-chronology':
        return MangaUniverseChronologyCard(
          points: _points(items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-franchise-universes':
        return MangaFranchiseUniversesCard(
          items: _relationEntries(ctx, items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'manga-character-relations':
        return MangaCharacterRelationsCard(
          items: _relationEntries(ctx, items),
          width: w ?? 430,
          columns: ctx.number('columns') ?? 4,
          onSeeAll: seeAll,
        );
      case 'manga-universe-map':
        return MangaUniverseMapCard(
          nodes: _relationEntries(ctx, items),
          width: w ?? 430,
          onSeeAll: seeAll,
        );

      // ── Home hero rails ──
      case 'home-spotlight-rail':
        return HomeSpotlightRailCard(
          items: _spotlightEntries(ctx, items),
          width: w ?? 340,
          onSeeAll: seeAll,
        );
      case 'home-genre-tile':
        return HomeGenreTileCard(
          items: _genreCardEntries(ctx, items),
          width: w ?? 620,
          onSeeAll: seeAll,
        );
      case 'home-popular-rail':
        return HomePopularRailCard(
          items: _popularEntries(ctx, items),
          width: w ?? 620,
          onSeeAll: seeAll,
        );
      case 'home-read-rail':
        return HomeReadRailCard(
          items: _spotlightEntries(ctx, items),
          width: w ?? 620,
          onSeeAll: seeAll,
        );
      case 'home-language-grid':
        return HomeLanguageGridCard(
          chips: _countryChips(items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'home-my-list':
        return HomeMyListCard(
          items: _myListEntries(items),
          width: w ?? 360,
          onSeeAll: seeAll,
        );
      case 'home-airecommender':
        final placeholder = ctx.text('subtitle');
        return HomeAIRecommenderCard(
          placeholder: placeholder ?? 'Top 20 séries comme Superman…',
          width: w ?? 360,
          onSend: (_) {},
        );
      case 'home-mini-player':
        return HomeMiniPlayerCard(
          title: items.first.title,
          episodeLabel: ctx.text('subtitle'),
          progressLabel: ctx.text('badge'),
          progress: ctx.decimal('progress') ?? 0.0,
          thumbUrl: items.first.backdropUrl ?? items.first.posterUrl,
          width: w ?? 420,
          onResume: () {},
        );

      // ── Landscape sections ──
      case 'landscape-showcase':
      case 'landscape-films':
      case 'landscape-series':
      case 'landscape-manga':
      case 'landscape-novels':
        return LandscapeShowcaseSection(
          title: title,
          subtitle: ctx.text('subtitle') ?? 'Sélection',
          icon: Icons.view_carousel_outlined,
          items: _landscape(ctx, items),
          width: w ?? 900,
          onSeeAll: seeAll,
        );
      case 'landscape-playlist':
        return LandscapePlaylistCard(
          playlists: _playlists(ctx, items),
          width: w ?? 900,
          onSeeAll: seeAll,
        );
      case 'landscape-genre-row':
        return LandscapeGenreRow(
          tiles: _genreTiles(ctx, items),
          width: w ?? 900,
          onSeeAll: seeAll,
        );

      // ── Streaming rails ──
      case 'recently-watched':
        return RecentlyWatchedCard(
          items: _streamEpisodes(ctx, items),
          width: w ?? 470,
          headerLabel: title,
          onSeeAll: seeAll,
        );

      // ── Swipe ──
      case 'three-column-swipe':
        return ThreeColumnSwipeSection<ContentItem>(
          title: title,
          items: items,
          rows: ctx.number('rows') ?? 3,
          columns: ctx.number('columns') ?? 3,
          itemHeight: ctx.decimal('height') ?? 196,
          onSeeAll: seeAll,
          // A fixed poster width keeps the image height (2/3 ratio) inside the
          // fixed-height cell instead of overflowing it.
          itemBuilder: (context, item) => PosterCard(
            item: item,
            width: 96,
            onTap: () => ctx.onOpen(items.indexOf(item)),
          ),
        );

      // ── Manga home composite cards ──
      case 'manga-top3':
        return manga_home.MangaTop3Card(
          items: items.take(3).toList(growable: false),
          rank: 1,
          onTap: (index) => ctx.onOpen(index),
        );
      case 'manga-ranking':
        return manga_home.MangaRankingCard(
          items: items,
          onOpen: (index) => ctx.onOpen(index),
        );
      case 'manga-trending-list':
        return manga_home.MangaTrendingListCard(
          title: items.first.title,
          author: ctx.text('subtitle') ?? items.first.badge ?? 'Auteur',
          rank: 1,
          covers: _covers(items),
          onTap: () => ctx.onOpen(0),
        );
      case 'manga-collection-showcase':
        return manga_home.MangaCollectionShowcaseCard(
          title: items.first.title,
          covers: _covers(items),
          onTap: () => ctx.onOpen(0),
        );
      case 'manga-scan-group':
        return manga_home.MangaScanGroupCard(
          name: items.first.title,
          rank: ctx.number('rank') ?? 1,
          covers: _covers(items),
          onTap: () => ctx.onOpen(0),
        );

      // ── Extension rails: whole sections, not a rail of standalone cards ──
      case 'media-ranked':
        return MediaRankedRail(items: items, title: title, onOpen: ctx.onOpen);
      case 'media-landscape':
        return MediaLandscapeRail(
          items: items,
          title: title,
          onOpen: ctx.onOpen,
        );

      // ── Adaptive catalog grid (responsive: fills phone ↔ desktop) ──
      case 'media-grid':
        return MediaGridSection(
          title: title,
          items: items,
          onOpen: ctx.onOpen,
          columns: ctx.number('columns'),
          rows: ctx.number('rows'),
          scrollDirection: ctx.text('scrollDirection'),
          onSeeAll: seeAll,
        );
    }
    return null;
  }

  // ── Per-item cards ───────────────────────────────────────────────────────

  static Widget _perItem(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
  ) {
    final i = index.clamp(0, items.length - 1);
    final item = items[i];
    void onTap() => ctx.onOpen(i);
    final w = ctx.decimal('width');

    // Cards that accept an explicit width keep their design size by default.
    switch (ctx.componentId) {
      // ── Rich media ──
      case 'movie-details':
        return MovieDetailsCard(
          data: _rich(ctx, item),
          castNames: _cast(ctx),
          width: w ?? 300,
        );
      case 'movie-detail':
        return MovieDetailCard(data: _rich(ctx, item), width: w ?? 220);
      case 'expanded-movie':
        return ExpandableMovieCard(
          data: _rich(ctx, item),
          director: ctx.text('subtitle'),
          actors: _cast(ctx),
          width: w ?? 250,
        );
      case 'expandable-movie':
        return ExpandableMovieCard(
          data: _rich(ctx, item),
          director: ctx.text('subtitle'),
          actors: _cast(ctx),
          width: w ?? 250,
        );
      case 'interactive-movie':
        return InteractiveMovieCard(data: _rich(ctx, item), width: w ?? 220);
      case 'hover-movie':
        return HoverMovieCard(data: _rich(ctx, item), width: w ?? 230);
      case 'movie-quick-view':
        return MovieQuickView(
          data: _rich(ctx, item),
          width: w ?? 280,
          onClose: () {},
        );
      case 'media-quick-view':
        return MediaQuickView(data: _rich(ctx, item), onClose: () {});
      case 'movie-preview':
        return MoviePreview(
          data: _rich(ctx, item),
          width: w ?? 132,
          onTap: onTap,
        );
      case 'media-preview':
        return MediaPreview(data: _rich(ctx, item), onTap: onTap);
      case 'movie-details-modal':
        return MovieDetailsModal(data: _rich(ctx, item));
      case 'media-details-modal':
        return MediaDetailsModal(data: _rich(ctx, item));

      // ── Streaming ──
      case 'continue-watching':
        return ContinueWatchingCard(data: _stream(ctx, item), width: w ?? 300);
      case 'continue-watching-item':
        return ContinueWatchingItem(data: _stream(ctx, item), width: w ?? 380);
      case 'resume-watching':
        return ResumeWatchingCard(data: _stream(ctx, item), width: w ?? 220);
      case 'watch-again':
        return WatchAgainCard(data: _stream(ctx, item), width: w ?? 200);
      case 'now-playing':
        return NowPlayingCard(
          data: _stream(ctx, item),
          width: w ?? 380,
          hd: ctx.flag('hd'),
        );
      case 'up-next':
        return UpNextCard(data: _stream(ctx, item), width: w ?? 240);
      case 'next-episode':
        return NextEpisodeCard(data: _stream(ctx, item), width: w ?? 240);
      case 'season':
        return SeasonCard(data: _stream(ctx, item), width: w ?? 280);
      case 'series-episode':
        return SeriesEpisodeCard(data: _stream(ctx, item), width: w ?? 400);
      case 'watch-progress':
        return WatchProgressCard(data: _stream(ctx, item), width: w ?? 400);
      case 'progress-media':
        return ProgressMediaCard(
          data: _stream(ctx, item),
          width: w ?? 400,
          style: ProgressMediaStyle.bar,
        );
      case 'progress-media-card-percent':
        return ProgressMediaCard(
          data: _stream(ctx, item),
          width: w ?? 400,
          style: ProgressMediaStyle.percent,
        );
      case 'progress-media-card-chip':
        return ProgressMediaCard(
          data: _stream(ctx, item),
          width: w ?? 400,
          style: ProgressMediaStyle.chip,
        );
      case 'episode':
        return EpisodeCard(
          episodes: _streamEpisodes(ctx, items),
          width: w ?? 330,
          seasonLabel: ctx.text('subtitle') ?? 'Saison 1',
        );

      // ── Collections ──
      case 'collection':
        return CollectionCard(data: _collection(ctx, item), width: w ?? 420);
      case 'movie-collection':
        return MovieCollectionCard(
          data: _collection(ctx, item),
          width: w ?? 400,
        );
      case 'franchise':
        return FranchiseCard(data: _collection(ctx, item), width: w ?? 400);
      case 'saga':
        return SagaCard(data: _collection(ctx, item), width: w ?? 400);
      case 'studio':
        return StudioCard(data: _collection(ctx, item), width: w ?? 400);
      case 'network':
        return NetworkCard(data: _collection(ctx, item), width: w ?? 400);
      case 'genre':
        return GenreCard(data: _collection(ctx, item), width: w ?? 400);
      case 'actor':
        return ActorCard(data: _collection(ctx, item), width: w ?? 400);
      case 'director':
        return DirectorCard(data: _collection(ctx, item), width: w ?? 400);
      case 'character':
        return CharacterCard(data: _collection(ctx, item), width: w ?? 400);
      case 'related-media':
        return RelatedMediaCard(data: _collection(ctx, item), width: w ?? 400);
      case 'featured':
        return FeaturedCard(
          data: _collection(ctx, item),
          width: w ?? 340,
          height: ctx.decimal('height') ?? 190,
        );
      case 'spotlight-card':
        return SpotlightCard(
          data: _collection(ctx, item),
          width: w ?? 300,
          height: ctx.decimal('height') ?? 170,
        );
      case 'universe':
      case 'category-card':
      case 'cast':
        return UniverseCard(data: _collection(ctx, item), width: w ?? 400);

      // ── Episodes ──
      case 'compact-episode':
        return CompactEpisodeCard(
          entry: _episode(ctx, item, i),
          width: w ?? 340,
        );
      case 'episode-thumbnail':
        return EpisodeThumbnail(entry: _episode(ctx, item, i), width: w ?? 240);
      case 'episode-preview':
        return EpisodePreviewCard(
          entry: _episode(ctx, item, i),
          width: w ?? 400,
        );
      case 'season-detail':
        return SeasonDetailCard(season: _season(ctx, item), width: w ?? 260);
      case 'featured-episode':
        return FeaturedEpisodeCard(
          entry: _episode(ctx, item, i),
          width: w ?? 200,
        );
      case 'next-episode-hero':
        return NextEpisodeHeroCard(
          entry: _episode(ctx, item, i),
          width: w ?? 380,
        );
      case 'latest-episode':
        return LatestEpisodeCard(
          entry: _episode(ctx, item, i),
          width: w ?? 340,
        );
      case 'episode-progress':
        return EpisodeProgressCard(
          entry: _episode(ctx, item, i),
          width: w ?? 380,
        );
      case 'media-progress':
        return MediaProgressCard(
          entry: _episode(ctx, item, i),
          width: w ?? 380,
        );
      case 'up-next-compact':
        return UpNextCompactCard(
          entry: _episode(ctx, item, i),
          width: w ?? 240,
        );
      case 'season-episode':
        return SeasonEpisodeCard(
          entry: _episode(ctx, item, i),
          width: w ?? 380,
        );
      case 'series-banner':
        return SeriesBannerCard(season: _season(ctx, item), width: w ?? 420);
      case 'season-banner':
        return SeasonBannerCard(season: _season(ctx, item), width: w ?? 420);

      // ── Manga chapter ──
      case 'manga-chapter':
        return MangaChapterCard(item: _chapter(ctx, item, i), width: w ?? 280);
      case 'manga-chapter-group':
        return MangaChapterGroupCard(
          item: _chapter(ctx, item, i),
          width: w ?? 260,
        );
      case 'manga-chapter-volume':
        return MangaChapterVolumeCard(
          item: _chapter(ctx, item, i),
          width: w ?? 280,
        );
      case 'manga-chapter-range':
        return MangaChapterRangeCard(
          item: _chapter(ctx, item, i),
          width: w ?? 260,
          onViewList: () {},
        );
      case 'manga-new-chapter':
        return MangaNewChapterCard(
          item: _chapter(ctx, item, i),
          width: w ?? 320,
        );
      case 'manga-chapter-progress':
        return MangaChapterProgressCard(
          item: _chapter(ctx, item, i),
          width: w ?? 300,
          onContinue: () {},
        );
      case 'manga-chapter-next':
        return MangaChapterNextCard(
          item: _chapter(ctx, item, i),
          width: w ?? 280,
          onRemind: () {},
        );

      // ── Manga volume ──
      case 'manga-volume':
        return MangaVolumeCard(item: _volume(ctx, item, i), width: w ?? 150);
      case 'manga-special-edition':
        return MangaSpecialEditionCard(item: _volume(ctx, item, i));
      case 'manga-format':
        return MangaFormatCard(item: _volume(ctx, item, i), width: w ?? 120);
      case 'manga-collection-tracker':
        return MangaCollectionTrackerCard(
          item: _volume(ctx, item, i),
          stats: _statPairs(items),
          progress: ctx.decimal('progress') ?? 0.0,
          width: w ?? 400,
          onViewCollection: () {},
        );

      // ── Manga genre single card ──
      case 'manga-genre':
        return manga_home.MangaGenreCard(
          label: item.title,
          imageUrl: item.posterUrl,
          onTap: onTap,
        );
      case 'app-genre-tile':
        return SizedBox(
          width: w ?? 260,
          height: ctx.decimal('height') ?? 112,
          child: AppGenreTile(
            label: item.title,
            imageUrl: item.posterUrl,
            onTap: onTap,
          ),
        );

      // ── Manga reader ──
      case 'manga-reader':
        return MangaReaderCard(
          title: item.title,
          author: ctx.text('subtitle'),
          chapterLabel: ctx.text('badge'),
          pageLabel: ctx.text('readingDirection'),
          coverUrl: item.posterUrl,
          width: w ?? 300,
          onRead: onTap,
        );
      case 'manga-page':
        return MangaPageCard(
          pageUrl: item.posterUrl ?? '',
          pageLabel: ctx.text('badge') ?? '${i + 1}',
          totalLabel: ctx.text('subtitle') ?? '${items.length}',
          width: w ?? 340,
        );
      case 'manga-page-preview':
        return MangaPagePreviewCard(pages: _pages(items), width: w ?? 420);
      case 'manga-page-strip':
        return MangaPageStripCard(pages: _pages(items), width: w ?? 420);
      case 'manga-double-page':
        return MangaDoublePageCard(
          leftUrl: item.posterUrl,
          rightUrl: item.backdropUrl ?? item.posterUrl,
          width: w ?? 340,
        );
      case 'manga-reading-mode':
        return MangaReadingModeCard(
          options: _readingOptions(items),
          width: w ?? 400,
        );
      case 'manga-reading-direction':
        return MangaReadingDirectionCard(
          options: _readingOptions(items),
          width: w ?? 300,
        );
      case 'manga-reader-settings':
        return MangaReaderSettingsCard(rows: _settingRows(), width: w ?? 340);
      case 'manga-page-progress':
        return MangaPageProgressCard(
          percentLabel: ctx.text('badge') ?? '42%',
          progress: ctx.decimal('progress') ?? 0.42,
          chapterLabel: ctx.text('subtitle'),
          pageLabel: ctx.text('title'),
          width: w ?? 280,
        );
      case 'manga-reading-progress':
        return MangaReadingProgressCard(
          title: item.title,
          chapterLabel: ctx.text('subtitle'),
          pageLabel: ctx.text('badge'),
          percentLabel: '42%',
          progress: ctx.decimal('progress') ?? 0.42,
          coverUrl: item.posterUrl,
          width: w ?? 300,
        );
      case 'manga-chapter-navigation':
        return MangaChapterNavigationCard(
          currentLabel: item.title,
          prevLabel: ctx.text('subtitle'),
          nextLabel: ctx.text('badge'),
          width: w ?? 420,
        );
      case 'manga-quick-access':
        return MangaQuickAccessCard(
          resumeTitle: item.title,
          resumeChapter: ctx.text('subtitle') ?? 'Chapitre 1',
          resumePage: ctx.text('badge') ?? 'Page 1',
          resumeThumb: item.posterUrl,
          actions: _quickActions(),
          shortcuts: _quickActions(),
          width: w ?? 340,
          onResume: onTap,
        );
      case 'manga-reader-floating':
        return MangaReaderFloatingCard(
          bgUrl: item.backdropUrl ?? item.posterUrl,
          chapterLabel: ctx.text('subtitle') ?? 'Chapitre 1',
          actions: _quickActions(),
          width: w ?? 340,
        );
      case 'manga-reader-chapter-list':
        return MangaReaderChapterListCard(
          items: _chapterRows(items),
          width: w ?? 300,
          onRead: () {},
        );
      case 'manga-reader-history':
        return MangaReaderHistoryCard(
          items: _history(items),
          width: w ?? 300,
          onSeeAll: ctx.onSeeAll,
        );

      // ── Manga home single cards ──
      case 'manga-featured':
        return manga_home.MangaFeaturedCard(
          item: item,
          onTap: onTap,
          width: w ?? 168,
        );
      case 'manga-resume':
        return manga_home.MangaResumeCard(
          item: item,
          subtitle: ctx.text('subtitle'),
          progress: ctx.decimal('progress') ?? 0.42,
          onTap: onTap,
        );
      case 'manga-spotlight':
        return manga_home.MangaSpotlightCard(
          item: item,
          height: ctx.decimal('height') ?? 210,
          onTap: onTap,
        );
      case 'manga-update-row':
        return manga_home.MangaUpdateRow(
          item: item,
          subtitle: ctx.text('subtitle') ?? item.badge,
          time: ctx.text('time'),
          onTap: onTap,
        );
      case 'manga-banner':
        return manga_home.MangaBannerCard(item: item, onTap: onTap);
      case 'manga-latest-update':
        return manga_home.MangaLatestUpdateCard(
          item: item,
          time: ctx.text('time'),
          onTap: onTap,
        );
      case 'manga-vote':
        return manga_home.MangaVoteCard(
          title: item.title,
          imageUrl: item.posterUrl,
          status: ctx.text('badge') ?? 'Voting closed',
          onTap: onTap,
        );

      // ── Home hero single cards ──
      case 'home-hero-banner':
        return HomeHeroBannerCard(
          title: item.title,
          kindLabel: ctx.text('badge') ?? 'Série',
          tags: _tagsFrom(ctx),
          description: item.description,
          ratingLabel: item.rating?.toStringAsFixed(1),
          backdropUrl: item.backdropUrl ?? item.posterUrl,
          width: w ?? 640,
          onWatch: onTap,
        );
      case 'home-mini-player-card':
        return HomeMiniPlayerCard(
          title: item.title,
          thumbUrl: item.posterUrl,
          width: w ?? 420,
          onResume: onTap,
        );

      // ── Poster / landscape / ranked / tag ──
      case 'poster':
        return PosterCard(
          item: item,
          width: w ?? 120,
          compact: ctx.flag('compact'),
          showMediaMetadata: true,
          onTap: onTap,
        );
      case 'poster-card-compact':
        return PosterCard(
          item: item,
          width: w ?? 92,
          compact: true,
          onTap: onTap,
        );
      case 'landscape':
        return LandscapeCard(item: item, width: w ?? 220, onTap: onTap);
      case 'ranked-card':
        return RankedCard(
          item: item,
          rank: ctx.number('rank') ?? i + 1,
          width: w ?? 110,
          onTap: onTap,
        );
      case 'tag':
        return TagCard(item: item, onTap: onTap);

      // ── Discovery cards ──
      case 'discovery':
      case 'animated-discovery':
        return PosterCard(
          item: item,
          width: w ?? 120,
          showMediaMetadata: true,
          onTap: onTap,
        );
      case 'featured-discovery':
        return FeaturedDiscoveryCard(media: _anilist(item), onTap: onTap);
      case 'saga-discovery':
        return SagaDiscoveryCard(media: _anilist(item), onTap: onTap);
      case 'spotlight-discovery':
        return SpotlightDiscoveryCard(media: _anilist(item), onTap: onTap);
      case 'landscape-discovery':
        return LandscapeDiscoveryCard(
          media: _anilist(item),
          width: w ?? 220,
          onTap: onTap,
        );
      case 'ranked-discovery':
        return RankedDiscoveryCard(
          media: _anilist(item),
          rank: i + 1,
          onTap: onTap,
        );
    }

    // Unknown ids fall back to the family default so nothing is dropped.
    return _familyFallback(ctx, items, i);
  }

  static Widget _familyFallback(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
  ) {
    final item = items[index];
    void onTap() => ctx.onOpen(index);
    final w = ctx.decimal('width');
    final family = ctx.family;
    if (family == null) {
      return PosterCard(item: item, width: w ?? 120, onTap: onTap);
    }
    switch (family) {
      case GalleryComponentFamily.richMedia:
        return MovieDetailsCard(data: _rich(ctx, item), width: w ?? 300);
      case GalleryComponentFamily.streaming:
        return ContinueWatchingCard(data: _stream(ctx, item), width: w ?? 300);
      case GalleryComponentFamily.collections:
        return CollectionCard(data: _collection(ctx, item), width: w ?? 420);
      case GalleryComponentFamily.episodes:
        return EpisodePreviewCard(
          entry: _episode(ctx, item, index),
          width: w ?? 400,
        );
      case GalleryComponentFamily.ranking:
        return TopMoviesCard(items: _rank(items), width: w ?? 430);
      case GalleryComponentFamily.mangaChapter:
        return MangaChapterCard(
          item: _chapter(ctx, item, index),
          width: w ?? 280,
        );
      case GalleryComponentFamily.mangaVolume:
        return MangaVolumeCard(
          item: _volume(ctx, item, index),
          width: w ?? 150,
        );
      case GalleryComponentFamily.mangaReader:
        return MangaReaderCard(
          title: item.title,
          coverUrl: item.posterUrl,
          width: w ?? 300,
          onRead: onTap,
        );
      case GalleryComponentFamily.mangaGenre:
        return manga_home.MangaGenreCard(
          label: item.title,
          imageUrl: item.posterUrl,
          onTap: onTap,
        );
      case GalleryComponentFamily.ranked:
        return RankedCard(
          item: item,
          rank: index + 1,
          width: w ?? 110,
          onTap: onTap,
        );
      case GalleryComponentFamily.landscape:
        return LandscapeCard(item: item, width: w ?? 220, onTap: onTap);
      case GalleryComponentFamily.homeHero:
        return manga_home.MangaFeaturedCard(
          item: item,
          width: w ?? 168,
          onTap: onTap,
        );
      case GalleryComponentFamily.spotlight:
      case GalleryComponentFamily.banner:
        return manga_home.MangaBannerCard(item: item, onTap: onTap);
      case GalleryComponentFamily.mangaUniverse:
        return MangaLinkedSeriesCard(
          items: _relationEntries(ctx, items),
          width: w ?? 360,
        );
      case GalleryComponentFamily.mangaStats:
        return MangaGlobalStatsCard(tiles: _statTiles(items), width: w ?? 430);
      case GalleryComponentFamily.grid:
      case GalleryComponentFamily.posterRail:
      case GalleryComponentFamily.swipe:
        return PosterCard(item: item, width: w ?? 120, onTap: onTap);
    }
  }

  // ── Model builders ──────────────────────────────────────────────────────

  static List<String> _cast(GalleryComponentContext ctx) {
    final raw = ctx.text('cast');
    if (raw == null) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _tagsFrom(GalleryComponentContext ctx) {
    final raw = ctx.text('tags');
    if (raw == null) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _titles(List<ContentItem> items) => [
    for (final item in items) item.title,
  ];

  static List<String> _covers(List<ContentItem> items) => [
    for (final item in items)
      if (item.posterUrl != null) item.posterUrl!,
  ];

  static RichMediaCardData _rich(
    GalleryComponentContext ctx,
    ContentItem item,
  ) => RichMediaCardData(
    item: item,
    meta: item.badge,
    genres: ctx.text('genres'),
    runtimeMinutes: ctx.number('runtime'),
    onPlay: () {},
    onAddToList: () {},
    onMore: () {},
    onShare: () {},
  );

  static StreamingCardData _stream(
    GalleryComponentContext ctx,
    ContentItem item,
  ) => StreamingCardData(
    item: item,
    seriesMeta: ctx.text('seriesMeta'),
    extraMeta: item.description,
    remainingLabel: ctx.text('remaining'),
    badge: ctx.text('badge') ?? item.badge,
    progress: ctx.decimal('progress'),
    onPlay: () {},
    onTap: () {},
  );

  static CollectionCardData _collection(
    GalleryComponentContext ctx,
    ContentItem item,
  ) => CollectionCardData(
    item: item,
    stats: ctx.text('stats'),
    subtitle: ctx.text('subtitle'),
    description: item.description,
    badge: ctx.text('badge') ?? item.badge,
    actionLabel: ctx.text('actionLabel'),
    onExplore: () {},
    onTap: () {},
  );

  static EpisodeEntry _episode(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => EpisodeEntry(
    title: item.title,
    meta: item.badge,
    subtitle: item.description,
    number: index + 1,
    rating: item.rating,
    progress: ctx.decimal('progress'),
    thumbUrl: item.posterUrl,
    backdropUrl: item.backdropUrl,
    badge: ctx.text('badge') ?? item.badge,
    onTap: () {},
    onPlay: () {},
  );

  static SeasonEntry _season(GalleryComponentContext ctx, ContentItem item) =>
      SeasonEntry(
        title: item.title,
        seasonLabel: ctx.text('subtitle'),
        stats: ctx.text('stats'),
        description: item.description,
        thumbUrl: item.backdropUrl ?? item.posterUrl,
        rating: item.rating,
        onTap: () {},
      );

  static MangaChapterItem _chapter(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => MangaChapterItem(
    title: item.title,
    subtitle: ctx.text('subtitle') ?? item.description,
    thumbUrl: item.posterUrl,
    badge: ctx.text('badge') ?? item.badge,
    number: '${index + 1}',
    ratingLabel: item.rating?.toStringAsFixed(1),
  );

  static MangaVolumeItem _volume(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => MangaVolumeItem(
    title: item.title,
    author: ctx.text('subtitle'),
    tomeLabel: 'Tome ${index + 1}',
    ratingLabel: item.rating?.toStringAsFixed(1),
    metaLabel: item.badge,
    coverUrl: item.posterUrl,
    onTap: () {},
  );

  static List<MangaChapterItem> _chapters(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [for (var i = 0; i < items.length; i++) _chapter(ctx, items[i], i)];

  static List<MangaVolumeItem> _volumes(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [for (var i = 0; i < items.length; i++) _volume(ctx, items[i], i)];

  static List<EpisodeEntry> _episodes(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [for (var i = 0; i < items.length; i++) _episode(ctx, items[i], i)];

  static List<SeasonEntry> _seasons(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [for (final item in items) _season(ctx, item)];

  static List<RankingEntry> _rank(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      RankingEntry(
        title: items[i].title,
        meta: items[i].badge,
        rating: items[i].rating,
        rank: i + 1,
        thumbUrl: items[i].posterUrl,
      ),
  ];

  static List<CollectionEntry> _entries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      CollectionEntry(
        title: items[i].title,
        meta: items[i].badge,
        thumbUrl: items[i].posterUrl,
        rating: items[i].rating,
        rank: ctx.flag('numbered') ? i + 1 : null,
      ),
  ];

  static List<MangaGenreEntry> _genreEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      MangaGenreEntry(
        title: items[i].title,
        countLabel: ctx.flag('showCount', fallback: true)
            ? '${items[i].key.length + 3} titres'
            : null,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<MangaShowcaseEntry> _showcase(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      MangaShowcaseEntry(
        title: items[i].title,
        badge: items[i].badge,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<MangaTagEntry> _tags(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      MangaTagEntry(label: items[i].title, onTap: () => ctx.onOpen(i)),
  ];

  static List<MangaLangEntry> _langs(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (final item in items)
      MangaLangEntry(name: item.title, countLabel: item.badge),
  ];

  static List<MangaTeamEntry> _teams(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (final item in items)
      MangaTeamEntry(
        name: item.title,
        meta: item.badge,
        thumbUrl: item.posterUrl,
      ),
  ];

  static List<MangaStatusRow> _statusRows(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      MangaStatusRow(
        label: items[i].title,
        percentLabel: '${40 + i * 10}%',
        progress: (0.4 + i * 0.1).clamp(0.0, 1.0),
        color: Colors.blueAccent,
      ),
  ];

  static List<MangaPublisherEntry> _publishers(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (final item in items)
      MangaPublisherEntry(
        name: item.title,
        countLabel: item.badge,
        initial: item.title.isNotEmpty ? item.title[0] : '?',
        logoUrl: item.posterUrl,
      ),
  ];

  static List<MangaRelationEntry> _relations(List<ContentItem> items) => [
    for (final item in items)
      MangaRelationEntry(
        title: item.title,
        badge: item.badge,
        thumbUrl: item.posterUrl,
      ),
  ];

  static List<MangaRelationEntry> _relationEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      MangaRelationEntry(
        title: items[i].title,
        badge: items[i].badge,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<MangaUniversePoint> _points(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      MangaUniversePoint(
        year: '${2000 + i}',
        title: items[i].title,
        subtitle: items[i].badge,
        thumbUrl: items[i].posterUrl,
      ),
  ];

  static List<MangaStatTile> _statTiles(List<ContentItem> items) => [
    for (final item in items)
      MangaStatTile(
        value: '${item.title.length}',
        label: item.title,
        icon: Icons.insights_rounded,
      ),
  ];

  static List<MangaRankEntry> _rankEntries(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      MangaRankEntry(
        title: items[i].title,
        rank: i + 1,
        thumbUrl: items[i].posterUrl,
        ratingLabel: items[i].rating?.toStringAsFixed(1),
      ),
  ];

  static List<(String, String, IconData, Color)> _statusTuples(
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      (
        items[i].title,
        '${items[i].key.length}',
        Icons.circle,
        Colors.blueAccent,
      ),
  ];

  static List<(String, String, Color)> _freqTuples(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      (items[i].title, '${i + 1}/sem', Colors.deepPurpleAccent),
  ];

  static List<(IconData, String, String)> _statRows(List<ContentItem> items) =>
      [
        for (final item in items)
          (Icons.insights_rounded, item.title, '${item.title.length}'),
      ];

  static List<(String, String, String)> _editionRows(
    List<ContentItem> items,
  ) => [
    for (final item in items) (item.title, item.badge ?? 'VF', 'Disponible'),
  ];

  static List<(String, String)> _statPairs(List<ContentItem> items) => [
    for (final item in items) (item.title, '${item.key.length}'),
  ];

  static List<MangaBadgeSpec> _badges(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (final item in items)
      MangaBadgeSpec(item.title, Colors.blueAccent, Icons.bookmark_rounded),
  ];

  static List<MangaReaderPage> _pages(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      MangaReaderPage(label: '${i + 1}', url: items[i].posterUrl),
  ];

  static List<MangaReadingOption> _readingOptions(List<ContentItem> items) => [
    for (var i = 0; i < items.length; i++)
      MangaReadingOption(
        label: items[i].title,
        icon: Icons.chrome_reader_mode_outlined,
        selected: i == 0,
      ),
  ];

  static List<MangaSettingRow> _settingRows() => const [
    MangaSettingRow(
      label: 'Luminosité',
      value: 'Auto',
      icon: Icons.brightness_6_outlined,
    ),
    MangaSettingRow(
      label: 'Mode nuit',
      value: 'Oui',
      icon: Icons.dark_mode_outlined,
    ),
  ];

  static List<MangaQuickAction> _quickActions() => const [
    MangaQuickAction(label: 'Reprendre', icon: Icons.play_arrow_rounded),
    MangaQuickAction(label: 'Marquer lu', icon: Icons.check_rounded),
  ];

  static List<MangaReaderChapterRow> _chapterRows(List<ContentItem> items) => [
    for (final item in items)
      MangaReaderChapterRow(
        title: item.title,
        thumbUrl: item.posterUrl,
        onTap: () {},
      ),
  ];

  static List<MangaReaderHistoryEntry> _history(List<ContentItem> items) => [
    for (final item in items)
      MangaReaderHistoryEntry(
        title: item.title,
        subtitle: item.badge,
        percentLabel: '42%',
        progress: 0.42,
        thumbUrl: item.posterUrl,
      ),
  ];

  static List<StreamingEpisode> _streamEpisodes(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      StreamingEpisode(
        title: items[i].title,
        meta: items[i].badge,
        thumbUrl: items[i].posterUrl,
        isCurrent: i == 0,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<LandscapeEntry> _landscape(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      LandscapeEntry(
        title: items[i].title,
        genres: items[i].description,
        meta: items[i].badge,
        ratingLabel: items[i].rating?.toStringAsFixed(1),
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<LandscapePlaylist> _playlists(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      LandscapePlaylist(
        title: items[i].title,
        subtitle: items[i].description,
        countLabel: items[i].badge,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<LandscapeGenreTile> _genreTiles(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      LandscapeGenreTile(
        title: items[i].title,
        countLabel: items[i].badge,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<HomeSpotlightEntry> _spotlightEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      HomeSpotlightEntry(
        title: items[i].title,
        kindLabel: items[i].badge,
        ratingLabel: items[i].rating?.toStringAsFixed(1),
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<HomeGenreCardEntry> _genreCardEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      HomeGenreCardEntry(
        title: items[i].title,
        tagline: items[i].description,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<HomePopularEntry> _popularEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      HomePopularEntry(
        title: items[i].title,
        meta: items[i].badge,
        ratingLabel: items[i].rating?.toStringAsFixed(1),
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static List<HomeMyListEntry> _myListEntries(List<ContentItem> items) => [
    for (final item in items)
      HomeMyListEntry(title: item.title, thumbUrl: item.posterUrl),
  ];

  static List<HomeCountryChip> _countryChips(List<ContentItem> items) {
    const countryNames = <String, String>{
      'BR': 'Brésil',
      'CN': 'Chine',
      'DE': 'Allemagne',
      'ES': 'Espagne',
      'FR': 'France',
      'GB': 'Royaume-Uni',
      'IN': 'Inde',
      'IT': 'Italie',
      'JP': 'Japon',
      'KR': 'Corée du Sud',
      'US': 'États-Unis',
    };
    final seen = <String>{};
    final chips = <HomeCountryChip>[];
    for (final item in items) {
      final code = item.countryCode?.trim().toUpperCase();
      if (code == null || code.length != 2 || !seen.add(code)) continue;
      chips.add(
        HomeCountryChip(
          label: countryNames[code] ?? code,
          code: code,
        ),
      );
    }
    return chips;
  }

  static AnilistMedia _anilist(ContentItem item) => AnilistMedia(
    id: item.key.hashCode,
    type: 'ANIME',
    titleEnglish: item.title,
    coverLarge: item.posterUrl,
    coverExtraLarge: item.posterUrl,
    bannerImage: item.backdropUrl,
    description: item.description,
    averageScore: item.rating == null ? null : (item.rating! * 10).round(),
  );
}
