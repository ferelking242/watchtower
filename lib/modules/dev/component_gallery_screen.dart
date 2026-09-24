import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/watchtower_home_screen.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';

enum _GalleryState { result, skeleton }

enum _PreviewKind {
  poster,
  compactPoster,
  landscape,
  ranked,
  mini,
  featured,
  saga,
  spotlight,
  tag,
  genre,
  carousel,
}

class _ComponentSpec {
  final String title;
  final String className;
  final String path;
  final String usage;
  final IconData icon;
  final _PreviewKind kind;
  final Widget Function(BuildContext context) result;

  const _ComponentSpec({
    required this.title,
    required this.className,
    required this.path,
    required this.usage,
    required this.icon,
    required this.kind,
    required this.result,
  });

  String get searchableText => '$title $className $path $usage'.toLowerCase();
}

class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  final _searchController = TextEditingController();
  _GalleryState _state = _GalleryState.result;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ComponentSpec> get _components => _buildComponents();

  List<_ComponentSpec> get _visibleComponents {
    final query = _query.trim().toLowerCase();
    return _components
        .where((component) {
          final textMatches =
              query.isEmpty || component.searchableText.contains(query);
          return textMatches;
        })
        .toList(growable: false);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _state = _GalleryState.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppUI.pagePadding(context);
    final visible = _visibleComponents;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0B0D10).withValues(alpha: .96),
            surfaceTintColor: Colors.transparent,
            titleSpacing: padding,
            title: const Row(
              children: [
                _GalleryMark(),
                SizedBox(width: 11),
                Text('Galerie des composants'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Réinitialiser les filtres',
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
              Padding(
                padding: EdgeInsets.only(right: padding - 8),
                child: IconButton(
                  tooltip: 'Fermer la galerie',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Broken.close_circle),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 18),
              child: _GalleryHeader(
                queryController: _searchController,
                query: _query,
                state: _state,
                resultCount: visible.length,
                onQueryChanged: (query) => setState(() => _query = query),
                onStateChanged: (state) => setState(() => _state = state),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 88),
            sliver: visible.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyGalleryState())
                : SliverToBoxAdapter(
                    child: _UnifiedGallery(
                      components: visible,
                      state: _state,
                      showCompositions: _query.trim().isEmpty,
                    ),
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

class _GalleryHeader extends StatelessWidget {
  final TextEditingController queryController;
  final String query;
  final _GalleryState state;
  final int resultCount;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_GalleryState> onStateChanged;

  const _GalleryHeader({
    required this.queryController,
    required this.query,
    required this.state,
    required this.resultCount,
    required this.onQueryChanged,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Une référence claire pour chaque carte.',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            'Retrouvez toutes les cartes réellement utilisées dans l’application. '
            'Chaque aperçu conserve sa taille réelle, '
            'son nom et son usage, en résultat ou en chargement.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: queryController,
          onChanged: onQueryChanged,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher une carte, un usage ou un fichier…',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      queryController.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
            filled: true,
            fillColor: const Color(0xFF161A20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.grid_view_rounded, size: 17, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              '$resultCount aperçu${resultCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.visibility_rounded,
              size: 17,
              color: Colors.white54,
            ),
            const SizedBox(width: 8),
            _StateToggle(state: state, onChanged: onStateChanged),
          ],
        ),
      ],
    );
  }
}

class _StateToggle extends StatelessWidget {
  final _GalleryState state;
  final ValueChanged<_GalleryState> onChanged;

  const _StateToggle({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF161A20),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateOption(
            icon: Icons.image_outlined,
            label: 'Résultat',
            selected: state == _GalleryState.result,
            onTap: () => onChanged(_GalleryState.result),
          ),
          _StateOption(
            icon: Icons.hourglass_empty_rounded,
            label: 'Skeleton',
            selected: state == _GalleryState.skeleton,
            onTap: () => onChanged(_GalleryState.skeleton),
          ),
        ],
      ),
    );
  }
}

