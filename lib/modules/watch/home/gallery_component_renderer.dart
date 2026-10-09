import 'package:flutter/material.dart';

import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/collection_cards.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/episode_cards.dart';
import 'package:watchtower/modules/media/manga_chapter_cards.dart';
import 'package:watchtower/modules/media/manga_genre_cards.dart';
import 'package:watchtower/modules/media/manga_reader_cards.dart';
import 'package:watchtower/modules/media/manga_stats_cards.dart';
import 'package:watchtower/modules/media/manga_universe_cards.dart';
import 'package:watchtower/modules/media/manga_volume_cards.dart';
import 'package:watchtower/modules/media/ranking_cards.dart';
import 'package:watchtower/modules/media/rich_media_cards.dart';
import 'package:watchtower/modules/media/streaming_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart'
    as manga_home;

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

  bool flag(String key, {bool fallback = false}) {
    final value = params[key];
    if (value is bool) return value;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
  }

  static GalleryComponentContext fromSection({
    required UiSection section,
    required List<ContentItem> items,
    required ValueChanged<int> onOpen,
    Color? accent,
    VoidCallback? onSeeAll,
  }) => GalleryComponentContext(
    componentId: section.component,
    items: items,
    onOpen: onOpen,
    title: section.title,
    accent: accent,
    params: section.params,
    onSeeAll: onSeeAll,
  );
}

/// Renders any gallery component from extension-home content.
///
/// The declarative layout JSON selects the component id; this class maps the
/// data to the exact widget the developer gallery previews
/// (`MovieDetailsCard`, `MangaChapterCard`, `TopMoviesCard`, …).
class GalleryComponentRenderer {
  GalleryComponentRenderer._();

  /// A single card (used by the grid renderer path).
  static Widget card(GalleryComponentContext ctx) {
    final items = limited(ctx);
    if (items.isEmpty) return const SizedBox.shrink();
    return _card(ctx, items, 0);
  }

  /// A horizontal rail of cards for the current component family.
  static Widget rail(GalleryComponentContext ctx) {
    final items = limited(ctx);
    if (items.isEmpty) return const SizedBox.shrink();
    final family = ctx.family ?? GalleryComponentFamily.posterRail;

    // These families are rendered as a single composite card.
    if (family == GalleryComponentFamily.mangaGenre) {
      return _band(ctx, MangaGenresCard(items: _genreEntries(ctx, items)));
    }
    if (family == GalleryComponentFamily.mangaStats) {
      return _band(ctx, MangaGlobalStatsCard(tiles: _tiles(items)));
    }
    if (family == GalleryComponentFamily.mangaUniverse) {
      return _band(ctx, MangaLinkedSeriesCard(items: _relations(items)));
    }
    if (family == GalleryComponentFamily.swipe) {
      return _band(ctx, _swipe(ctx, items));
    }
    // `manga-top3`, `manga-ranking` and `manga-trending-list` are composite
    // cards that consume the whole item list, so they bypass the rail.
    final composite = _mangaComposite(ctx, items);
    if (composite != null) return _band(ctx, composite);
    if (family == GalleryComponentFamily.mangaGenre &&
        ctx.componentId == 'manga-genre') {
      return _band(
        ctx,
        _rail([
          for (var i = 0; i < items.length; i++)
            manga_home.MangaGenreCard(
              label: items[i].title,
              imageUrl: items[i].posterUrl,
              onTap: () => ctx.onOpen(i),
            ),
        ]),
      );
    }

    return _band(
      ctx,
      _rail([
        for (var i = 0; i < items.length; i++) _card(ctx, items, i),
      ]),
    );
  }

  /// Full-width spotlight used by the extension renderer.
  static Widget spotlight(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
  ) => manga_home.MangaSpotlightCard(
    item: items[index],
    onTap: () => ctx.onOpen(index),
    height: ctx.number('height')?.toDouble() ?? 230,
  );

