import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/hero_carousel.dart';
import 'package:watchtower/modules/home/widgets/skeleton_home.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';

/// Anime tab — AniList-powered discover page (trending, popular, upcoming…).
///
/// Sections are built from the same shared gallery components the rest of the
/// app uses ([GalleryComponentRenderer]) so the catalogue stays a single
/// source of truth, and every rail gets a working "see all" that opens the
/// shared catalogue page (`/anilistBrowse`) — the same destination the film
/// and série hubs already use.
class AnimeDiscoveryScreen extends ConsumerWidget {
  const AnimeDiscoveryScreen({super.key});

  void _openDetail(BuildContext context, AnilistMedia media) {
    context.push('/anilistDetail', extra: media);
  }

  AnilistBrowseFilter _filter(
    String? genre, {
    String? format,
    int? studioId,
    String? sort,
  }) => AnilistBrowseFilter(
    mediaType: 'ANIME',
    genre: genre,
    format: format,
    studioId: studioId,
    sort: sort,
  );

  /// Banner artwork of the best anime of a studio, used as the studio tile.
  String? _studioImage(AnilistHome home, String studio) {
    for (final media in home.allAnimes) {
      if (media.mainStudio == studio) return media.bestBackdrop;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: asyncHome.when(
          loading: () => const SkeletonHomeScreen(),
          error: (e, _) => AniListErrorView(
            error: e,
            onRetry: () => ref.invalidate(anilistHomeProvider),
          ),
          data: (home) => _AnimeBody(
            home: home,
            onRefresh: () async {
              ref.invalidate(anilistHomeProvider);
              await ref.read(anilistHomeProvider.future);
            },
            onOpen: (media) => _openDetail(context, media),
            onBrowse: (title, filter) =>
                context.push('/anilistBrowse', extra: (filter, title)),
            filterFor: _filter,
            studioImage: (studio) => _studioImage(home, studio),
          ),
        ),
      ),
    );
  }
}

class _AnimeBody extends StatelessWidget {
  final AnilistHome home;
  final Future<void> Function() onRefresh;
  final void Function(AnilistMedia) onOpen;
  final void Function(String, AnilistBrowseFilter) onBrowse;
  final AnilistBrowseFilter Function(
    String? genre, {
    String? format,
    int? studioId,
    String? sort,
  })
  filterFor;
  final String? Function(String) studioImage;

  const _AnimeBody({
    required this.home,
    required this.onRefresh,
    required this.onOpen,
    required this.onBrowse,
    required this.filterFor,
    required this.studioImage,
  });

