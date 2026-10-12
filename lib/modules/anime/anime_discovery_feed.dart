import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

/// AniList discovery feed. Every visual card is rendered by the same gallery
/// renderer used by WatchExtensionHomeScreen and the component gallery.
class AnimeDiscoveryFeed extends StatefulWidget {
  const AnimeDiscoveryFeed({
    required this.home,
    required this.onRefresh,
    super.key,
  });

  final AnilistHome home;
  final Future<void> Function() onRefresh;

  @override
  State<AnimeDiscoveryFeed> createState() => _AnimeDiscoveryFeedState();
}

class _AnimeDiscoveryFeedState extends State<AnimeDiscoveryFeed> {
  final _catalogueKey = GlobalKey();
  String? _selectedGenre;

  AnilistHome get home => widget.home;

  void _open(AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  void _browse(String title, AnilistBrowseFilter filter) {
    context.push('/anilistBrowse', extra: (filter, title));
  }

  AnilistBrowseFilter _filter(
    String? genre, {
    String? format,
    int? studioId,
    String? sort,
    String? country,
  }) => AnilistBrowseFilter(
    mediaType: 'ANIME',
    genre: genre,
    format: format,
    studioId: studioId,
    sort: sort,
    country: country,
  );

  void _selectGenre(String genre) {
    setState(() => _selectedGenre = genre);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _catalogueKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: .08,
        );
      }
    });
  }

  List<CategoryDef> get _genres =>
      enrichCategoryImages(animeCategories(), home.allAnimes);

  List<_GenreSpotlight> _genreChoices() {
    return [
      for (final genre in _genres)
        if (genre.imageUrl != null &&
            home.allAnimes.any(
              (media) => media.genres.any(
                (candidate) =>
                    candidate.toLowerCase() ==
                    (genre.genre ?? genre.label).toLowerCase(),
              ),
            ))
          _GenreSpotlight(
            definition: genre,
            item: ContentItem.genreTile(
              label: genre.label,
              imageUrl: genre.imageUrl,
              key: 'anime-genre-${genre.label.toLowerCase()}',
            ),
          ),
    ];
  }

  List<AnilistMedia> _mediaForGenre(String genre) => home.allAnimes
      .where(
        (media) => media.genres.any(
          (candidate) => candidate.toLowerCase() == genre.toLowerCase(),
        ),
      )
      .toList(growable: false);

  List<_StudioSpotlight> _studioEntries() {
    final all = home.allAnimes;
    final result = <_StudioSpotlight>[];
    for (final studio in home.topStudios) {
      final matching = all.where(
        (media) => media.studios.any((entry) => entry.id == studio.id),
      );
      for (final media in matching) {
        final image = media.bestBackdrop ?? media.bestCover;
        if (image == null) continue;
        result.add(
          _StudioSpotlight(
            studio: studio,
            item: ContentItem(
              key: 'anime-studio-${studio.id}',
              title: studio.name,
              posterUrl: image,
              backdropUrl: image,
              imageUrl: image,
              badge: 'Studio',
              meta: studio.name,
            ),
          ),
        );
        break;
      }
    }
    return result;
  }

  ContentItem? _popularCollection() {
    if (home.popularAnimes.isEmpty) return null;
    final media = home.popularAnimes.firstWhere(
      (entry) => entry.bestBackdrop != null || entry.bestCover != null,
      orElse: () => home.popularAnimes.first,
    );
    final image = media.bestBackdrop ?? media.bestCover;
    if (image == null) return null;
    return ContentItem(
      key: 'anime-collection-popular',
      title: 'Anime populaires',
      posterUrl: media.bestCover,
      backdropUrl: image,
      imageUrl: image,
      description: 'Une sélection des anime les plus populaires sur AniList.',
      badge: '${home.popularAnimes.length} titres',
    );
  }

  List<_FranchiseSpotlight> _franchises() {
    const franchises = <(String, String)>[
      ('Naruto', 'naruto'),
      ('Dragon Ball', 'dragon ball'),
      ('One Piece', 'one piece'),
      ('JoJo', 'jojo'),
    ];
    final all = home.allAnimes;
    final result = <_FranchiseSpotlight>[];
    for (final (label, query) in franchises) {
      final matches = all.where((media) {
        final searchable =
            '${media.titleEnglish ?? ''} ${media.titleRomaji ?? ''} '
                    '${media.titleNative ?? ''}'
                .toLowerCase();
        return searchable.contains(query) &&
            (media.bestCover != null || media.bestBackdrop != null);
      }).toList(growable: false);
      if (matches.isEmpty) continue;
      final lead = matches.first;
      result.add(
        _FranchiseSpotlight(
          media: lead,
          item: ContentItem(
            key: 'anime-franchise-${label.toLowerCase().replaceAll(' ', '-')}',
            title: '$label · Franchise',
            posterUrl: lead.bestCover,
            backdropUrl: lead.bestBackdrop,
            description: '${matches.length} titres dans cette sélection.',
            badge: '${matches.length} anime',
            rating: lead.averageScore == null
                ? null
                : lead.averageScore! / 10,
          ),
        ),
      );
    }
    return result;
  }

  List<ContentItem> _countryItems() {
    const countries = <(String, String)>[
      ('JP', 'Japon'),
      ('KR', 'Corée du Sud'),
      ('CN', 'Chine'),
      ('TW', 'Taïwan'),
      ('US', 'États-Unis'),
      ('FR', 'France'),
    ];
    final all = home.allAnimes;
    final presentCodes = all
        .map((media) => media.countryOfOrigin?.toUpperCase())
        .whereType<String>()
        .toSet();
    return [
      for (final country in countries)
        if (presentCodes.contains(country.$1) &&
            all.any(
              (media) =>
                  media.countryOfOrigin?.toUpperCase() == country.$1 &&
                  (media.bestBackdrop != null || media.bestCover != null),
            ))
          _countryItem(country, all),
    ];
  }

  ContentItem _countryItem((String, String) country, List<AnilistMedia> all) {
    final representative = all.firstWhere(
      (media) =>
          media.countryOfOrigin?.toUpperCase() == country.$1 &&
          (media.bestBackdrop != null || media.bestCover != null),
    );
    final image = representative.bestBackdrop ?? representative.bestCover;
    return ContentItem(
      key: 'anime-country-${country.$1}',
      title: country.$2,
      posterUrl: representative.bestCover,
      backdropUrl: representative.bestBackdrop,
      imageUrl: image,
      badge: country.$2,
      countryCode: country.$1,
    );
  }

  GalleryComponentContext _context({
    required String componentId,
    required List<ContentItem> items,
    required String title,
    required ValueChanged<int> onOpen,
    Map<String, dynamic> params = const {},
    VoidCallback? onSeeAll,
  }) => GalleryComponentContext(
    componentId: componentId,
    items: items,
    title: title,
    params: params,
    onOpen: onOpen,
    onSeeAll: onSeeAll,
  );

  Widget _gallerySection({
    required String componentId,
    required List<AnilistMedia> media,
    required String title,
    required ValueChanged<AnilistMedia> onOpen,
    Map<String, dynamic> params = const {},
    VoidCallback? onSeeAll,
  }) {
    if (media.isEmpty) return const SizedBox.shrink();
    final items = media.map(ContentItem.fromAnilist).toList(growable: false);
    return _galleryItemsSection(
      componentId: componentId,
      items: items,
      title: title,
      onOpen: (index) => onOpen(media[index]),
      params: params,
      onSeeAll: onSeeAll,
    );
  }

  Widget _galleryItemsSection({
    required String componentId,
    required List<ContentItem> items,
    required String title,
    required ValueChanged<int> onOpen,
    Map<String, dynamic> params = const {},
    VoidCallback? onSeeAll,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GalleryComponentRenderer.section(
      _context(
        componentId: componentId,
        items: items,
        title: title,
        params: params,
        onOpen: onOpen,
        onSeeAll: onSeeAll,
      ),
    );
  }

  Widget _spotlightCarousel(BuildContext context) {
    final items = home.trendingAnimes.take(6).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final height = ((width - AppUI.pagePadding(context) * 2) / 2.5)
        .clamp(150.0, 220.0)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'À la une'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: AppCrossfadeCarousel(
              itemCount: items.length,
              clipRadius: 18,
              itemBuilder: (context, index) {
                final media = items[index];
                return SizedBox.expand(
                  child: GalleryComponentRenderer.card(
                    _context(
                      componentId: 'spotlight-discovery',
                      items: [ContentItem.fromAnilist(media)],
                      title: 'À la une',
                      onOpen: (_) => _open(media),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _twoRowGalleryGrid({
    required BuildContext context,
    required String title,
    required List<ContentItem> items,
    required ValueChanged<int> onOpen,
    required VoidCallback onSeeAll,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final pagePadding = AppUI.pagePadding(context);
    final visibleItems = items.take(8).toList(growable: false);
    final tileWidth = math
        .min(184.0, (MediaQuery.sizeOf(context).width - 48) / 2)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'Tout voir',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 188,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: pagePadding),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: tileWidth,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
            ),
            itemCount: visibleItems.length,
            itemBuilder: (context, index) => Center(
              child: GalleryComponentRenderer.card(
                _context(
                  componentId: 'app-genre-tile',
                  items: [visibleItems[index]],
                  title: title,
                  params: {'width': tileWidth, 'height': 84},
                  onOpen: (_) => onOpen(index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final genres = _genreChoices();
    final genreItems = genres.map((entry) => entry.item).toList();
    final countryItems = _countryItems();
    final featuredGenres = genreItems.take(4).toList(growable: false);
    final selected = _selectedGenre;
    final catalogue = selected == null
        ? home.popularAnimes.take(15).toList(growable: false)
        : _mediaForGenre(selected);
    final studioEntries = _studioEntries();
    final studioItems = studioEntries
        .map((entry) => entry.item)
        .toList(growable: false);
    final franchiseEntries = _franchises();
    final popularCollection = _popularCollection();
    final studioFilter = studioEntries.isEmpty
        ? _filter(null)
        : _filter(null, studioId: studioEntries.first.studio.id);
    final studioContent = studioItems.isEmpty
        ? const <ContentItem>[]
        : [studioItems.first];

    return ExtensionAppleRefreshable(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _spotlightCarousel(context)),
          SliverToBoxAdapter(
            child: _gallerySection(
              componentId: 'top-anime',
              media: home.topRatedAnimes.take(10).toList(growable: false),
              title: 'Top 10 Anime',
              params: {
                'title': 'Top 10 Anime',
                'subtitle': 'Les mieux notés sur AniList',
                'flat': true,
                'width': math
                    .min(
                      430.0,
                      MediaQuery.sizeOf(context).width -
                          AppUI.pagePadding(context) * 2,
                    )
                    .toDouble(),
              },
              onOpen: _open,
              onSeeAll: () => _browse(
                'Top Anime',
                _filter(null, sort: 'SCORE_DESC'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _galleryItemsSection(
              componentId: 'tag',
              items: genreItems.take(8).toList(growable: false),
              title: 'Explorer par tags',
              params: const {'width': 188},
              onOpen: (index) => _selectGenre(
                genres[index].definition.genre ??
                    genres[index].definition.label,
              ),
              onSeeAll: () => _browse('Tous les anime', _filter(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: _gallerySection(
              componentId: 'movie-details',
              media: home.animeMovies.take(3).toList(growable: false),
              title: 'Films à découvrir',
              params: const {'width': 320},
              onOpen: _open,
              onSeeAll: () => _browse(
                'Films anime',
                _filter(null, format: 'MOVIE'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _gallerySection(
              componentId: 'poster',
              media: home.trendingAnimes,
              title: 'Tendances',
              params: const {'width': 112},
              onOpen: _open,
              onSeeAll: () => _browse(
                'Tendances',
                _filter(null, sort: 'TRENDING_DESC'),
              ),
            ),
          ),
          if (popularCollection != null)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'collection',
                items: [popularCollection],
                title: 'Collections à découvrir',
                params: const {'width': 380},
                onOpen: (_) => _browse('Anime populaires', _filter(null)),
                onSeeAll: () => _browse('Anime populaires', _filter(null)),
              ),
            ),
          if (franchiseEntries.isNotEmpty)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'franchise',
                items: franchiseEntries.map((entry) => entry.item).toList(),
                title: 'Franchises cultes',
                params: const {'width': 380},
                onOpen: (index) => _open(franchiseEntries[index].media),
                onSeeAll: () => _browse('Franchises anime', _filter(null)),
              ),
            ),
          if (studioContent.isNotEmpty)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'studio',
                items: studioContent,
                title: 'Studio en vedette',
                params: const {'width': 380},
                onOpen: (_) => _browse(
                  studioEntries.first.studio.name,
                  studioFilter,
                ),
                onSeeAll: () => _browse(
                  studioEntries.first.studio.name,
                  studioFilter,
                ),
              ),
            ),
          if (studioItems.isNotEmpty)
            SliverToBoxAdapter(
              child: _twoRowGalleryGrid(
                context: context,
                title: 'Studios populaires',
                items: studioItems,
                onOpen: (index) {
                  final studio = studioEntries[index].studio;
                  _browse(
                    studio.name,
                    _filter(null, studioId: studio.id),
                  );
                },
                onSeeAll: () => _browse('Anime populaires', _filter(null)),
              ),
            ),
          SliverToBoxAdapter(
            child: _galleryItemsSection(
              componentId: 'genre',
              items: featuredGenres,
              title: 'Genres en vedette',
              params: const {'width': 360},
              onOpen: (index) {
                final genre = genres[index].definition;
                _browse(
                  genre.label,
                  _filter(genre.genre ?? genre.label),
                );
              },
              onSeeAll: () => _browse('Tous les anime', _filter(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: _twoRowGalleryGrid(
              context: context,
              title: 'Genres',
              items: genreItems,
              onOpen: (index) {
                if (index < genres.length) {
                  _selectGenre(
                    genres[index].definition.genre ??
                        genres[index].definition.label,
                  );
                }
              },
              onSeeAll: () => _browse('Tous les anime', _filter(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: _galleryItemsSection(
              componentId: 'home-language-grid',
              items: countryItems,
              title: 'Explorer le monde',
              params: {
                'width': MediaQuery.sizeOf(context).width -
                    AppUI.pagePadding(context) * 2,
                'fill': true,
              },
              onOpen: (index) {
                final country = countryItems[index].countryCode;
                if (country != null) {
                  _browse(
                    'Anime · $country',
                    _filter(null, country: country),
                  );
                }
              },
              onSeeAll: () => _browse('Anime du monde', _filter(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: _galleryItemsSection(
              componentId: 'manga-tags',
              items: genreItems,
              title: 'Genres et tags',
              params: {
                'width': MediaQuery.sizeOf(context).width -
                    AppUI.pagePadding(context) * 2,
                'fill': true,
              },
              onOpen: (index) => _selectGenre(
                genres[index].definition.genre ??
                    genres[index].definition.label,
              ),
              onSeeAll: () => _browse('Tous les anime', _filter(null)),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _catalogueKey,
              child: _gallerySection(
                componentId: 'poster',
                media: catalogue,
                title: selected == null
                    ? 'Catalogue anime'
                    : 'Anime · $selected',
                params: const {'width': 112},
                onOpen: _open,
                onSeeAll: () => _browse(
                  selected == null ? 'Anime populaires' : selected,
                  selected == null
                      ? _filter(null)
                      : _filter(selected),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _FranchiseSpotlight {
  const _FranchiseSpotlight({required this.media, required this.item});

  final AnilistMedia media;
  final ContentItem item;
}

class _StudioSpotlight {
  const _StudioSpotlight({required this.studio, required this.item});

  final AnilistStudio studio;
  final ContentItem item;
}

class _GenreSpotlight {
  const _GenreSpotlight({required this.definition, required this.item});

  final CategoryDef definition;
  final ContentItem item;
}

/// Initial screen shimmer uses the same shared shimmer primitives and spacing
/// as the Watch extension home, and follows the real discovery feed structure.
class AnimeDiscoveryLoadingScreen extends StatelessWidget {
  const AnimeDiscoveryLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = ((width - AppUI.pagePadding(context) * 2) / 2.5)
        .clamp(150.0, 220.0)
        .toDouble();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(title: 'À la une'),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppUI.pagePadding(context),
                ),
                child: SizedBox(
                  height: heroHeight,
                  width: double.infinity,
                  child: AppHeroShimmer(height: heroHeight),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 142,
            child: const SizedBox(height: 210, child: AppRankedRowShimmer()),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 156,
            child: const SizedBox(
              height: 220,
              child: AppMediaRowShimmer(itemWidth: 188),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 130,
            child: _loadingCompositeRow(
              context,
              height: 190,
              cardWidth: 320,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 120,
            child: const SizedBox(height: 220, child: AppMediaRowShimmer()),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 132,
            child: _loadingCompositeRow(
              context,
              height: 176,
              cardWidth: 320,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 144,
            child: _loadingCompositeRow(
              context,
              height: 176,
              cardWidth: 320,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 124,
            child: _loadingCompositeRow(
              context,
              height: 164,
              cardWidth: 320,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _loadingGrid(context, 'Studios populaires')),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 128,
            child: _loadingCompositeRow(
              context,
              height: 176,
              cardWidth: 320,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _loadingGrid(context, 'Genres')),
        SliverToBoxAdapter(
          child: _loadingCountryGrid(context),
        ),
        SliverToBoxAdapter(child: _loadingTags(context, 'Genres et tags')),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 118,
            child: const SizedBox(height: 220, child: AppMediaRowShimmer()),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _loadingGrid(BuildContext context, String title) =>
      _AnimeLoadingSection(
        titleWidth: (title.length * 8).clamp(86, 180).toDouble(),
        child: SizedBox(
          height: 188,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 160,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
            ),
            itemCount: 8,
            itemBuilder: (_, _) => const AppGenreTileShimmer(),
          ),
        ),
      );

  Widget _loadingCompositeRow(
    BuildContext context, {
    required double height,
    required double cardWidth,
  }) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => SizedBox(
        width: cardWidth,
        child: const AppShimmerBlock(radius: 18),
      ),
    ),
  );

  Widget _loadingCountryGrid(BuildContext context) => _AnimeLoadingSection(
    titleWidth: 150,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.pagePadding(context),
      ).copyWith(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          6,
          (_) => SizedBox(
            width: (MediaQuery.sizeOf(context).width -
                    AppUI.pagePadding(context) * 2 -
                    36) /
                2,
            height: 82,
            child: const AppShimmerBlock(radius: 11),
          ),
        ),
      ),
    ),
  );

  Widget _loadingTags(BuildContext context, String title) =>
      _AnimeLoadingSection(
        titleWidth: (title.length * 8).clamp(86, 180).toDouble(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppUI.pagePadding(context),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              10,
              (index) => SizedBox(
                width: 88 + (index % 3) * 16,
                height: 30,
                child: const AppShimmerBlock(radius: 16),
              ),
            ),
          ),
        ),
      );
}

class _AnimeLoadingSection extends StatelessWidget {
  const _AnimeLoadingSection({
    required this.titleWidth,
    required this.child,
  });

  final double titleWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
          child: SizedBox(
            width: titleWidth,
            height: 16,
            child: const AppShimmerBlock(radius: 5),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
