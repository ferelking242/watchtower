import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/watchtower_home_screen.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/episode_card.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/widgets/component_library.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';

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
  genreSection,
  mediaSection,
  providersSection,
  carousel,
  episode,
  detailEpisode,
  wallpaper,
  season,
  cast,
  trailer,
  extensionHero,
  rankedWide,
  showcase,
  collection,
  banner,
  creator,
  studio,
  searchGrid,
  searchList,
  searchCinema,
  manga,
  mangaList,
  extensionGrid,
  history,
  historyGrid,
  empty,
  error,
  libraryCard,
  librarySection,
  swipeSection,
}

class _ComponentSpec {
  final String title;
  final String className;
  final String path;
  final String usage;
  final String section;
  final IconData icon;
  final _PreviewKind kind;
  final Widget Function(BuildContext context) result;

  const _ComponentSpec({
    required this.title,
    required this.className,
    required this.path,
    required this.usage,
    this.section = 'CATALOGUE & DISCOVERY',
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
    final grouped = <String, List<_ComponentSpec>>{};
    for (final component in components) {
      grouped.putIfAbsent(component.section, () => <_ComponentSpec>[]).add(component);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          _UnifiedSectionLabel(
            icon: _sectionIcon(entry.key),
            label: entry.key,
          ),
          const SizedBox(height: 12),
          _ComponentGrid(components: entry.value, state: state),
          if (entry.key != grouped.keys.last) const SizedBox(height: 32),
        ],
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

IconData _sectionIcon(String section) {
  if (section.contains('EXTENSION')) return Icons.extension_outlined;
  if (section.contains('MANGA')) return Icons.menu_book_outlined;
  if (section.contains('RECHERCHE')) return Icons.search_rounded;
  if (section.contains('HISTORIQUE')) return Icons.history_rounded;
  if (section.contains('ÉTATS')) return Icons.checklist_rounded;
  if (section.contains('DÉTAIL')) return Icons.movie_filter_outlined;
  return Icons.grid_view_rounded;
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
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: component.className),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('${component.className} copié'),
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(component.icon, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          component.className,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${component.title} · ${component.usage}',
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
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: previewHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: state == _GalleryState.result
                  ? component.result(context)
                  : _CardSkeleton(kind: component.kind),
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
      _PreviewKind.genreSection => const AppGenreGridShimmer(),
      _PreviewKind.mediaSection => SizedBox(
        width: 340,
        height: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 110,
              height: 16,
              child: AppShimmerBlock(radius: 5),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: AppShimmerBlock(radius: 14)),
                  const SizedBox(width: 10),
                  Expanded(child: AppShimmerBlock(radius: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
      _PreviewKind.providersSection => const AppStreamingServicesShimmer(),
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
      _PreviewKind.episode ||
      _PreviewKind.detailEpisode ||
      _PreviewKind.trailer => const SizedBox(
        width: 220,
        height: 152,
        child: AppShimmerBlock(radius: 12),
      ),
      _PreviewKind.wallpaper ||
      _PreviewKind.extensionHero ||
      _PreviewKind.studio ||
      _PreviewKind.searchCinema => const SizedBox(
        width: 320,
        height: 180,
        child: AppShimmerBlock(radius: 16),
      ),
      _PreviewKind.season ||
      _PreviewKind.cast ||
      _PreviewKind.creator ||
      _PreviewKind.manga => const SizedBox(
        width: 112,
        height: 168,
        child: AppShimmerBlock(radius: 12),
      ),
      _PreviewKind.rankedWide ||
      _PreviewKind.searchList ||
      _PreviewKind.history => const SizedBox(
        width: 330,
        height: 92,
        child: AppShimmerBlock(radius: 12),
      ),
      _PreviewKind.showcase ||
      _PreviewKind.banner ||
      _PreviewKind.extensionGrid ||
      _PreviewKind.historyGrid ||
      _PreviewKind.mangaList => const SizedBox(
        width: 300,
        height: 190,
        child: AppShimmerBlock(radius: 14),
      ),
      _PreviewKind.collection => const ExtensionCollectionCardShimmer(),
      _PreviewKind.searchGrid => const SizedBox(
        width: 112,
        height: 178,
        child: AppShimmerBlock(radius: 12),
      ),
      _PreviewKind.empty ||
      _PreviewKind.error => const SizedBox(
        width: 300,
        height: 174,
        child: AppShimmerBlock(radius: 18),
      ),
      _PreviewKind.libraryCard => const SizedBox(
        width: 230,
        height: 190,
        child: AppShimmerBlock(radius: 14),
      ),
      _PreviewKind.librarySection => const SizedBox(
        width: 340,
        height: 220,
        child: AppShimmerBlock(radius: 14),
      ),
      _PreviewKind.swipeSection => const SizedBox(
        width: 340,
        height: 520,
        child: AppShimmerBlock(radius: 14),
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

class _WallpaperPreview extends StatelessWidget {
  final TmdbMedia media;

  const _WallpaperPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: media.bannerImage, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF0000000)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                media.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonPreview extends StatelessWidget {
  final TmdbMedia media;

  const _SeasonPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: media.bestCover, radius: 0),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(7),
                      color: Colors.black.withValues(alpha: .72),
                      child: const Text(
                        'Saison 1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '10 épisodes',
            style: TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CastPreview extends StatelessWidget {
  final TmdbMedia media;

  const _CastPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: 92,
              height: 92,
              child: ContentImage(url: media.bestCover, radius: 0),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acteur principal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            media.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TrailerPreview extends StatelessWidget {
  final TmdbMedia media;

  const _TrailerPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: media.bannerImage, radius: 0),
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${media.displayTitle} · Bande-annonce',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/*
class _ExtensionHeroPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionHeroPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 224,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: item.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF5000000)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GalleryBadge(label: 'À LA UNE'),
                  const SizedBox(height: 8),
                  Text(
                    item.name ?? 'Sans titre',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Extension vidéo · 2024',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionRankedWidePreview extends StatelessWidget {
  final MManga item;
  final int rank;

  const _ExtensionRankedWidePreview({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 88,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 66,
              height: 88,
              child: ContentImage(url: item.imageUrl, radius: 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Sans titre',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Extension · 8.6',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionShowcasePreview extends StatelessWidget {
  final MManga item;

  const _ExtensionShowcasePreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 192,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: item.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF0000000), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _GalleryBadge(label: 'SHOWCASE'),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              right: 90,
              child: Text(
                item.name ?? 'Sans titre',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Positioned(
              right: 15,
              bottom: 15,
              child: _PlayCircle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCollectionPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionCollectionPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 112,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF17243C), Color(0xFF294B6B)],
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 76,
                height: 112,
                child: ContentImage(url: item.imageUrl, radius: 0),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COLLECTION',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name ?? 'Sans titre',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionBannerPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionBannerPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 146,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: item.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                item.name ?? 'Sans titre',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCreatorPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionCreatorPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: 98,
              height: 98,
              child: ContentImage(url: item.imageUrl, radius: 0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name ?? 'Créateur',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            '12 titres',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ExtensionStudioPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionStudioPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 176,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: item.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF0000000)],
                ),
              ),
            ),
            const Positioned(
              left: 14,
              top: 14,
              child: _GalleryBadge(label: 'STUDIO'),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: Text(
                item.name ?? 'Studio',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCategoryPreview extends StatelessWidget {
  final MManga item;

  const _ExtensionCategoryPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 112,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: item.imageUrl, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDF000000)],
                ),
              ),
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: Text(
                'Science-fiction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionGridPreview extends StatelessWidget {
  final List<MManga> items;

  const _ExtensionGridPreview({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 208,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items.take(3)) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ContentImage(url: item.imageUrl, radius: 0),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name ?? 'Sans titre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

*/
class _SearchGridPreview extends StatelessWidget {
  final MManga item;

  const _SearchGridPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 112,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: item.imageUrl, radius: 0),
                  const Positioned(
                    top: 7,
                    right: 7,
                    child: _GalleryBadge(label: '8.6'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name ?? 'Sans titre',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchListPreview extends StatelessWidget {
  final MManga item;

  const _SearchListPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      height: 88,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 76,
              child: ContentImage(url: item.imageUrl, radius: 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Sans titre',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Manga · En cours',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }
}

class _SearchCinemaPreview extends StatelessWidget {
  final TmdbMedia media;

  const _SearchCinemaPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            SizedBox(
              height: 150,
              child: ContentImage(url: media.bannerImage, radius: 0),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xEC000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                media.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  final MManga item;

  const _HistoryPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      height: 88,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 78,
              height: 76,
              child: ContentImage(url: item.imageUrl, radius: 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Sans titre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Chapitre 24 · il y a 2 h',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: .68,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
        ],
      ),
    );
  }
}

class _LibraryGridPreview extends StatelessWidget {
  final List<MManga> items;

  const _LibraryGridPreview({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 208,
      child: Row(
        children: [
          for (final item in items.take(3)) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ContentImage(url: item.imageUrl, radius: 0),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name ?? 'Sans titre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryEmptyPreview extends StatelessWidget {
  const _GalleryEmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 174,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, color: Colors.white54, size: 34),
          SizedBox(height: 9),
          Text(
            'Aucun résultat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Votre catalogue est vide pour le moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _GalleryErrorPreview extends StatelessWidget {
  const _GalleryErrorPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 174,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF24191D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: .26)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 34),
          SizedBox(height: 9),
          Text(
            'Impossible de charger',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Réessayez dans quelques instants.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          SizedBox(height: 9),
          Text(
            'Réessayer',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBadge extends StatelessWidget {
  final String label;

  const _GalleryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

class _PlayCircle extends StatelessWidget {
  const _PlayCircle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
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
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Grille des genres du Hub',
    className: 'GenreListGrid',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Section Genres films/séries avec navigation',
    icon: Icons.category_outlined,
    kind: _PreviewKind.genreSection,
    result: (_) => GenreListGrid(imageSource: _tmdbItems),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Rail de posters',
    className: 'ScrollingMovies',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Sections Popular · Trending · Top rated',
    icon: Icons.view_carousel_outlined,
    kind: _PreviewKind.mediaSection,
    result: (_) => SizedBox(
      width: 340,
      height: 240,
      child: ClipRect(
        child: ScrollingMovies(
          title: 'Popular',
          items: _tmdbItems,
          discoverPath: '/movie/popular',
        ),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Rail Top 10',
    className: 'RankedMovies',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Section Top 10 de la semaine',
    icon: Icons.leaderboard_outlined,
    kind: _PreviewKind.mediaSection,
    result: (_) => SizedBox(
      width: 340,
      height: 240,
      child: ClipRect(
        child: RankedMovies(
          title: 'Top 10 cette semaine',
          items: _tmdbItems,
        ),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Rail paysage',
    className: 'ScrollingLandscapeMovies',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Now playing · Upcoming · Airing today',
    icon: Icons.panorama_outlined,
    kind: _PreviewKind.mediaSection,
    result: (_) => SizedBox(
      width: 340,
      height: 240,
      child: ClipRect(
        child: ScrollingLandscapeMovies(
          title: 'Now playing',
          items: _tmdbItems,
          discoverPath: '/movie/now_playing',
        ),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Rail à découvrir',
    className: 'FeaturedMovieRail',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Sélection mise en avant',
    icon: Icons.auto_awesome_outlined,
    kind: _PreviewKind.mediaSection,
    result: (_) => SizedBox(
      width: 340,
      height: 240,
      child: ClipRect(
        child: FeaturedMovieRail(
          title: 'À découvrir',
          items: _tmdbItems,
        ),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Bannières plein écran',
    className: 'FullWidthMovieBanners',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'À voir ce soir · À voir bientôt',
    icon: Icons.view_agenda_outlined,
    kind: _PreviewKind.mediaSection,
    result: (_) => SizedBox(
      width: 340,
      height: 240,
      child: ClipRect(
        child: FullWidthMovieBanners(
          title: 'À voir ce soir',
          items: _tmdbItems,
        ),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Services de streaming',
    className: 'MoviesFromWatchProviders',
    path: 'lib/modules/media/media_home_widgets.dart',
    usage: 'Section des plateformes disponibles',
    icon: Icons.live_tv_outlined,
    kind: _PreviewKind.providersSection,
    result: (_) => const SizedBox(
      width: 340,
      child: MoviesFromWatchProviders(),
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
  _ComponentSpec(
    section: 'ACCUEIL & LECTURE',
    title: 'Carte épisode',
    className: 'EpisodeCard',
    path: 'lib/modules/home/widgets/episode_card.dart',
    usage: 'Reprendre la lecture',
    icon: Icons.play_circle_outline_rounded,
    kind: _PreviewKind.episode,
    result: (_) => EpisodeCard(
      width: 220,
      data: EpisodeCardData(
        thumbnailUrl: _tmdbItems[4].bannerImage,
        animeTitle: 'Arcane',
        episodeNumber: 4,
        episodeTitle: 'Happy Progress Day!',
        progress: const EpisodeProgress(value: .62, timeLeft: '12 min'),
      ),
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    section: 'ACCUEIL & LECTURE',
    title: 'Épisode sans progression',
    className: 'EpisodeCard',
    path: 'lib/modules/home/widgets/episode_card.dart',
    usage: 'Liste des épisodes',
    icon: Icons.movie_outlined,
    kind: _PreviewKind.detailEpisode,
    result: (_) => EpisodeCard(
      width: 220,
      data: EpisodeCardData(
        thumbnailUrl: _tmdbItems[1].bannerImage,
        animeTitle: 'Interstellar',
        episodeNumber: 1,
        episodeTitle: 'Le voyage commence',
      ),
      onTap: () {},
    ),
  ),
  _ComponentSpec(
    section: 'DÉTAIL MÉDIA',
    title: 'Wallpaper détail',
    className: '_WallpaperCard',
    path: 'lib/modules/media/tmdb_media_detail_screen.dart',
    usage: 'En-tête détail film/série',
    icon: Icons.wallpaper_outlined,
    kind: _PreviewKind.wallpaper,
    result: (_) => _WallpaperPreview(media: _tmdbItems[0]),
  ),
  _ComponentSpec(
    section: 'DÉTAIL MÉDIA',
    title: 'Carte saison',
    className: '_SeasonsSummary',
    path: 'lib/modules/media/tmdb_media_detail_screen.dart',
    usage: 'Sélecteur de saisons',
    icon: Icons.video_library_outlined,
    kind: _PreviewKind.season,
    result: (_) => _SeasonPreview(media: _tmdbItems[3]),
  ),
  _ComponentSpec(
    section: 'DÉTAIL MÉDIA',
    title: 'Carte casting',
    className: '_CastSection',
    path: 'lib/modules/media/tmdb_media_detail_screen.dart',
    usage: 'Distribution principale',
    icon: Icons.people_outline_rounded,
    kind: _PreviewKind.cast,
    result: (_) => _CastPreview(media: _tmdbItems[4]),
  ),
  _ComponentSpec(
    section: 'DÉTAIL MÉDIA',
    title: 'Carte bande-annonce',
    className: '_TrailerHeroSlide',
    path: 'lib/modules/media/tmdb_media_detail_screen.dart',
    usage: 'Vidéos et trailers',
    icon: Icons.ondemand_video_outlined,
    kind: _PreviewKind.trailer,
    result: (_) => _TrailerPreview(media: _tmdbItems[2]),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Hero extension',
    className: 'MediaHeroCarousel',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layout spotlight · carrousel plein écran',
    icon: Icons.open_in_full_rounded,
    kind: _PreviewKind.extensionHero,
    result: (_) => ExtensionLayoutPreview(
      title: 'À la une',
      component: 'spotlight',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Classement horizontal',
    className: 'MediaRankedRail → RankedCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layouts ranked · rankedWide',
    icon: Icons.format_list_numbered_rounded,
    kind: _PreviewKind.rankedWide,
    result: (_) => ExtensionLayoutPreview(
      title: 'Top extensions',
      component: 'rankedWide',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Carte showcase',
    className: 'MediaLandscapeRail → LandscapeCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layouts showcase · landscapeStacked',
    icon: Icons.auto_awesome_outlined,
    kind: _PreviewKind.showcase,
    result: (_) => ExtensionLayoutPreview(
      title: 'Sélection',
      component: 'showcase',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Collection / playlist',
    className: '_ExtensionCollectionCardRail → _ExtensionCollectionCard',
    path: 'lib/modules/watch/home/watch_extension_home_screen.dart',
    usage: 'Cartes collectionCards · playlistCarousel',
    icon: Icons.collections_bookmark_outlined,
    kind: _PreviewKind.collection,
    result: (_) => ExtensionLayoutPreview(
      title: 'Collections',
      component: 'collectionCards',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Bannière extension',
    className: 'MediaBannerRail',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layout banner',
    icon: Icons.view_carousel_outlined,
    kind: _PreviewKind.banner,
    result: (_) => ExtensionLayoutPreview(
      title: 'Bannières',
      component: 'banner',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Créateur',
    className: 'MediaLandscapeRail → LandscapeCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layout creatorRow',
    icon: Icons.person_outline_rounded,
    kind: _PreviewKind.creator,
    result: (_) => ExtensionLayoutPreview(
      title: 'Créateurs',
      component: 'creatorRow',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Studio',
    className: 'MediaLandscapeRail → LandscapeCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layout studioExplorer',
    icon: Icons.business_outlined,
    kind: _PreviewKind.studio,
    result: (_) => ExtensionLayoutPreview(
      title: 'Studios',
      component: 'studioExplorer',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Catégorie extension',
    className: 'MediaGridSection → PosterCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layouts category · categoryPills',
    icon: Icons.category_outlined,
    kind: _PreviewKind.collection,
    result: (_) => ExtensionLayoutPreview(
      title: 'Catégories',
      component: 'category',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'EXTENSIONS WATCH',
    title: 'Grille extension',
    className: 'MediaGridSection → PosterCard',
    path: 'lib/modules/media/media_content_sections.dart',
    usage: 'Layout grid',
    icon: Icons.grid_4x4_rounded,
    kind: _PreviewKind.extensionGrid,
    result: (_) => ExtensionLayoutPreview(
      title: 'Catalogue',
      component: 'grid',
      source: _gallerySource,
      items: _extensionItems,
      onOpen: (_) {},
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Carte manga',
    className: 'MangaImageCardWidget',
    path: 'lib/modules/widgets/manga_image_card_widget.dart',
    usage: 'Grille catalogue manga',
    icon: Icons.menu_book_outlined,
    kind: _PreviewKind.manga,
    result: (_) => SizedBox(
      width: 112,
      height: 168,
      child: MangaImageCardWidget(
        source: _gallerySource,
        itemType: ItemType.manga,
        getMangaDetail: _extensionItems[0],
        isComfortableGrid: false,
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Tuile manga liste',
    className: 'MangaImageCardListTileWidget',
    path: 'lib/modules/widgets/manga_image_card_widget.dart',
    usage: 'Résultats en liste',
    icon: Icons.view_list_rounded,
    kind: _PreviewKind.mangaList,
    result: (_) => SizedBox(
      width: 300,
      height: 112,
      child: MangaImageCardListTileWidget(
        source: _gallerySource,
        itemType: ItemType.manga,
        getMangaDetail: _extensionItems[1],
      ),
    ),
  ),
  _ComponentSpec(
    section: 'RECHERCHE',
    title: 'Résultat recherche grille',
    className: '_MediaCard',
    path: 'lib/modules/search/watchtower_discover_screen.dart',
    usage: 'Résultats compacts',
    icon: Icons.grid_view_outlined,
    kind: _PreviewKind.searchGrid,
    result: (_) => _SearchGridPreview(item: _extensionItems[0]),
  ),
  _ComponentSpec(
    section: 'RECHERCHE',
    title: 'Résultat recherche liste',
    className: '_MediaListTile',
    path: 'lib/modules/search/watchtower_discover_screen.dart',
    usage: 'Résultats détaillés',
    icon: Icons.view_list_outlined,
    kind: _PreviewKind.searchList,
    result: (_) => _SearchListPreview(item: _extensionItems[1]),
  ),
  _ComponentSpec(
    section: 'RECHERCHE',
    title: 'Résultat recherche cinéma',
    className: '_MediaCardCinema',
    path: 'lib/modules/search/watchtower_discover_screen.dart',
    usage: 'Résultat média paysage',
    icon: Icons.local_movies_outlined,
    kind: _PreviewKind.searchCinema,
    result: (_) => _SearchCinemaPreview(media: _tmdbItems[2]),
  ),
  _ComponentSpec(
    section: 'HISTORIQUE & BIBLIOTHÈQUE',
    title: 'Ligne historique',
    className: '_HistoryListItem',
    path: 'lib/modules/history/history_screen.dart',
    usage: 'Historique de lecture',
    icon: Icons.history_rounded,
    kind: _PreviewKind.history,
    result: (_) => _HistoryPreview(item: _extensionItems[2]),
  ),
  _ComponentSpec(
    section: 'HISTORIQUE & BIBLIOTHÈQUE',
    title: 'Grille bibliothèque',
    className: 'LibraryGridViewWidget',
    path: 'lib/modules/library/widgets/library_gridview_widget.dart',
    usage: 'Bibliothèque en grille',
    icon: Icons.collections_outlined,
    kind: _PreviewKind.historyGrid,
    result: (_) => _LibraryGridPreview(items: _extensionItems),
  ),
  _ComponentSpec(
    section: 'ÉTATS & FEEDBACK',
    title: 'État vide',
    className: '_ExtensionEmpty',
    path: 'lib/modules/watch/home/watch_extension_home_screen.dart',
    usage: 'Aucune donnée dans une extension',
    icon: Icons.inbox_outlined,
    kind: _PreviewKind.empty,
    result: (_) => const _GalleryEmptyPreview(),
  ),
  _ComponentSpec(
    section: 'ÉTATS & FEEDBACK',
    title: 'État erreur',
    className: '_ExtensionError',
    path: 'lib/modules/watch/home/watch_extension_home_screen.dart',
    usage: 'Échec de chargement extension',
    icon: Icons.error_outline_rounded,
    kind: _PreviewKind.error,
    result: (_) => const _GalleryErrorPreview(),
  ),
  _ComponentSpec(
    section: 'SECTIONS RÉUTILISABLES',
    title: 'Swipe 3 × 3',
    className: 'ThreeColumnSwipeSection<T>',
    path: 'lib/modules/widgets/component_library.dart',
    usage: '3 colonnes × 3 lignes, pagination horizontale',
    icon: Icons.swipe_rounded,
    kind: _PreviewKind.swipeSection,
    result: (_) => ThreeColumnSwipeSection<TmdbMedia>(
      title: 'Sélection',
      items: [..._tmdbItems, ..._tmdbItems].take(9).toList(growable: false),
      itemHeight: 155,
      itemBuilder: (_, item) => SizedBox(
        width: 92,
        child: PosterCard(
          item: ContentItem.fromTmdb(item),
          width: 92,
          compact: true,
          onTap: () {},
        ),
      ),
    ),
  ),
];

/*
List<_ComponentSpec> _buildLibraryComponents() => [
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · CARDS',
    title: 'Classic poster',
    className: 'ClassicPosterCard',
    usage: 'Poster vertical réutilisable',
    icon: Icons.local_movies_outlined,
    result: (_) => ClassicPosterCard(item: _libraryItems[0]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · CARDS',
    title: 'Compact media',
    className: 'CompactMediaCard',
    usage: 'Grilles denses et mobile',
    icon: Icons.grid_view_outlined,
    result: (_) => CompactMediaCard(item: _libraryItems[1]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · CARDS',
    title: 'Landscape media',
    className: 'LandscapeMediaCard',
    usage: 'Rail paysage standard',
    icon: Icons.panorama_outlined,
    result: (_) => LandscapeMediaCard(item: _libraryItems[2]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · CARDS',
    title: 'Featured media',
    className: 'FeaturedMediaCard',
    usage: 'Mise en avant avec overlay',
    icon: Icons.star_border_rounded,
    result: (_) => FeaturedMediaCard(item: _libraryItems[3]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · CARDS',
    title: 'Hero media',
    className: 'HeroMediaCard',
    usage: 'Hero riche avec description',
    icon: Icons.open_in_full_rounded,
    result: (_) => HeroMediaCard(item: _libraryItems[4]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · LECTURE',
    title: 'Episode library',
    className: 'EpisodeLibraryCard',
    usage: 'Screenshot, titre et durée',
    icon: Icons.play_circle_outline_rounded,
    result: (_) => EpisodeLibraryCard(item: _libraryItems[5]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · LECTURE',
    title: 'Season',
    className: 'SeasonLibraryCard',
    usage: 'Saison et nombre d’épisodes',
    icon: Icons.video_library_outlined,
    result: (_) => SeasonLibraryCard(item: _libraryItems[6]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · LECTURE',
    title: 'Continue watching',
    className: 'ContinueWatchingCard',
    usage: 'Reprise avec progression',
    icon: Icons.history_rounded,
    result: (_) => ContinueWatchingCard(item: _libraryItems[7]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · LECTURE',
    title: 'Recently watched',
    className: 'RecentlyWatchedCard',
    usage: 'Historique de lecture',
    icon: Icons.update_rounded,
    result: (_) => RecentlyWatchedCard(item: _libraryItems[8]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · LECTURE',
    title: 'Watchlist',
    className: 'WatchlistCard',
    usage: 'À regarder plus tard',
    icon: Icons.bookmark_border_rounded,
    result: (_) => WatchlistCard(item: _libraryItems[9]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · DISCOVERY',
    title: 'Recommendation',
    className: 'RecommendationCard',
    usage: 'Suggestion éditoriale',
    icon: Icons.recommend_rounded,
    result: (_) => RecommendationCard(item: _libraryItems[2]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · DISCOVERY',
    title: 'Similar media',
    className: 'SimilarMediaCard',
    usage: 'Contenus similaires',
    icon: Icons.compare_arrows_rounded,
    result: (_) => SimilarMediaCard(item: _libraryItems[1]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · DISCOVERY',
    title: 'Trending',
    className: 'TrendingCard',
    usage: 'Tendance du moment',
    icon: Icons.trending_up_rounded,
    result: (_) => TrendingCard(item: _libraryItems[0]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · DISCOVERY',
    title: 'Ranked media',
    className: 'RankedMediaCard',
    usage: 'Top avec rang visuel',
    icon: Icons.format_list_numbered_rounded,
    result: (_) => RankedMediaCard(item: _libraryItems[3], rank: 1),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Collection',
    className: 'CollectionCard',
    usage: 'Collection éditoriale',
    icon: Icons.collections_bookmark_outlined,
    result: (_) => CollectionCard(item: _libraryItems[10]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Saga',
    className: 'SagaCard',
    usage: 'Franchise avec backdrop',
    icon: Icons.auto_stories_outlined,
    result: (_) => SagaCard(item: _libraryItems[11]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Saga collection',
    className: 'SagaCollectionCard',
    usage: 'Franchise avec plusieurs posters',
    icon: Icons.view_carousel_outlined,
    result: (_) => SagaCollectionCard(item: _libraryItems[10]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Universe',
    className: 'UniverseCard',
    usage: 'Univers partagé',
    icon: Icons.public_rounded,
    result: (_) => UniverseCard(item: _libraryItems[11]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Studio',
    className: 'StudioCard',
    usage: 'Catalogue d’un studio',
    icon: Icons.business_outlined,
    result: (_) => StudioCard(item: _libraryItems[2]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Provider',
    className: 'ProviderCard',
    usage: 'Source de diffusion',
    icon: Icons.play_circle_outline_rounded,
    result: (_) => ProviderCard(item: _libraryItems[9]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Genre / category',
    className: 'GenreCard · CategoryCard',
    usage: 'Découverte par taxonomie',
    icon: Icons.category_outlined,
    result: (_) => GenreCard(item: _libraryItems[10]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · COLLECTIONS',
    title: 'Country / language',
    className: 'CountryCard · LanguageCard',
    usage: 'Filtres pays et langue',
    icon: Icons.translate_rounded,
    result: (_) => CountryCard(item: _libraryItems[11]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Playlist',
    className: 'PlaylistCard',
    usage: 'Playlist carrée',
    icon: Icons.queue_music_rounded,
    result: (_) => PlaylistCard(item: _libraryItems[12]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Playlist grid',
    className: 'PlaylistGridCard',
    usage: 'Grille de playlists',
    icon: Icons.grid_view_rounded,
    result: (_) => PlaylistGridCard(item: _libraryItems[13]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Playlist featured',
    className: 'PlaylistFeaturedCard',
    usage: 'Playlist mise en avant',
    icon: Icons.featured_play_list_outlined,
    result: (_) => PlaylistFeaturedCard(item: _libraryItems[12]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Album',
    className: 'AlbumCard',
    usage: 'Album avec artwork',
    icon: Icons.album_outlined,
    result: (_) => AlbumCard(item: _libraryItems[13]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Artist',
    className: 'ArtistCard',
    usage: 'Artiste en avatar',
    icon: Icons.person_outline_rounded,
    result: (_) => ArtistCard(item: _libraryItems[14]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Track',
    className: 'TrackCard',
    usage: 'Ligne titre, artiste et durée',
    icon: Icons.music_note_rounded,
    result: (_) => TrackCard(item: _libraryItems[15]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Now playing',
    className: 'NowPlayingCard',
    usage: 'Titre actif avec progression',
    icon: Icons.equalizer_rounded,
    result: (_) => NowPlayingCard(item: _libraryItems[16]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MUSIC',
    title: 'Music collection',
    className: 'MusicCollectionCard',
    usage: 'Collection musicale',
    icon: Icons.library_music_outlined,
    result: (_) => MusicCollectionCard(item: _libraryItems[13]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Chapter',
    className: 'ChapterCard',
    usage: 'Chapitre et durée de lecture',
    icon: Icons.menu_book_outlined,
    result: (_) => ChapterCard(item: _libraryItems[17]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Reading progress',
    className: 'ReadingProgressCard',
    usage: 'Progression de lecture',
    icon: Icons.auto_stories_outlined,
    result: (_) => ReadingProgressCard(item: _libraryItems[18]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Library book',
    className: 'LibraryBookCard',
    usage: 'Livre dans la bibliothèque',
    icon: Icons.book_outlined,
    result: (_) => LibraryBookCard(item: _libraryItems[19]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Author',
    className: 'AuthorCard',
    usage: 'Auteur en avatar',
    icon: Icons.edit_outlined,
    result: (_) => AuthorCard(item: _libraryItems[14]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Series collection',
    className: 'SeriesCollectionCard',
    usage: 'Série éditoriale',
    icon: Icons.collections_bookmark_outlined,
    result: (_) => SeriesCollectionCard(item: _libraryItems[10]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · MANGA & LECTURE',
    title: 'Reading continue / history',
    className: 'ReadingContinueCard · ReadingHistoryCard',
    usage: 'Reprise et historique manga',
    icon: Icons.history_edu_rounded,
    result: (_) => ReadingContinueCard(item: _libraryItems[18]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Person / avatar',
    className: 'PersonCard · AvatarCard',
    usage: 'Personne et avatar',
    icon: Icons.account_circle_outlined,
    result: (_) => PersonCard(item: _libraryItems[14]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Video',
    className: 'VideoCard',
    usage: 'Vidéo avec action play',
    icon: Icons.ondemand_video_outlined,
    result: (_) => VideoCard(item: _libraryItems[5]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Spotlight',
    className: 'SpotlightCard',
    usage: 'Coup de cœur éditorial',
    icon: Icons.highlight_rounded,
    result: (_) => SpotlightCard(item: _libraryItems[4]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Banner / wallpaper',
    className: 'BannerCard · WallpaperCard',
    usage: 'Bannière et backdrop',
    icon: Icons.wallpaper_outlined,
    result: (_) => BannerCard(item: _libraryItems[4]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Promo / announcement',
    className: 'PromoCard · AnnouncementCard',
    usage: 'Message promotionnel',
    icon: Icons.campaign_outlined,
    result: (_) => PromoCard(item: _libraryItems[20]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'News',
    className: 'NewsCard',
    usage: 'Actualité éditoriale',
    icon: Icons.newspaper_outlined,
    result: (_) => NewsCard(item: _libraryItems[20]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Profile',
    className: 'ProfileCard',
    usage: 'Profil avec métadonnées',
    icon: Icons.badge_outlined,
    result: (_) => ProfileCard(item: _libraryItems[14]),
  ),
  _libraryCardSpec(
    section: 'BIBLIOTHÈQUE · PEOPLE & SPECIAL',
    title: 'Badge / tag',
    className: 'BadgeCard · TagLibraryCard',
    usage: 'Labels et attributs',
    icon: Icons.local_offer_outlined,
    result: (_) => BadgeCard(item: _libraryItems[20]),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Horizontal rail',
    className: 'HorizontalRailSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Titre, action et contenu horizontal',
    icon: Icons.view_stream_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Films populaires',
      child: HorizontalRailSection<ComponentLibraryItem>(
        title: 'Films populaires',
        onSeeAll: () {},
        height: 188,
        items: _libraryItems.take(4).toList(),
        itemBuilder: (_, item) => CompactMediaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Compact rail',
    className: 'CompactRailSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Rail dense pour reprise',
    icon: Icons.view_agenda_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Continuer',
      child: CompactRailSection<ComponentLibraryItem>(
        title: 'Continuer',
        items: _libraryItems.skip(7).take(4).toList(),
        itemBuilder: (_, item) => ContinueWatchingCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Grid section',
    className: 'GridSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Grille responsive',
    icon: Icons.grid_4x4_rounded,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibrarySectionPreview(
      child: GridSection<ComponentLibraryItem>(
        title: 'Découvrir',
        items: _libraryItems.take(4).toList(),
        itemBuilder: (_, item) => CompactMediaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Two / three columns',
    className: 'TwoColumnSection · ThreeColumnSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Grilles adaptatives',
    icon: Icons.table_rows_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibrarySectionPreview(
      child: ThreeColumnSection<ComponentLibraryItem>(
        title: 'Nouveautés',
        items: _libraryItems.take(3).toList(),
        itemBuilder: (_, item) => CompactMediaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Featured / hero',
    className: 'FeaturedSection · HeroSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Section avec item principal',
    icon: Icons.featured_play_list_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibrarySectionPreview(
      child: HeroSection<ComponentLibraryItem>(
        title: 'À la une',
        item: _libraryItems[4],
        itemBuilder: (_, item) => HeroMediaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Ranking section',
    className: 'RankingSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Top avec rang injecté',
    icon: Icons.leaderboard_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibrarySectionPreview(
      child: RankingSection<ComponentLibraryItem>(
        title: 'Top du moment',
        items: _libraryItems.take(3).toList(),
        itemBuilder: (_, item, rank) => RankedMediaCard(item: item, rank: rank),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Collection / saga',
    className: 'CollectionSection · SagaSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Rails de regroupements',
    icon: Icons.collections_bookmark_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Collections',
      child: SagaSection<ComponentLibraryItem>(
        title: 'Collections',
        items: _libraryItems.skip(10).take(2).toList(),
        itemBuilder: (_, item) => SagaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Mixed / spotlight',
    className: 'MixedContentSection · SpotlightSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Mélange et mise en avant',
    icon: Icons.auto_awesome_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibrarySectionPreview(
      child: SpotlightSection<ComponentLibraryItem>(
        title: 'Coup de cœur',
        item: _libraryItems[4],
        itemBuilder: (_, item) => SpotlightCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Banner / carousel',
    className: 'BannerSection · CarouselSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Bannières et carrousels',
    icon: Icons.view_carousel_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Événements',
      child: BannerSection<ComponentLibraryItem>(
        title: 'Événements',
        items: _libraryItems.skip(20).take(2).toList(),
        itemBuilder: (_, item) => BannerCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Stacked / recent',
    className: 'StackedCardSection · RecentlyAddedSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Cartes empilées et ajouts récents',
    icon: Icons.layers_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Ajouts récents',
      child: RecentlyAddedSection<ComponentLibraryItem>(
        title: 'Ajouts récents',
        items: _libraryItems.take(4).toList(),
        itemBuilder: (_, item) => LandscapeMediaCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Continue watching',
    className: 'ContinueWatchingSection',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Rail de reprise',
    icon: Icons.play_circle_outline_rounded,
    kind: _PreviewKind.librarySection,
    result: (_) => _LibraryRailPreview(
      title: 'Reprendre la lecture',
      child: ContinueWatchingSection<ComponentLibraryItem>(
        title: 'Reprendre la lecture',
        items: _libraryItems.skip(7).take(3).toList(),
        itemBuilder: (_, item) => ContinueWatchingCard(item: item),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · SECTIONS',
    title: 'Swipe 3 × 3',
    className: 'ThreeColumnSwipeSection<T>',
    path: 'lib/modules/widgets/component_library.dart',
    usage: '3 colonnes × 3 lignes, pagination horizontale',
    icon: Icons.swipe_rounded,
    kind: _PreviewKind.swipeSection,
    result: (_) => _LibrarySectionPreview(
      child: ThreeColumnSwipeSection<ComponentLibraryItem>(
        title: 'Sélection',
        items: _libraryItems.take(9).toList(),
        itemHeight: 70,
        itemBuilder: (_, item) => CompactMediaCard(item: item, width: 92),
      ),
    ),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · ÉTATS',
    title: 'Loading / shimmer',
    className: 'ComponentSectionState · ComponentSectionSkeleton',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'État de chargement partagé',
    icon: Icons.hourglass_empty_rounded,
    kind: _PreviewKind.librarySection,
    result: (_) => const ComponentSectionSkeleton(height: 180),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · ÉTATS',
    title: 'Empty',
    className: 'ComponentSectionState',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'État vide réutilisable',
    icon: Icons.inbox_outlined,
    kind: _PreviewKind.librarySection,
    result: (_) => const ComponentSectionState(state: ComponentViewState.empty),
  ),
  _ComponentSpec(
    section: 'BIBLIOTHÈQUE · ÉTATS',
    title: 'Error',
    className: 'ComponentSectionState',
    path: 'lib/modules/widgets/component_library.dart',
    usage: 'Erreur avec retry',
    icon: Icons.error_outline_rounded,
    kind: _PreviewKind.librarySection,
    result: (_) => ComponentSectionState(
      state: ComponentViewState.error,
      onRetry: () {},
    ),
  ),
];

_ComponentSpec _libraryCardSpec({
  required String section,
  required String title,
  required String className,
  required String usage,
  required IconData icon,
  required Widget Function(BuildContext context) result,
}) =>
    _ComponentSpec(
      section: section,
      title: title,
      className: className,
      path: 'lib/modules/widgets/component_library.dart',
      usage: usage,
      icon: icon,
      kind: _PreviewKind.libraryCard,
      result: result,
    );

class _LibrarySectionPreview extends StatelessWidget {
  const _LibrarySectionPreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 340, child: child);
  }
}

class _LibraryRailPreview extends StatelessWidget {
  const _LibraryRailPreview({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 340, height: 215, child: child);
  }
}

final _libraryItems = <ComponentLibraryItem>[
  ComponentLibraryItem(
    id: 'dune',
    title: 'Dune : Deuxième partie',
    subtitle: '2024 · Science-fiction',
    description: 'Une longue description de démonstration pour tester la lisibilité.',
    imageUrl: 'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg',
    rating: 8.2,
    badge: 'NOUVEAU',
    meta: 'Film · 2h 46',
  ),
  const ComponentLibraryItem(
    id: 'no-image',
    title: 'Titre sans image',
    subtitle: 'État no image',
    rating: 7.8,
    badge: 'HD',
  ),
  ComponentLibraryItem(
    id: 'interstellar',
    title: 'Interstellar',
    subtitle: '2014 · Drame',
    imageUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/pbrkL804c8yAv3zBZR4QPEafpAR.jpg',
    rating: 8.4,
    meta: 'Film · 2h 49',
  ),
  ComponentLibraryItem(
    id: 'arcane',
    title: 'Arcane',
    subtitle: 'Série · Animation',
    imageUrl: 'https://image.tmdb.org/t/p/w500/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/rkB4LyZHo1NHXFEDHl8M3g1Q3Q.jpg',
    rating: 8.7,
    badge: 'TOP',
    meta: 'Saison 2',
  ),
  ComponentLibraryItem(
    id: 'one-piece',
    title: 'One Piece : le voyage continue',
    subtitle: '1122 épisodes · Aventure',
    imageUrl: 'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/m0bV4D3dZQYjF4gUeR5Y4kK8v8c.jpg',
    rating: 8.7,
    description: 'Une aventure sans fin, présentée dans un hero réutilisable.',
    meta: 'Anime · 24 min',
  ),
  ComponentLibraryItem(
    id: 'episode',
    title: 'Épisode 04 · Progress Day!',
    subtitle: 'Arcane · 42 min',
    imageUrl: 'https://image.tmdb.org/t/p/w780/rkB4LyZHo1NHXFEDHl8M3g1Q3Q.jpg',
    description: 'Une description suffisamment longue pour vérifier le clamp.',
    progress: .62,
    duration: const Duration(minutes: 42),
  ),
  const ComponentLibraryItem(
    id: 'season',
    title: 'Saison 2',
    subtitle: '9 épisodes',
    count: 9,
    badge: '2024',
  ),
  ComponentLibraryItem(
    id: 'continue',
    title: 'Reprendre One Piece',
    subtitle: 'Épisode 1089 · 12 min restantes',
    imageUrl: 'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
    progress: .74,
    duration: const Duration(minutes: 24),
  ),
  ComponentLibraryItem(
    id: 'history',
    title: 'The Last of Us',
    subtitle: 'Vu hier · épisode 5',
    imageUrl: 'https://image.tmdb.org/t/p/w500/uKvVjHNqB5VmOrdxqAt2F7J78ED.jpg',
    progress: 1,
  ),
  const ComponentLibraryItem(
    id: 'watchlist',
    title: 'À voir plus tard',
    subtitle: '12 contenus',
    badge: '12',
  ),
  ComponentLibraryItem(
    id: 'collection',
    title: 'Univers science-fiction',
    subtitle: '18 films · 4 séries',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/pbrkL804c8yAv3zBZR4QPEafpAR.jpg',
    count: 18,
  ),
  ComponentLibraryItem(
    id: 'saga',
    title: 'Saga Dune',
    subtitle: '3 films · Science-fiction',
    backdropUrl: 'https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg',
    count: 3,
  ),
  const ComponentLibraryItem(
    id: 'playlist',
    title: 'Night Drive',
    subtitle: '32 titres',
    badge: 'PLAYLIST',
    count: 32,
  ),
  const ComponentLibraryItem(
    id: 'album',
    title: 'Random Access Memories',
    subtitle: 'Daft Punk',
    badge: 'ALBUM',
  ),
  const ComponentLibraryItem(
    id: 'artist',
    title: 'Daft Punk',
    subtitle: 'Artiste',
    badge: 'ARTIST',
  ),
  const ComponentLibraryItem(
    id: 'track',
    title: 'Instant Crush',
    subtitle: 'Daft Punk · Random Access Memories',
    duration: Duration(minutes: 5, seconds: 37),
  ),
  const ComponentLibraryItem(
    id: 'now-playing',
    title: 'Midnight City',
    subtitle: 'M83 · Lecture en cours',
    progress: .48,
    duration: Duration(minutes: 4, seconds: 3),
  ),
  const ComponentLibraryItem(
    id: 'chapter',
    title: 'Chapitre 14 · Le dernier portail',
    subtitle: '12 pages restantes',
    progress: .38,
  ),
  const ComponentLibraryItem(
    id: 'reading',
    title: 'Solo Leveling',
    subtitle: 'Chapitre 187 · 38%',
    progress: .38,
  ),
  const ComponentLibraryItem(
    id: 'book',
    title: 'Le château ambulant',
    subtitle: 'Manga · 4 tomes',
    count: 4,
  ),
  const ComponentLibraryItem(
    id: 'promo',
    title: 'Nouvelle extension disponible',
    subtitle: 'Découvrez les derniers catalogues ajoutés.',
    badge: 'INFO',
  ),
];
*/

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
    collectionId: 'category_science-fiction',
    genre: ['Science-fiction', 'Aventure'],
  ),
  MManga(
    name: 'Interstellar',
    imageUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    collectionId: 'playlist_night-drive',
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

final _gallerySource = Source(
  id: 999999,
  name: 'Gallery Extension',
  lang: 'fr',
  itemType: ItemType.manga,
);

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
  _PreviewKind.genreSection => 214,
  _PreviewKind.mediaSection => 240,
  _PreviewKind.providersSection => 170,
  _PreviewKind.carousel => 220,
  _PreviewKind.episode => 170,
  _PreviewKind.detailEpisode => 170,
  _PreviewKind.wallpaper => 180,
  _PreviewKind.season => 168,
  _PreviewKind.cast => 168,
  _PreviewKind.trailer => 152,
  _PreviewKind.extensionHero => 240,
  _PreviewKind.rankedWide => 96,
  _PreviewKind.showcase => 205,
  _PreviewKind.collection => 126,
  _PreviewKind.banner => 154,
  _PreviewKind.creator => 168,
  _PreviewKind.studio => 190,
  _PreviewKind.searchGrid => 178,
  _PreviewKind.searchList => 96,
  _PreviewKind.searchCinema => 180,
  _PreviewKind.manga => 168,
  _PreviewKind.mangaList => 112,
  _PreviewKind.extensionGrid => 220,
  _PreviewKind.history => 96,
  _PreviewKind.historyGrid => 220,
  _PreviewKind.empty => 174,
  _PreviewKind.error => 174,
  _PreviewKind.libraryCard => 190,
  _PreviewKind.librarySection => 220,
  _PreviewKind.swipeSection => 520,
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
  _PreviewKind.genreSection => 340,
  _PreviewKind.mediaSection => 340,
  _PreviewKind.providersSection => 340,
  _PreviewKind.carousel => 112,
  _PreviewKind.episode => 220,
  _PreviewKind.detailEpisode => 220,
  _PreviewKind.wallpaper => 320,
  _PreviewKind.season => 112,
  _PreviewKind.cast => 112,
  _PreviewKind.trailer => 220,
  _PreviewKind.extensionHero => 320,
  _PreviewKind.rankedWide => 330,
  _PreviewKind.showcase => 300,
  _PreviewKind.collection => 190,
  _PreviewKind.banner => 300,
  _PreviewKind.creator => 112,
  _PreviewKind.studio => 300,
  _PreviewKind.searchGrid => 112,
  _PreviewKind.searchList => 330,
  _PreviewKind.searchCinema => 320,
  _PreviewKind.manga => 112,
  _PreviewKind.mangaList => 300,
  _PreviewKind.extensionGrid => 300,
  _PreviewKind.history => 330,
  _PreviewKind.historyGrid => 300,
  _PreviewKind.empty => 300,
  _PreviewKind.error => 300,
  _PreviewKind.libraryCard => 230,
  _PreviewKind.librarySection => 340,
  _PreviewKind.swipeSection => 340,
};