class _StateOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StateOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .22) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? accent : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedGallery extends StatelessWidget {
  final _GalleryState state;
  final List<_ComponentSpec> components;
  final bool showCompositions;

  const _UnifiedGallery({
    required this.state,
    required this.components,
    required this.showCompositions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComponentGrid(components: components, state: state),
        if (showCompositions) ...[
          const SizedBox(height: 32),
          const _UnifiedSectionLabel(
            icon: Icons.layers_outlined,
            label: 'Blocs composés',
          ),
          const SizedBox(height: 12),
          _ComposedBlocks(state: state),
        ],
      ],
    );
  }
}

class _UnifiedSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UnifiedSectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ComponentGrid extends StatelessWidget {
  final List<_ComponentSpec> components;
  final _GalleryState state;

  const _ComponentGrid({required this.components, required this.state});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 26,
      runSpacing: 28,
      alignment: WrapAlignment.start,
      children: [
        for (final component in components)
          _ComponentTile(component: component, state: state),
      ],
    );
  }
}

class _ComponentTile extends StatelessWidget {
  final _ComponentSpec component;
  final _GalleryState state;

  const _ComponentTile({required this.component, required this.state});

  @override
  Widget build(BuildContext context) {
    final previewHeight = _previewHeight(component.kind);
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: _previewWidth(component.kind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: previewHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: state == _GalleryState.result
                  ? component.result(context)
                  : _CardSkeleton(kind: component.kind),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(component.icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  component.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                state == _GalleryState.result
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_top_rounded,
                size: 13,
                color: state == _GalleryState.result
                    ? Colors.greenAccent.shade400
                    : Colors.amberAccent,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${component.className} · ${component.usage}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final _PreviewKind kind;

  const _CardSkeleton({required this.kind});

  @override
  Widget build(BuildContext context) {
    final card = switch (kind) {
      _PreviewKind.poster ||
      _PreviewKind.compactPoster ||
      _PreviewKind.ranked ||
      _PreviewKind.featured => SizedBox(
        width: kind == _PreviewKind.compactPoster ? 92 : 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppShimmerBlock(
                radius: kind == _PreviewKind.featured ? 16 : 12,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 86,
              height: 11,
              child: AppShimmerBlock(radius: 5),
            ),
            const SizedBox(height: 5),
            const SizedBox(
              width: 54,
              height: 9,
              child: AppShimmerBlock(radius: 5),
            ),
          ],
        ),
      ),
      _PreviewKind.landscape ||
      _PreviewKind.saga ||
      _PreviewKind.spotlight => SizedBox(
        width: kind == _PreviewKind.spotlight ? 290 : 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppShimmerBlock(radius: 15)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 150,
              height: 11,
              child: AppShimmerBlock(radius: 5),
            ),
          ],
        ),
      ),
      _PreviewKind.mini => SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppShimmerBlock(radius: 11)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 120,
              height: 11,
              child: AppShimmerBlock(radius: 5),
            ),
          ],
        ),
      ),
      _PreviewKind.tag => const SizedBox(
        width: 260,
        height: 64,
        child: AppShimmerBlock(radius: 14),
      ),
      _PreviewKind.genre => const SizedBox(
        width: 260,
        height: 112,
        child: AppShimmerBlock(radius: 17),
      ),
      _PreviewKind.carousel => SizedBox(
        width: 112,
        height: 190,
        child: Column(
          children: [
            const Expanded(child: AppShimmerBlock(radius: 14)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 82,
              height: 10,
              child: AppShimmerBlock(radius: 5),
            ),
          ],
        ),
      ),
    };
    return card;
  }
}

class _ComposedBlocks extends StatelessWidget {
  final _GalleryState state;

