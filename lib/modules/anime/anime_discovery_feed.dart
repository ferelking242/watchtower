import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/anime/anime_directory_screen.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/manga_genre_cards.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

/// AniList discovery feed. Every visual card is rendered by the same gallery
/// renderer used by WatchExtensionHomeScreen and the component gallery.
class AnimeDiscoveryFeed extends ConsumerStatefulWidget {
  const AnimeDiscoveryFeed({
    required this.home,
    required this.onRefresh,
    super.key,
  });

  final AnilistHome home;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<AnimeDiscoveryFeed> createState() => _AnimeDiscoveryFeedState();
}

class _AnimeDiscoveryFeedState extends ConsumerState<AnimeDiscoveryFeed> {
  AnilistHome get home => widget.home;
  String? _selectedGenre;

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
    int page = 1,
  }) => AnilistBrowseFilter(
    mediaType: 'ANIME',
    genre: genre,
    format: format,
    studioId: studioId,
    sort: sort,
    country: country,
    page: page,
  );

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
            item: ContentItem(
              key: 'anime-genre-${genre.label.toLowerCase()}',
              title: genre.label,
              posterUrl: genre.imageUrl,
              backdropUrl: genre.imageUrl,
              imageUrl: genre.imageUrl,
              badge: genre.label,
              coverUrls: [
                genre.imageUrl!,
                for (final media in home.allAnimes)
                  if (media.genres.any(
                    (candidate) =>
                        candidate.toLowerCase() ==
                        (genre.genre ?? genre.label).toLowerCase(),
                  ))
                    media.bestBackdrop ?? media.bestCover,
              ].whereType<String>().toSet().take(4).toList(growable: false),
            ),
          ),
    ];
  }

  List<_StudioSpotlight> _studioEntries() {
    final all = home.allAnimes;
    final result = <_StudioSpotlight>[];
    for (final studio in home.topStudios) {
      final productions = all
          .where((media) => media.studios.any((entry) => entry.id == studio.id))
          .toList(growable: false);
      final covers = productions
          .map((media) => media.bestBackdrop ?? media.bestCover)
          .whereType<String>()
          .toSet()
          .take(4)
          .toList(growable: false);
      if (covers.isEmpty) continue;
      result.add(
        _StudioSpotlight(
          studio: studio,
          item: ContentItem(
            key: 'anime-studio-${studio.id}',
            title: studio.name,
            posterUrl: covers.first,
            backdropUrl: covers.first,
            imageUrl: covers.first,
            logoUrl: studioBrandMarkUrl(studio.name),
            coverUrls: covers,
            badge: 'Studio',
            countryCode: productions.first.countryOfOrigin ?? 'JP',
            meta: studio.name,
          ),
        ),
      );
    }
    return result;
  }

  ContentItem _relationGroupItem(
    AnilistRelationGroup group, {
    required String groupLabel,
  }) {
    final relatedMedia = home.allAnimes
        .where((media) => group.mediaIds.contains(media.id))
        .toList(growable: false);
    final representative = relatedMedia.isEmpty ? null : relatedMedia.first;
    final image =
        group.representative.coverImage ??
        representative?.bestBackdrop ??
        representative?.bestCover;
    final coverUrls = [
      if (image != null) image,
      for (final media in relatedMedia)
        media.bestBackdrop ?? media.bestCover,
    ].whereType<String>().toSet().take(4).toList(growable: false);
    return ContentItem(
      key: 'anilist-$groupLabel-${group.mediaIds.join('-')}',
      title: group.representative.title,
      posterUrl: representative?.bestCover ?? image,
      backdropUrl: image,
      imageUrl: image,
      coverUrls: coverUrls,
      logoUrl: representative?.mainStudio == null
          ? null
          : studioBrandMarkUrl(representative!.mainStudio!),
      countryCode: representative?.countryOfOrigin,
      description:
          '${group.members.length} titres liés par les relations AniList.',
      badge: '${group.members.length} anime',
    );
  }

  void _browseRelationGroup(String title, AnilistRelationGroup group) {
    _browse(
      title,
      AnilistBrowseFilter(
        mediaType: 'ANIME',
        mediaIds: group.mediaIds,
        sort: 'POPULARITY_DESC',
      ),
    );
  }

  void _browseRelationGroups(
    String title,
    List<AnilistRelationGroup> groups,
  ) {
    final ids = groups.expand((group) => group.mediaIds).toSet().toList();
    if (ids.isEmpty) return;
    _browse(
      title,
      AnilistBrowseFilter(
        mediaType: 'ANIME',
        mediaIds: ids,
        sort: 'POPULARITY_DESC',
      ),
    );
  }

  List<ContentItem> _countryItems() {
    final usedArtwork = <String>{};
    return [
      for (final country in animeCountryOptions)
        _countryItem(country, home.allAnimes, usedArtwork),
    ];
  }

  ContentItem _countryItem(
    (String, String) country,
    List<AnilistMedia> all,
    Set<String> usedArtwork,
  ) {
    final matching = all
        .where((media) => media.countryOfOrigin?.toUpperCase() == country.$1)
        .toList(growable: false);
    AnilistMedia? representative;
    for (final media in [...matching, ...all]) {
      final image = media.bestBackdrop ?? media.bestCover;
      if (image != null && usedArtwork.add(image)) {
        representative = media;
        break;
      }
    }
    final image = representative?.bestBackdrop ?? representative?.bestCover;
    return ContentItem(
      key: 'anime-country-${country.$1}',
      title: country.$2,
      posterUrl: representative?.bestCover,
      backdropUrl: representative?.bestBackdrop,
      imageUrl: image,
      badge: 'Pays',
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
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              final covers = item.coverUrls.isNotEmpty
                  ? item.coverUrls
                  : [
                      item.imageUrl ?? item.backdropUrl ?? item.posterUrl,
                    ].whereType<String>().toList(growable: false);
              return AnimeDirectoryCard(
                title: item.title,
                coverUrls: covers,
                logoUrl: item.logoUrl,
                showLogo: item.badge == 'Studio',
                height: 84,
                onTap: () => onOpen(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _worldSection({
    required BuildContext context,
    required List<ContentItem> countries,
  }) {
    final pagePadding = AppUI.pagePadding(context);
    final previewCountries = countries.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Explorer le monde',
          actionLabel: 'Tout voir',
          onAction: () => context.push(
            '/animeDirectory',
            extra: AnimeDirectoryKind.countries,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pagePadding),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.42,
            ),
            itemCount: previewCountries.length,
            itemBuilder: (context, index) {
              final country = previewCountries[index];
              final code = country.countryCode;
              final cover = country.imageUrl ?? country.backdropUrl;
              return AnimeDirectoryCard(
                title: country.title,
                coverUrls: cover == null ? const [] : [cover],
                flag: code == null ? '🌍' : countryFlag(code),
                height: 80,
                onTap: () {
                  if (code != null) {
                    _browse(
                      'Anime · ${country.title}',
                      _filter(null, country: code),
                    );
                  }
                },
              );
            },
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
    final firstCataloguePage = ref.watch(
      anilistBrowseProvider(_filter(null, page: 1)),
    );
    final secondCataloguePage = ref.watch(
      anilistBrowseProvider(_filter(null, page: 2)),
    );
    final pageOneItems = firstCataloguePage.when(
      data: (page) => page.items,
      error: (_, _) => home.popularAnimes,
      loading: () => home.popularAnimes,
    );
    final pageTwoItems = secondCataloguePage.when(
      data: (page) => page.items,
      error: (_, _) => const <AnilistMedia>[],
      loading: () => const <AnilistMedia>[],
    );
    final seenCatalogueIds = <int>{};
    final catalogue = <AnilistMedia>[
      for (final media in [...pageOneItems, ...pageTwoItems])
        if (seenCatalogueIds.add(media.id) && seenCatalogueIds.length <= 60)
          media,
    ];
    final displayedCatalogue = _selectedGenre == null
        ? catalogue
        : catalogue
              .where(
                (media) => media.genres.any(
                  (genre) =>
                      genre.toLowerCase() == _selectedGenre!.toLowerCase(),
                ),
              )
              .toList(growable: false);
    final fullCardWidth =
        MediaQuery.sizeOf(context).width - AppUI.pagePadding(context) * 2;
    final studioEntries = _studioEntries();
    final studioItems = studioEntries
        .map((entry) => entry.item)
        .toList(growable: false);
    final franchiseGroups = buildAnilistFranchiseGroups(home.allAnimes);
    final collectionGroups = buildAnilistCollectionGroups(home.allAnimes);
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
          SliverToBoxAdapter(
            child: HeroCarousel(
              items: home.trendingAnimes.take(8).toList(growable: false),
              onItemTap: _open,
              topPadding: MediaQuery.paddingOf(context).top,
            ),
          ),
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
                'fill': true,
                'width': fullCardWidth,
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
              params: const {'width': 154, 'compact': true},
              onOpen: (index) {
                final genre =
                    genres[index].definition.genre ??
                    genres[index].definition.label;
                _browse(genre, _filter(genre));
              },
              onSeeAll: () => context.push(
                '/animeDirectory',
                extra: AnimeDirectoryKind.tags,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _gallerySection(
              componentId: 'movie-details',
              media: home.animeMovies.take(3).toList(growable: false),
              title: 'À découvrir',
              params: {'width': fullCardWidth, 'fill': true},
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
          if (collectionGroups.isNotEmpty)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'collection',
                items: [
                  for (final group in collectionGroups)
                    _relationGroupItem(group, groupLabel: 'collection'),
                ],
                title: 'Collections à découvrir',
                params: const {'width': 380},
                onOpen: (index) => _browseRelationGroup(
                  collectionGroups[index].representative.title,
                  collectionGroups[index],
                ),
                onSeeAll: () => _browseRelationGroups(
                  'Collections anime',
                  collectionGroups,
                ),
              ),
            ),
          if (franchiseGroups.isNotEmpty)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'franchise',
                items: [
                  for (final group in franchiseGroups)
                    _relationGroupItem(group, groupLabel: 'franchise'),
                ],
                title: 'Franchises cultes',
                params: {'width': fullCardWidth, 'fill': true, 'flat': true},
                onOpen: (index) => _browseRelationGroup(
                  franchiseGroups[index].representative.title,
                  franchiseGroups[index],
                ),
                onSeeAll: () => _browseRelationGroups(
                  'Franchises anime',
                  franchiseGroups,
                ),
              ),
            ),
          if (studioContent.isNotEmpty)
            SliverToBoxAdapter(
              child: _galleryItemsSection(
                componentId: 'studio',
                items: studioContent,
                title: 'Studio en vedette',
                params: {'width': fullCardWidth, 'fill': true, 'flat': true},
                onOpen: (_) => _browse(
                  studioEntries.first.studio.name,
                  studioFilter,
                ),
                onSeeAll: () => context.push(
                  '/animeDirectory',
                  extra: AnimeDirectoryKind.studios,
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
                onSeeAll: () => context.push(
                  '/animeDirectory',
                  extra: AnimeDirectoryKind.studios,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _galleryItemsSection(
              componentId: 'genre',
              items: featuredGenres,
              title: 'Genres en vedette',
              params: {'width': fullCardWidth, 'fill': true, 'flat': true},
              onOpen: (index) {
                final genre = genres[index].definition;
                _browse(
                  genre.label,
                  _filter(genre.genre ?? genre.label),
                );
              },
              onSeeAll: () => context.push(
                '/animeDirectory',
                extra: AnimeDirectoryKind.genres,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _twoRowGalleryGrid(
              context: context,
              title: 'Genres',
              items: genreItems,
              onOpen: (index) {
                if (index < genres.length) {
                  final genre =
                      genres[index].definition.genre ??
                      genres[index].definition.label;
                  _browse(genre, _filter(genre));
                }
              },
              onSeeAll: () => context.push(
                '/animeDirectory',
                extra: AnimeDirectoryKind.genres,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _worldSection(context: context, countries: countryItems),
          ),
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: 'Catalogue anime',
              actionLabel: 'Tout voir',
              onAction: () => _browse('Anime populaires', _filter(null)),
            ),
          ),
          if (genres.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.pagePadding(context),
              ),
              sliver: SliverToBoxAdapter(
                child: MangaTagsCard(
                  title: '',
                  width: fullCardWidth,
                  showHeader: false,
                  showPanel: false,
                  compact: true,
                  columns: 3,
                  tags: [
                    for (final entry in genres)
                      MangaTagEntry(
                        label: entry.definition.label,
                        imageUrl: entry.definition.imageUrl,
                        isSelected:
                            _selectedGenre ==
                            (entry.definition.genre ?? entry.definition.label),
                        onTap: () {
                          final selected =
                              entry.definition.genre ?? entry.definition.label;
                          setState(
                            () => _selectedGenre =
                                _selectedGenre == selected ? null : selected,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          if (displayedCatalogue.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.pagePadding(context),
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
                ),
                itemCount: displayedCatalogue.length,
                itemBuilder: (context, index) {
                  final media = displayedCatalogue[index];
                  final cardWidth =
                      (MediaQuery.sizeOf(context).width -
                          AppUI.pagePadding(context) * 2 -
                          20) /
                      3;
                  return GalleryComponentRenderer.card(
                    _context(
                      componentId: 'poster',
                      items: [ContentItem.fromAnilist(media)],
                      title: 'Catalogue anime',
                      params: {'width': cardWidth},
                      onOpen: (_) => _open(media),
                    ),
                  );
                },
              ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: AppHeroShimmer(height: heroHeight),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 118,
            child: _loadingCompositeRow(
              context,
              height: 190,
              cardWidth: 300,
            ),
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
        SliverToBoxAdapter(
          child: _AnimeLoadingSection(
            titleWidth: 118,
            child: _loadingCatalogueGrid(context),
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

  Widget _loadingCatalogueGrid(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
      ),
      itemCount: 9,
      itemBuilder: (_, _) =>
          const AppShimmerBlock(radius: AppUI.cardRadius),
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