  @override
  Widget build(BuildContext context) {
    final genres = animeCategories();
    final studios = home.topStudios;

    return Stack(
      children: [
        ExtensionAppleRefreshable(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              // Keep the hero fixed while pulling to refresh: the custom
              // indicator paints above the feed instead of displacing it.
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: HeroCarousel(
                  items: home.trendingAnimes.take(8).toList(),
                  onItemTap: onOpen,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Genres — shared gallery component, real artwork per tile.
                    if (genres.isNotEmpty)
                      _GenreGrid(
                        genres: genres,
                        media: home.allAnimes,
                        onBrowse: onBrowse,
                        filterFor: filterFor,
                      ),

                    // Top ranked — shared "top-anime" ranking panel.
                    if (home.topRatedAnimes.isNotEmpty)
                      _SharedSection(
                        componentId: 'top-anime',
                        title: 'Top 10 Anime',
                        items: home.topRatedAnimes.take(10).toList(),
                        params: const {'subtitle': 'Les mieux notés sur AniList'},
                        onOpen: onOpen,
                        onSeeAll: () => onBrowse(
                          'Top Anime',
                          filterFor(null, sort: 'SCORE_DESC'),
                        ),
                      ),

                    _AnimeRow(
                      title: 'Tendances',
                      items: home.trendingAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Tendances',
                        filterFor(null, sort: 'TRENDING_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Populaires',
                      items: home.popularAnimes,
                      onOpen: onOpen,
                      onSeeAll: () =>
                          onBrowse('Anime populaires', filterFor(null)),
                    ),
                    _AnimeRow(
                      title: 'En diffusion',
                      items: home.airingAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'En diffusion',
                        filterFor(null, sort: 'POPULARITY_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Coups de cœur',
                      items: home.favouriteAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Coups de cœur',
                        filterFor(null, sort: 'FAVOURITES_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Mieux notés',
                      items: home.topRatedAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Mieux notés',
                        filterFor(null, sort: 'SCORE_DESC'),
                      ),
                    ),
                    _AnimeLandscapeRow(
                      title: 'Films populaires',
                      items: home.animeMovies,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Films populaires',
                        filterFor(null, format: 'MOVIE'),
                      ),
                    ),
                    _AnimeLandscapeRow(
                      title: 'Films les mieux notés',
                      items: home.topMovies,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Films les mieux notés',
                        filterFor(null, format: 'MOVIE', sort: 'SCORE_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Sorties récentes',
                      items: home.recentAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Sorties récentes',
                        filterFor(null, sort: 'START_DATE_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Prochainement',
                      items: home.upcomingAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse(
                        'Prochainement',
                        filterFor(null, sort: 'POPULARITY_DESC'),
                      ),
                    ),
                    _AnimeRow(
                      title: 'Longues séries',
                      items: home.longRunningAnimes,
                      onOpen: onOpen,
                      onSeeAll: () => onBrowse('Longues séries', filterFor(null)),
                    ),

                    // Studios — shared "app-genre-tile" component + studioId.
                    if (studios.isNotEmpty)
                      _StudioGrid(
                        studios: studios,
                        imageFor: studioImage,
                        onBrowse: onBrowse,
                        filterFor: filterFor,
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Genre tiles rendered through the shared [GalleryComponentRenderer] so the
/// gallery component and the production page stay identical.
class _GenreGrid extends StatelessWidget {
  final List<CategoryDef> genres;
  final List<AnilistMedia> media;
  final void Function(String, AnilistBrowseFilter) onBrowse;
  final AnilistBrowseFilter Function(
    String? genre, {
    String? format,
    int? studioId,
    String? sort,
  })
  filterFor;

  const _GenreGrid({
    required this.genres,
    required this.media,
    required this.onBrowse,
    required this.filterFor,
  });

  String? _artworkFor(CategoryDef genre) {
    final label = genre.genre?.toLowerCase();
    for (final item in media) {
      if (item.bestBackdrop == null) continue;
      if (label != null && item.genres.any((g) => g.toLowerCase() == label)) {
        return item.bestBackdrop;
      }
    }
    return media.isEmpty ? null : media.first.bestBackdrop;
  }

  @override
  Widget build(BuildContext context) {
    final items = <ContentItem>[
      for (final genre in genres)
        ContentItem.genreTile(
          label: genre.label,
          imageUrl: _artworkFor(genre),
        ),
    ];
    final ctx = GalleryComponentContext(
      componentId: 'app-genre-tile',
      items: items,
      title: 'Genres',
      params: const {'layout': 'grid', 'columns': 2, 'height': 84},
      onOpen: (index) {
        final genre = genres[index];
        onBrowse(genre.label, filterFor(genre.genre ?? genre.label));
      },
    );
    return GalleryComponentRenderer.section(ctx);
  }
}

/// Studio tiles rendered through the shared renderer, opening the catalogue
/// filtered by the studio id.
class _StudioGrid extends StatelessWidget {
  final List<AnilistStudio> studios;
  final String? Function(String) imageFor;
  final void Function(String, AnilistBrowseFilter) onBrowse;
  final AnilistBrowseFilter Function(
    String? genre, {
    String? format,
    int? studioId,
    String? sort,
  })
  filterFor;

  const _StudioGrid({
    required this.studios,
    required this.imageFor,
    required this.onBrowse,
    required this.filterFor,
  });

  @override
  Widget build(BuildContext context) {
    final items = <ContentItem>[
      for (final studio in studios)
        ContentItem.genreTile(
          label: studio.name,
          imageUrl: imageFor(studio.name),
          key: 'studio-${studio.id}',
        ),
    ];
    final ctx = GalleryComponentContext(
      componentId: 'app-genre-tile',
      items: items,
      title: 'Studios',
      params: const {'layout': 'grid', 'columns': 2, 'height': 84},
      onOpen: (index) {
        final studio = studios[index];
        onBrowse(studio.name, filterFor(null, studioId: studio.id));
      },
    );
    return GalleryComponentRenderer.section(ctx);
  }
}

/// Renders one shared whole-section card (e.g. the `top-anime` ranking panel).
class _SharedSection extends StatelessWidget {
  final String componentId;
  final String title;
  final List<AnilistMedia> items;
  final Map<String, dynamic> params;
  final void Function(AnilistMedia) onOpen;
  final VoidCallback onSeeAll;

  const _SharedSection({
    required this.componentId,
    required this.title,
    required this.items,
    this.params = const {},
    required this.onOpen,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = GalleryComponentContext(
      componentId: componentId,
      items: items.map(ContentItem.fromAnilist).toList(growable: false),
      title: title,
      params: params,
      onOpen: (index) => onOpen(items[index]),
      onSeeAll: onSeeAll,
    );
    return GalleryComponentRenderer.section(ctx);
  }
}

class _AnimeRow extends StatelessWidget {
  final String title;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onOpen;
  final VoidCallback onSeeAll;

  const _AnimeRow({
    required this.title,
    required this.items,
    required this.onOpen,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return DiscoveryRow(
      title: title,
      items: items,
      onItemTap: onOpen,
      onSeeAll: onSeeAll,
    );
  }
}

/// Landscape rail used for movies — renders the shared `landscape` component.
class _AnimeLandscapeRow extends StatelessWidget {
  final String title;
  final List<AnilistMedia> items;
  final void Function(AnilistMedia) onOpen;
  final VoidCallback onSeeAll;

  const _AnimeLandscapeRow({
    required this.title,
    required this.items,
    required this.onOpen,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ctx = GalleryComponentContext(
      componentId: 'landscape',
      items: items.map(ContentItem.fromAnilist).toList(growable: false),
      title: title,
      params: const {'width': 220},
      onOpen: (index) => onOpen(items[index]),
      onSeeAll: onSeeAll,
    );
    return GalleryComponentRenderer.section(ctx);
  }
}

class AniListErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const AniListErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = error.toString().toLowerCase();
    final isNet =
        msg.contains('socket') ||
        msg.contains('failed host') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection');
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNet ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              isNet ? 'No internet connection' : 'Could not reach AniList',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isNet
                  ? 'Check your Wi-Fi or mobile data and try again.'
                  : 'AniList is unreachable right now. It may be down or rate-limiting.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