  const _ComposedBlocks({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CompositionHeader(
          title: 'Blocs composés',
          detail:
              'Blocs complets qui assemblent plusieurs cartes dans les écrans d’accueil.',
        ),
        if (state == _GalleryState.skeleton)
          const SizedBox(height: 220, child: AppBannerRowShimmer())
        else ...[
          SizedBox(
            height: 270,
            child: TmdbHeroCarousel(
              items: _tmdbItems.take(4).toList(growable: false),
              onTap: (_) {},
            ),
          ),
          const SizedBox(height: 15),
          TmdbFeaturedStack(
            title: 'À voir cette semaine',
            icon: Icons.auto_awesome_rounded,
            color: Theme.of(context).colorScheme.primary,
            items: _tmdbItems,
            onTap: (_) {},
          ),
        ],
      ],
    );
  }
}

class _CompositionHeader extends StatelessWidget {
  final String title;
  final String detail;

  const _CompositionHeader({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
        ],
      ),
    );
  }
}

class _EmptyGalleryState extends StatelessWidget {
  const _EmptyGalleryState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF11151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.white38, size: 38),
          SizedBox(height: 13),
          Text(
            'Aucun composant trouvé',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Essayez un autre nom ou effacez la recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

List<_ComponentSpec> _buildComponents() => [
  _ComponentSpec(
    title: 'Poster contenu',
    className: 'PosterCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Rails catalogue',
    icon: Icons.local_movies_outlined,
    kind: _PreviewKind.poster,
    result: (_) => PosterCard(
      item: ContentItem.fromTmdb(_tmdbItems[0]),
      width: 112,
      heroTag: 'gallery-tmdb-poster',
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Poster compact',
    className: 'PosterCard(compact)',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Grille multi-rangées',
    icon: Icons.grid_view_outlined,
    kind: _PreviewKind.compactPoster,
    result: (_) => PosterCard(
      item: ContentItem.fromTmdb(_tmdbItems[1]),
      width: 92,
      compact: true,
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Carte paysage',
    className: 'LandscapeCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Rails paysage',
    icon: Icons.panorama_outlined,
    kind: _PreviewKind.landscape,
    result: (_) => LandscapeCard(
      item: ContentItem.fromTmdb(_tmdbItems[2]),
      width: 220,
      heroTag: 'gallery-tmdb-landscape',
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Carte classée',
    className: 'RankedCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Classements',
    icon: Icons.leaderboard_outlined,
    kind: _PreviewKind.ranked,
    result: (_) => RankedCard(
      item: ContentItem.fromTmdb(_tmdbItems[3]),
      rank: 1,
      heroTag: 'gallery-tmdb-ranked',
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Mini carte du soir',
    className: 'TmdbTonightMiniCard',
    path: 'lib/modules/home/watchtower_home_screen.dart',
    usage: 'Bloc À voir ce soir',
    icon: Icons.nightlight_round,
    kind: _PreviewKind.mini,
    result: (context) => SizedBox(
      width: 170,
      child: TmdbTonightMiniCard(
        media: _tmdbItems[4],
        background: Theme.of(context).colorScheme.surface,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Poster découverte',
    className: 'DiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Rails découverte',
    icon: Icons.animation_outlined,
    kind: _PreviewKind.poster,
    result: (_) =>
        DiscoveryCard(media: _animeItems[0], width: 116, onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Poster animé',
    className: 'AnimatedDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Entrée animée',
    icon: Icons.animation_rounded,
    kind: _PreviewKind.poster,
    result: (_) =>
        AnimatedDiscoveryCard(media: _animeItems[1], width: 116, onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Carte classée',
    className: 'RankedDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Classements',
    icon: Icons.format_list_numbered_rounded,
    kind: _PreviewKind.ranked,
    result: (_) =>
        RankedDiscoveryCard(media: _animeItems[2], rank: 2, onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Carte paysage',
    className: 'LandscapeDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Rails sorties',
    icon: Icons.landscape_outlined,
    kind: _PreviewKind.landscape,
    result: (_) => LandscapeDiscoveryCard(media: _animeItems[0], onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Carte mise en avant',
    className: 'FeaturedDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Premier élément des rails tendance',
    icon: Icons.star_border_rounded,
    kind: _PreviewKind.featured,
    result: (_) => FeaturedDiscoveryCard(media: _animeItems[0], onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Carte saga',
    className: 'SagaDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Franchises et longues séries',
    icon: Icons.auto_stories_outlined,
    kind: _PreviewKind.saga,
    result: (_) => SagaDiscoveryCard(media: _animeItems[1], onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Carte spotlight',
    className: 'SpotlightDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Rail Coup de cœur',
    icon: Icons.highlight_rounded,
    kind: _PreviewKind.spotlight,
    result: (_) => SizedBox(
      width: 290,
      child: SpotlightDiscoveryCard(media: _animeItems[2], onTap: () {}),
    ),
  ),
  _ComponentSpec(
    className: 'PosterCard',
    path: 'lib/modules/media/content_cards.dart',
    title: 'Poster catalogue',
    usage: 'Rails de résultats',
    icon: Icons.extension_outlined,
    kind: _PreviewKind.poster,
    result: (_) => PosterCard(
      item: ContentItem.fromManga(_extensionItems[0]),
      width: 112,
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Carte paysage',
    className: 'LandscapeCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Rails avec lecture',
    icon: Icons.play_circle_outline_rounded,
    kind: _PreviewKind.landscape,
    result: (_) => LandscapeCard(
      item: ContentItem.fromManga(_extensionItems[1]),
      width: 220,
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Classement',
    className: 'RankedCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Top des contenus',
    icon: Icons.emoji_events_outlined,
    kind: _PreviewKind.ranked,
    result: (_) => SizedBox(
      width: 110,
      height: 190,
      child: RankedCard(
        item: ContentItem.fromManga(_extensionItems[2]),
        rank: 1,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Carte tag',
    className: 'TagCard',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Grilles de tags',
    icon: Icons.local_offer_outlined,
    kind: _PreviewKind.tag,
    result: (_) => SizedBox(
      width: 260,
      child: TagCard(
        item: ContentItem.fromManga(_extensionItems[3]),
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Tuile genre',
    className: 'AppGenreTile',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Tuiles de genres',
    icon: Icons.category_outlined,
    kind: _PreviewKind.genre,
    result: (_) => SizedBox(
      width: 260,
      height: 112,
      child: AppGenreTile(
        label: 'Science-fiction',
        imageUrl: _extensionItems[0].imageUrl,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Carrousel tactile',
    className: 'AppCrossfadeCarousel',
    path: 'lib/modules/media/content_cards.dart',
    usage: 'Swipe, fondu et autoplay commun',
    icon: Icons.swipe_rounded,
    kind: _PreviewKind.carousel,
    result: (_) => SizedBox(
      width: 112,
      height: 190,
      child: AppCrossfadeCarousel(
        itemCount: 2,
        interval: const Duration(seconds: 5),
        itemBuilder: (_, index) => PosterCard(
          item: ContentItem.fromTmdb(_tmdbItems[index]),
          width: 112,
          heroTag: 'gallery-crossfade-$index',
          onTap: () {},
        ),
      ),
    ),
  ),
];

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
    description: 'Un résultat fourni par une extension vidéo.',
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

double _previewHeight(_PreviewKind kind) => switch (kind) {
  _PreviewKind.poster => 210,
  _PreviewKind.compactPoster => 195,
  _PreviewKind.landscape => 165,
  _PreviewKind.ranked => 205,
  _PreviewKind.mini => 165,
  _PreviewKind.featured => 270,
  _PreviewKind.saga => 165,
  _PreviewKind.spotlight => 165,
  _PreviewKind.tag => 86,
  _PreviewKind.genre => 132,
  _PreviewKind.carousel => 220,
};

double _previewWidth(_PreviewKind kind) => switch (kind) {
  _PreviewKind.poster => 116,
  _PreviewKind.compactPoster => 92,
  _PreviewKind.landscape => 220,
  _PreviewKind.ranked => 146,
  _PreviewKind.mini => 170,
  _PreviewKind.featured => 290,
  _PreviewKind.saga => 220,
  _PreviewKind.spotlight => 290,
  _PreviewKind.tag => 260,
  _PreviewKind.genre => 260,
  _PreviewKind.carousel => 112,
};