  /// Full-width banner used by the extension renderer.
  static Widget banner(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => manga_home.MangaBannerCard(item: item, onTap: () => ctx.onOpen(index));

  // ── Internals ───────────────────────────────────────────────────────────

  static List<ContentItem> limited(GalleryComponentContext ctx) {
    final limit = ctx.number('items');
    final items = ctx.items;
    if (limit == null || limit <= 0 || limit >= items.length) return items;
    return items.sublist(0, limit);
  }

  /// Selects the exact manga-home card for the requested component so
  /// `manga-featured`, `manga-resume`, `manga-banner`, `manga-top3`,
  /// `manga-ranking`, `manga-trending-list`, `manga-vote`,
  /// `manga-collection-showcase` and `manga-scan-group` each render their own
  /// widget instead of one generic card.
  static Widget _mangaHomeById(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int i,
  ) {
    final item = items[i];
    // The manga-home cards lay out at a fixed width (340 in the gallery),
    // so the rail keeps that exact geometry.
    Widget wrap(Widget child) => SizedBox(width: 340, child: child);
    switch (ctx.componentId) {
      case 'manga-resume':
        return wrap(
          manga_home.MangaResumeCard(
            item: item,
            subtitle: ctx.text('subtitle'),
            progress: 0.42,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-update-row':
        return wrap(
          manga_home.MangaUpdateRow(
            item: item,
            subtitle: item.badge,
            time: ctx.text('time'),
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-banner':
        return SizedBox(
          width: 320,
          child: manga_home.MangaBannerCard(
            item: item,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-spotlight':
        return SizedBox(
          width: 300,
          child: manga_home.MangaSpotlightCard(
            item: item,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-latest-update':
        return wrap(
          manga_home.MangaLatestUpdateCard(
            item: item,
            time: ctx.text('time'),
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-vote':
        return wrap(
          manga_home.MangaVoteCard(
            title: item.title,
            imageUrl: item.posterUrl,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-collection-showcase':
        return wrap(
          manga_home.MangaCollectionShowcaseCard(
            title: item.title,
            covers: [
              for (final entry in items.take(9)) entry.posterUrl ?? '',
            ],
            onTap: () => ctx.onOpen(i),
          ),
        );
      case 'manga-scan-group':
        return wrap(
          manga_home.MangaScanGroupCard(
            name: item.title,
            rank: i + 1,
            covers: [for (final entry in items.take(5)) entry.posterUrl ?? ''],
            onTap: () => ctx.onOpen(i),
          ),
        );
      default:
        return manga_home.MangaFeaturedCard(
          item: item,
          onTap: () => ctx.onOpen(i),
        );
    }
  }

  /// Composite manga family cards rendered as a single widget.
  static Widget? _mangaComposite(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) {
    final id = ctx.componentId;
    if (id == 'manga-top3') {
      return manga_home.MangaTop3Card(
        items: items.take(3).toList(growable: false),
        rank: 1,
        onTap: (_) {},
      );
    }
    if (id == 'manga-ranking') {
      return manga_home.MangaRankingCard(
        items: items,
        onOpen: (index) => ctx.onOpen(index),
      );
    }
    if (id == 'manga-trending-list') {
      final item = items.first;
      return manga_home.MangaTrendingListCard(
        title: item.title,
        author: item.badge ?? 'Auteur',
        rank: 1,
        covers: [for (final entry in items.take(6)) entry.posterUrl ?? ''],
        onTap: () => ctx.onOpen(0),
      );
    }
    return null;
  }


  static Widget _band(GalleryComponentContext ctx, Widget child) {
    final title = ctx.title ?? ctx.text('title');
    if (title == null || title.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  /// Cards size themselves, so the rail grows to the tallest one instead of
  /// clipping a card against a guessed height.
  static Widget _rail(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ],
    ),
  );

  static Widget _card(
    GalleryComponentContext ctx,
    List<ContentItem> items,
    int index,
  ) {
    final i = index.clamp(0, items.length - 1);
    final item = items[i];
    final family = ctx.family ?? GalleryComponentFamily.posterRail;
    switch (family) {
      case GalleryComponentFamily.richMedia:
        return MovieDetailsCard(
          data: RichMediaCardData(
            item: item,
            meta: item.badge,
            genres: item.description,
            onPlay: () => ctx.onOpen(i),
            onMore: () => ctx.onOpen(i),
          ),
        );
      case GalleryComponentFamily.streaming:
        return ContinueWatchingCard(
          data: StreamingCardData(
            item: item,
            badge: ctx.text('badge') ?? item.badge,
            progress: 0.4,
            onTap: () => ctx.onOpen(i),
            onPlay: () => ctx.onOpen(i),
          ),
        );
      case GalleryComponentFamily.collections:
        return CollectionCard(data: _collection(ctx, item, i));
      case GalleryComponentFamily.episodes:
        return EpisodePreviewCard(entry: _episode(item, i, ctx));
      case GalleryComponentFamily.ranking:
        return TopMoviesCard(items: _rankingEntries(ctx, items));
      case GalleryComponentFamily.mangaChapter:
        return MangaChapterCard(item: _mangaChapter(item, i));
      case GalleryComponentFamily.mangaVolume:
        return MangaVolumeCard(item: _volume(item, i));
      case GalleryComponentFamily.mangaReader:
        return MangaReaderCard(
          title: item.title,
          coverUrl: item.posterUrl,
          pageLabel: ctx.text('readingDirection'),
        );
      case GalleryComponentFamily.homeHero:
        return _mangaHomeById(ctx, items, i);
      case GalleryComponentFamily.ranked:
        return RankedCard(item: item, rank: i + 1, onTap: () => ctx.onOpen(i));
      case GalleryComponentFamily.landscape:
        return LandscapeCard(item: item, onTap: () => ctx.onOpen(i));
      case GalleryComponentFamily.banner:
        return SizedBox(
          width: 320,
          child: manga_home.MangaBannerCard(
            item: item,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case GalleryComponentFamily.spotlight:
        return SizedBox(
          width: 300,
          child: manga_home.MangaSpotlightCard(
            item: item,
            onTap: () => ctx.onOpen(i),
          ),
        );
      case GalleryComponentFamily.grid:
      case GalleryComponentFamily.posterRail:
      case GalleryComponentFamily.mangaGenre:
      case GalleryComponentFamily.mangaStats:
      case GalleryComponentFamily.mangaUniverse:
      case GalleryComponentFamily.swipe:
        return PosterCard(item: item, onTap: () => ctx.onOpen(i));
    }
  }

  static CollectionCardData _collection(
    GalleryComponentContext ctx,
    ContentItem item,
    int index,
  ) => CollectionCardData(
    item: item,
    subtitle: ctx.text('subtitle'),
    badge: ctx.text('badge') ?? item.badge,
    onTap: () => ctx.onOpen(index),
    onExplore: () => ctx.onOpen(index),
  );

  static EpisodeEntry _episode(
    ContentItem item,
    int index,
    GalleryComponentContext ctx,
  ) => EpisodeEntry(
    title: item.title,
    subtitle: item.description,
    number: index + 1,
    thumbUrl: item.backdropUrl ?? item.posterUrl,
    badge: ctx.text('badge') ?? item.badge,
    rating: item.rating,
    onTap: () => ctx.onOpen(index),
    onPlay: () => ctx.onOpen(index),
  );

  static List<RankingEntry> _rankingEntries(
    GalleryComponentContext ctx,
    List<ContentItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      RankingEntry(
        title: items[i].title,
        rating: items[i].rating,
        rank: i + 1,
        thumbUrl: items[i].posterUrl,
        onTap: () => ctx.onOpen(i),
      ),
  ];

  static MangaChapterItem _mangaChapter(ContentItem item, int index) =>
      MangaChapterItem(
        title: item.title,
        subtitle: item.badge,
        thumbUrl: item.posterUrl,
        number: '${index + 1}',
        badge: item.badge,
      );

  static MangaVolumeItem _volume(ContentItem item, int index) => MangaVolumeItem(
    title: item.title,
    coverUrl: item.posterUrl,
    tomeLabel: 'Tome ${index + 1}',
  );

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

  static List<MangaRelationEntry> _relations(List<ContentItem> items) => [
    for (final item in items)
      MangaRelationEntry(
        title: item.title,
        thumbUrl: item.posterUrl,
        badge: item.badge,
      ),
  ];

  static List<MangaStatTile> _tiles(List<ContentItem> items) => [
    for (final item in items)
      MangaStatTile(
        value: '${item.title.length}',
        label: item.title,
        icon: Icons.insights_rounded,
      ),
  ];

  static Widget _swipe(GalleryComponentContext ctx, List<ContentItem> items) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: PosterCard(
                  item: items[i],
                  width: 160,
                  onTap: () => ctx.onOpen(i),
                ),
              ),
          ],
        ),
      );
}
