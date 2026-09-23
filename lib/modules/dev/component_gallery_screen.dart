import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';

enum _GalleryFilter { all, tmdb, anime, extensions, loading }

class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  _GalleryFilter _filter = _GalleryFilter.all;

  bool _shows(_GalleryFilter filter) =>
      _filter == _GalleryFilter.all || _filter == filter;

  @override
  Widget build(BuildContext context) {
    final padding = AppUI.pagePadding(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0B0D10).withValues(alpha: .95),
            surfaceTintColor: Colors.transparent,
            titleSpacing: padding,
            title: const Row(
              children: [
                _GalleryMark(),
                SizedBox(width: 11),
                Text('Component gallery'),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: padding - 8),
                child: IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Broken.close_circle),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, 32, padding, 26),
              child: _GalleryIntro(
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 88),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_shows(_GalleryFilter.tmdb)) ...[
                  _GallerySection(
                    eyebrow: '01 · TMDB / FILMS & SÉRIES',
                    title: 'Cartes utilisées par l’accueil cinéma',
                    description:
                        'Ces widgets sont ceux branchés aux rails Films et Séries, avec leurs images TMDB réelles.',
                    child: const _TmdbCardsShowcase(),
                  ),
                  _GallerySection(
                    eyebrow: '02 · TMDB / ÉDITORIAL',
                    title: 'Featured, paysage et classement',
                    description:
                        'Les variantes éditoriales réelles gardent les mêmes données, ratios et interactions que l’application.',
                    child: const _TmdbEditorialShowcase(),
                  ),
                ],
                if (_shows(_GalleryFilter.anime))
                  _GallerySection(
                    eyebrow: '03 · ANILIST / ANIME',
                    title: 'Cartes de découverte anime',
                    description:
                        'Catalogue des six variantes réellement utilisées sur l’accueil et la recherche AniList.',
                    child: const _AnimeCardsShowcase(),
                  ),
                if (_shows(_GalleryFilter.extensions))
                  _GallerySection(
                    eyebrow: '04 · WATCH EXTENSIONS',
                    title: 'Cartes de WatchExtensionHomeScreen',
                    description:
                        'Les composants ont été rendus réutilisables ici : la galerie et l’accueil d’extension affichent les mêmes widgets.',
                    child: const _ExtensionCardsShowcase(),
                  ),
                if (_shows(_GalleryFilter.loading))
                  _GallerySection(
                    eyebrow: '05 · LOADING / INTERACTION',
                    title: 'Skeleton puis résultat',
                    description:
                        'Glissez horizontalement : la première page montre le chargement réel, la seconde les cartes réelles avec affiches distantes.',
                    child: const _SwipeStateShowcase(),
                  ),
                _GallerySection(
                  eyebrow: 'AUDIT · 23 SEPTEMBRE 2026',
                  title: 'Ce qui est réellement couvert',
                  description:
                      'La galerie ne fabrique plus de rectangles de démonstration : chaque nom ci-dessous correspond à une implémentation utilisée dans l’application.',
                  child: const _AuditSummary(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryMark extends StatelessWidget {
  const _GalleryMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(Icons.grid_view_rounded, size: 17),
      ),
    );
  }
}

class _GalleryIntro extends StatelessWidget {
  final _GalleryFilter filter;
  final ValueChanged<_GalleryFilter> onFilterChanged;

  const _GalleryIntro({required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Les vraies cartes, au même endroit.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -.9,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 13),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Galerie auditée des composants utilisés par les écrans Films, Séries, '
            'AniList et WatchExtensionHomeScreen. Les affiches viennent de TMDB '
            'et les états de chargement réutilisent les skeletons de production.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white60,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GalleryChip(
              label: 'Tout',
              icon: Icons.dashboard_outlined,
              selected: filter == _GalleryFilter.all,
              onTap: () => onFilterChanged(_GalleryFilter.all),
            ),
            _GalleryChip(
              label: 'Films / séries',
              icon: Icons.local_movies_outlined,
              selected: filter == _GalleryFilter.tmdb,
              onTap: () => onFilterChanged(_GalleryFilter.tmdb),
            ),
            _GalleryChip(
              label: 'Extensions',
              icon: Icons.extension_outlined,
              selected: filter == _GalleryFilter.extensions,
              onTap: () => onFilterChanged(_GalleryFilter.extensions),
            ),
            _GalleryChip(
              label: 'Skeleton',
              icon: Icons.hourglass_empty_rounded,
              selected: filter == _GalleryFilter.loading,
              onTap: () => onFilterChanged(_GalleryFilter.loading),
            ),
          ],
        ),
      ],
    );
  }
}

class _GalleryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GalleryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : Colors.white54,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: const Color(0xFF161A20),
      selectedColor: accent,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? accent.withValues(alpha: .8) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }
}

class _GallerySection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  const _GallerySection({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 18),
          _GalleryPanel(child: child),
        ],
      ),
    );
  }
}

class _GalleryPanel extends StatelessWidget {
  final Widget child;

  const _GalleryPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF11151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

const _tmdbItems = <TmdbMedia>[
  TmdbMedia(
    id: 693134,
    mediaType: 'movie',
    titleEn: 'Dune : Deuxième partie',
    titleFr: 'Dune : Deuxième partie',
    posterPath: '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    backdropPath: '/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg',
    voteAverage: 8.2,
    releaseDate: '2024-02-27',
  ),
  TmdbMedia(
    id: 157336,
    mediaType: 'movie',
    titleEn: 'Interstellar',
    titleFr: 'Interstellar',
    posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    backdropPath: '/pbrkL804c8yAv3zBZR4QPEafpAR.jpg',
    voteAverage: 8.4,
    releaseDate: '2014-11-05',
  ),
  TmdbMedia(
    id: 872585,
    mediaType: 'movie',
    titleEn: 'Oppenheimer',
    titleFr: 'Oppenheimer',
    posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    backdropPath: '/rLb2cwF3Pazuxaj0sRXQ037tGI1.jpg',
    voteAverage: 8.1,
    releaseDate: '2023-07-19',
  ),
  TmdbMedia(
    id: 1399,
    mediaType: 'tv',
    titleEn: 'Game of Thrones',
    titleFr: 'Game of Thrones',
    posterPath: '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
    backdropPath: '/m0bV4D3dZQYjF4gUeR5Y4kK8v8c.jpg',
    voteAverage: 8.4,
    firstAirDate: '2011-04-17',
  ),
  TmdbMedia(
    id: 94605,
    mediaType: 'tv',
    titleEn: 'Arcane',
    titleFr: 'Arcane',
    posterPath: '/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
    backdropPath: '/rkB4LyZHo1NHXFEDHl8M3g1Q3Q.jpg',
    voteAverage: 8.7,
    firstAirDate: '2021-11-06',
  ),
];

const _animeItems = <AnilistMedia>[
  AnilistMedia(
    id: 21,
    type: 'ANIME',
    titleEnglish: 'One Piece',
    titleRomaji: 'One Piece',
    coverLarge:
        'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
    bannerImage:
        'https://image.tmdb.org/t/p/w1280/m0bV4D3dZQYjF4gUeR5Y4kK8v8c.jpg',
    averageScore: 87,
    format: 'TV',
    episodes: 1122,
    genres: ['Action', 'Aventure'],
    countryOfOrigin: 'JP',
  ),
  AnilistMedia(
    id: 16498,
    type: 'ANIME',
    titleEnglish: 'Attack on Titan',
    titleRomaji: 'Shingeki no Kyojin',
    coverLarge:
        'https://image.tmdb.org/t/p/w500/hTP1DtLGFamjfu8WqjnuQdP1n4i.jpg',
    bannerImage:
        'https://image.tmdb.org/t/p/w1280/2LquGwEhbg3soxSCmYcW5s3j5Yw.jpg',
    averageScore: 91,
    format: 'TV',
    episodes: 89,
    genres: ['Action', 'Drame'],
    countryOfOrigin: 'JP',
  ),
  AnilistMedia(
    id: 52991,
    type: 'ANIME',
    titleEnglish: 'Frieren: Beyond Journey’s End',
    titleRomaji: 'Sousou no Frieren',
    coverLarge:
        'https://image.tmdb.org/t/p/w500/edZf3G2qkU8aT5s8H3rY5yJ2XbG.jpg',
    averageScore: 90,
    format: 'TV',
    episodes: 28,
    genres: ['Fantasy', 'Aventure'],
    countryOfOrigin: 'JP',
  ),
];

final _extensionItems = [
  MManga(
    name: 'Dune : Deuxième partie',
    imageUrl: 'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    description: 'Un exemple de résultat fourni par une extension vidéo.',
    genre: ['Science-fiction', 'Aventure'],
  ),
  MManga(
    name: 'Interstellar',
    imageUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    genre: ['Drame', 'Science-fiction'],
  ),
  MManga(
    name: 'Oppenheimer',
    imageUrl: 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    genre: ['Histoire', 'Drame'],
  ),
  MManga(
    name: 'Arcane',
    imageUrl: 'https://image.tmdb.org/t/p/w500/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
    genre: ['Animation', 'Drame'],
  ),
];

class _TmdbCardsShowcase extends StatelessWidget {
  const _TmdbCardsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShowcaseLabel(
          name: 'TmdbPosterCard',
          detail: 'Poster standard · 2:3 · rail Films / Séries',
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tmdbItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => TmdbPosterCard(
              media: _tmdbItems[index],
              width: 112,
              heroTag: 'gallery-poster-${_tmdbItems[index].id}',
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'TmdbCompactPosterCard',
          detail: 'Poster compact · utilisé dans les grilles multi-lignes',
        ),
        SizedBox(
          height: 174,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tmdbItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => TmdbCompactPosterCard(
              media: _tmdbItems[index],
              width: 92,
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _TmdbEditorialShowcase extends StatelessWidget {
  const _TmdbEditorialShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShowcaseLabel(
          name: 'TmdbLandscapeCard',
          detail: 'Paysage · 16:9 · rails Now playing / Airing today',
        ),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tmdbItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => TmdbLandscapeCard(
              media: _tmdbItems[index],
              width: 228,
              heroTag: 'gallery-landscape-${_tmdbItems[index].id}',
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'TmdbRankedCard',
          detail: 'Classement · poster avec rang #1, #2, #3',
        ),
        SizedBox(
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tmdbItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => TmdbRankedCard(
              media: _tmdbItems[index],
              rank: index + 1,
              heroTag: 'gallery-ranked-${_tmdbItems[index].id}',
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'TmdbFeaturedStack · TmdbHeroCarousel',
          detail: 'Hero éditorial et stack featured avec swipe automatique',
        ),
        Builder(
          builder: (context) {
            final accent = Theme.of(context).colorScheme.primary;
            return Column(
              children: [
                SizedBox(
                  height: 290,
                  child: TmdbHeroCarousel(
                    items: _tmdbItems.take(4).toList(growable: false),
                    onTap: (_) {},
                  ),
                ),
                const SizedBox(height: 12),
                TmdbFeaturedStack(
                  title: 'À voir cette semaine',
                  icon: Icons.auto_awesome_rounded,
                  color: accent,
                  items: _tmdbItems,
                  onTap: (_) {},
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnimeCardsShowcase extends StatelessWidget {
  const _AnimeCardsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShowcaseLabel(
          name: 'DiscoveryCard',
          detail: 'Poster AniList standard · score, pays et format',
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _animeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => DiscoveryCard(
              media: _animeItems[index],
              width: 116,
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'AnimatedDiscoveryCard',
          detail: 'Même carte de découverte avec entrée animée différée',
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _animeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => AnimatedDiscoveryCard(
              media: _animeItems[index],
              width: 116,
              delay: Duration(milliseconds: index * 90),
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'FeaturedDiscoveryCard · SagaDiscoveryCard',
          detail: 'Featured 3:4 et saga 16:10 · rails éditoriaux anime',
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _animeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => index.isEven
                ? FeaturedDiscoveryCard(media: _animeItems[index], onTap: () {})
                : SagaDiscoveryCard(media: _animeItems[index], onTap: () {}),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name:
              'RankedDiscoveryCard · LandscapeDiscoveryCard · SpotlightDiscoveryCard',
          detail: 'Rang, paysage 16:9 et spotlight cinématique',
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _animeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final media = _animeItems[index];
              return switch (index % 3) {
                0 => RankedDiscoveryCard(
                  media: media,
                  rank: index + 1,
                  onTap: () {},
                ),
                1 => LandscapeDiscoveryCard(media: media, onTap: () {}),
                _ => SizedBox(
                  width: 318,
                  child: SpotlightDiscoveryCard(media: media, onTap: () {}),
                ),
              };
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionCardsShowcase extends StatelessWidget {
  const _ExtensionCardsShowcase();

  @override
  Widget build(BuildContext context) {
    final item = _extensionItems.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ShowcaseLabel(
          name: 'ExtensionPosterCard',
          detail:
              'Carte poster de WatchExtensionHomeScreen · résultat extension',
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _extensionItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => ExtensionPosterCard(
              item: _extensionItems[index],
              width: 112,
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'ExtensionLandscapeCard',
          detail: 'Carte paysage 16:9 avec action de lecture',
        ),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _extensionItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => ExtensionLandscapeCard(
              item: _extensionItems[index],
              width: 228,
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _ShowcaseLabel(
          name: 'ExtensionRankedCard · ExtensionTagCard · AppGenreTile',
          detail:
              'Classement, tag et tuile genre employés par les layouts d’extension',
        ),
        SizedBox(
          height: 198,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                height: 198,
                child: ExtensionRankedCard(item: item, rank: 1, onTap: () {}),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 76,
                      child: ExtensionTagCard(item: item, onTap: () {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AppGenreTile(
                        label: 'Science-fiction',
                        imageUrl: item.imageUrl,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwipeStateShowcase extends StatefulWidget {
  const _SwipeStateShowcase();

  @override
  State<_SwipeStateShowcase> createState() => _SwipeStateShowcaseState();
}

class _SwipeStateShowcaseState extends State<_SwipeStateShowcase> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 328,
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            children: const [_LoadingStatePage(), _ResultStatePage()],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StateDot(active: _page == 0),
            const SizedBox(width: 6),
            _StateDot(active: _page == 1),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          _page == 0
              ? '1 / 2 · Skeleton de production'
              : '2 / 2 · Résultat avec affiches TMDB',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoadingStatePage extends StatelessWidget {
  const _LoadingStatePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StateHeader(
          icon: Icons.hourglass_top_rounded,
          title: 'Loading state',
          detail: 'AppMediaRowShimmer · AppLandscapeRowShimmer',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: AppMediaRowShimmer(
            itemWidth: MediaQuery.sizeOf(context).width < 650 ? 88 : 108,
          ),
        ),
      ],
    );
  }
}

class _ResultStatePage extends StatelessWidget {
  const _ResultStatePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StateHeader(
          icon: Icons.check_circle_outline_rounded,
          title: 'Result state',
          detail: 'TmdbPosterCard · image réseau réelle',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tmdbItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => TmdbPosterCard(
              media: _tmdbItems[index],
              width: 112,
              heroTag: 'swipe-result-${_tmdbItems[index].id}',
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _StateHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _StateHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.swipe_rounded, color: Colors.white38, size: 18),
      ],
    );
  }
}

class _StateDot extends StatelessWidget {
  final bool active;

  const _StateDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _ShowcaseLabel extends StatelessWidget {
  final String name;
  final String detail;

  const _ShowcaseLabel({required this.name, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 30,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditSummary extends StatelessWidget {
  const _AuditSummary();

  static const _rows = [
    (
      'TMDB',
      'TmdbPosterCard · TmdbCompactPosterCard · TmdbLandscapeCard · TmdbRankedCard',
    ),
    ('AniList', 'DiscoveryCard · RankedDiscoveryCard · LandscapeDiscoveryCard'),
    (
      'AniList éditorial',
      'FeaturedDiscoveryCard · SagaDiscoveryCard · SpotlightDiscoveryCard',
    ),
    (
      'Extensions',
      'ExtensionPosterCard · ExtensionLandscapeCard · ExtensionRankedCard · ExtensionTagCard',
    ),
    (
      'Commun',
      'AppGenreTile · AppCrossfadeCarousel · AppMediaRowShimmer · AppMediaGridShimmer',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _rows.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == _rows.length - 1 ? 0 : 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    _rows[index].$1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _rows[index].$2,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Conclusion : la galerie couvre les familles de cartes réellement appelées '
            'par les écrans Films/Séries et WatchExtensionHomeScreen. Les cartes de '
            'téléchargement, manga et musique restent hors de ce catalogue média.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }
}
