import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/watchtower_home_screen.dart';
import 'package:watchtower/modules/home/widgets/discovery_card.dart';
import 'package:watchtower/modules/home/widgets/episode_card.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/collection_cards.dart';
import 'package:watchtower/modules/media/episode_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/media/ranking_cards.dart';
import 'package:watchtower/modules/media/rich_media_cards.dart';
import 'package:watchtower/modules/media/streaming_cards.dart';
import 'package:watchtower/modules/widgets/component_library.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';

enum _GalleryState { result, skeleton }

enum _GalleryTab { cards, sections }

enum _PreviewKind {
  poster,
  compactPoster,
  landscape,
  ranked,
  top3,
  mini,
  featured,
  saga,
  spotlight,
  tag,
  genre,
  mangaGenre,
  genreSection,
  mediaSection,
  providersSection,
  featuredStack,
  carousel,
  episode,
  detailEpisode,
  wallpaper,
  season,
  cast,
  trailer,
  extensionHero,
  homeHero,
  rankedWide,
  showcase,
  collection,
  banner,
  mangaSpotlight,
  creator,
  studio,
  searchGrid,
  searchList,
  searchCinema,
  manga,
  mangaList,
  mangaHome,
  mangaUpdateFeed,
  mangaRanking,
  mangaVote,
  mangaCollection,
  mangaTrending,
  mangaScanGroup,
  extensionGrid,
  history,
  historyGrid,
  empty,
  error,
  swipeSection,
  richDetails,
  richBackdrop,
  richExpanded,
  richInteractive,
  richHover,
  richQuickView,
  richPreview,
  richModal,
  streamContinue,
  streamContinueItem,
  streamResume,
  streamRecently,
  streamWatchAgain,
  streamNowPlaying,
  streamUpNext,
  streamNextEpisode,
  streamEpisode,
  streamSeason,
  streamSeriesEpisode,
  streamWatchProgress,
  streamProgressMedia,
  collCollection,
  collMovieCollection,
  collFranchise,
  collSaga,
  collStudio,
  collNetwork,
  collGenre,
  collActor,
  collDirector,
  collCharacter,
  collRelated,
  collSimilar,
  collTrending,
  collPopular,
  collTopRated,
  collRanked,
  collNumbered,
  collFeatured,
  collSpotlight,
  collRecommendation,
  collCarousel,
  epCompact,
  epThumbnail,
  epPreview,
  epListItem,
  epSeasonDetail,
  epFeatured,
  epNextHero,
  epLatest,
  epSelector,
  epSeriesList,
  epProgress,
  epMediaProgress,
  epUpNextCompact,
  epSeasonEpisode,
  epSeriesBanner,
  epCarousel,
  epSeasonBanner,
  epEpisodeList,
  epSeriesGrid,
  rankMovies,
  rankSeries,
  rankAnime,
  rankByGenre,
  rankByCountry,
  rankGlobal,
  rankTopRated,
  rankTrending,
  rankByDecade,
  rankMustWatch,
}

/// Ordre d'affichage des sections dans la galerie.
const _orderedGallerySections = <String>[
  'CATALOGUE & DISCOVERY',
  'CARTES RICHES',
  'STREAMING & PROGRESSION',
  'COLLECTIONS & FRANCHISES',
  'ÉPISODES & SAISONS',
  'CLASSEMENTS & TOP 10',
  'FILMS & SÉRIES · SECTIONS',
  'ACCUEIL & LECTURE',
  'DÉTAIL MÉDIA',
  'EXTENSIONS WATCH',
  'MANGA & LECTURE',
  'RECHERCHE',
  'HISTORIQUE & BIBLIOTHÈQUE',
  'ÉTATS & FEEDBACK',
  'SECTIONS RÉUTILISABLES',
];

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

  /// Sections displayed in the "Sections" tab instead of the "Cards" tab.
  static const _sectionNames = <String>{
    'FILMS & SÉRIES · SECTIONS',
    'EXTENSIONS WATCH',
    'SECTIONS RÉUTILISABLES',
  };

  bool get isSection => _ComponentSpec._sectionNames.contains(section);

  /// Clean identifier copied to the clipboard (main class only).
  String get copyName => className.split(' →').first.trim();

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
  _GalleryTab _tab = _GalleryTab.cards;
  String _query = '';

  /// Filtre de section actif (`null` = toutes les sections).
  String? _sectionFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ComponentSpec> get _components => _buildComponents();

  /// Sections présentes pour l'onglet courant, dans l'ordre du catalogue.
  List<String> _sectionsFor(_GalleryTab tab) {
    final isSectionsTab = tab == _GalleryTab.sections;
    final seen = <String>{};
    for (final component in _components) {
      if (component.isSection == isSectionsTab) seen.add(component.section);
    }
    final ordered = _orderedGallerySections.where(seen.contains).toList();
    ordered.addAll(
      seen.where((section) => !_orderedGallerySections.contains(section)).toList()
        ..sort(),
    );
    return ordered;
  }

  List<_ComponentSpec> get _visibleComponents {
    final query = _query.trim().toLowerCase();
    return _components
        .where((component) {
          final textMatches =
              query.isEmpty || component.searchableText.contains(query);
          final sectionMatches =
              _sectionFilter == null || component.section == _sectionFilter;
          return textMatches &&
              sectionMatches &&
              component.isSection == (_tab == _GalleryTab.sections);
        })
        .toList(growable: false);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _state = _GalleryState.result;
      _sectionFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppUI.pagePadding(context);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final sections = _sectionsFor(_tab);
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
            bottom: isWide
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(50),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 6, padding, 8),
                      child: _GalleryTabBar(
                        tab: _tab,
                        onChanged: (tab) => setState(() {
                          _tab = tab;
                          if (_sectionFilter != null &&
                              !_sectionsFor(tab).contains(_sectionFilter)) {
                            _sectionFilter = null;
                          }
                        }),
                      ),
                    ),
                  ),
            actions: [
              // Mode PC : sélecteur Cartes / Sections en haut à droite.
              if (isWide)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 212,
                    child: _GalleryTabBar(
                      tab: _tab,
                      onChanged: (tab) => setState(() {
                        _tab = tab;
                        if (_sectionFilter != null &&
                            !_sectionsFor(tab).contains(_sectionFilter)) {
                          _sectionFilter = null;
                        }
                      }),
                    ),
                  ),
                ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1900),
                  child: _GalleryHeader(
                    queryController: _searchController,
                    query: _query,
                    state: _state,
                    resultCount: visible.length,
                    sections: sections,
                    sectionFilter: _sectionFilter,
                    onQueryChanged: (query) => setState(() => _query = query),
                    onStateChanged: (state) => setState(() => _state = state),
                    onSectionChanged: (section) =>
                        setState(() => _sectionFilter = section),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 88),
            sliver: visible.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyGalleryState())
                : SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1900),
                        child: _UnifiedGallery(
                          components: visible,
                          state: _state,
                        ),
                      ),
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

/// Pinned tab bar at the very top of the gallery: Cards vs Sections.
class _GalleryTabBar extends StatelessWidget {
  final _GalleryTab tab;
  final ValueChanged<_GalleryTab> onChanged;

  const _GalleryTabBar({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF161A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _GalleryTabOption(
            icon: Icons.photo_size_select_large_rounded,
            label: 'Cartes',
            selected: tab == _GalleryTab.cards,
            accent: accent,
            onTap: () => onChanged(_GalleryTab.cards),
          ),
          _GalleryTabOption(
            icon: Icons.view_carousel_outlined,
            label: 'Sections',
            selected: tab == _GalleryTab.sections,
            accent: accent,
            onTap: () => onChanged(_GalleryTab.sections),
          ),
        ],
      ),
    );
  }
}

class _GalleryTabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _GalleryTabOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: .22) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? accent : Colors.white54),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  final TextEditingController queryController;
  final String query;
  final _GalleryState state;
  final int resultCount;
  final List<String> sections;
  final String? sectionFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_GalleryState> onStateChanged;
  final ValueChanged<String?> onSectionChanged;

  const _GalleryHeader({
    required this.queryController,
    required this.query,
    required this.state,
    required this.resultCount,
    required this.sections,
    required this.sectionFilter,
    required this.onQueryChanged,
    required this.onStateChanged,
    required this.onSectionChanged,
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
        _SectionFilterBar(
          sections: sections,
          selected: sectionFilter,
          onChanged: onSectionChanged,
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

/// Filtre de sections : chips horizontales « Toutes » + chaque section.
class _SectionFilterBar extends StatelessWidget {
  final List<String> sections;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _SectionFilterBar({
    required this.sections,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.filter_alt_rounded, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _SectionChip(
                  label: 'Toutes',
                  selected: selected == null,
                  onTap: () => onChanged(null),
                ),
                for (final section in sections)
                  _SectionChip(
                    label: section,
                    selected: selected == section,
                    onTap: () => onChanged(section),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: .22) : Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: .55)
                  : Colors.white.withValues(alpha: .12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
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

  const _UnifiedGallery({
    required this.state,
    required this.components,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<_ComponentSpec>>{};
    for (final component in components) {
      grouped.putIfAbsent(component.section, () => <_ComponentSpec>[]).add(component);
    }
    // Keep the catalogue in a stable, readable order instead of an
    // insertion-order soup where section labels end up interleaved.
    final orderedEntries = <MapEntry<String, List<_ComponentSpec>>>[
      ..._orderedGallerySections.where(grouped.containsKey).map(
            (section) => MapEntry(section, grouped[section]!),
          ),
      ...grouped.entries
          .where((entry) => !_orderedGallerySections.contains(entry.key)),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in orderedEntries) ...[
            _UnifiedSectionLabel(
              icon: _sectionIcon(entry.key),
              label: entry.key,
              count: entry.value.length,
            ),
            const SizedBox(height: 12),
            _ComponentGrid(components: entry.value, state: state),
            if (entry.key != orderedEntries.last.key) const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

IconData _sectionIcon(String section) {
  if (section.contains('EXTENSION')) return Icons.extension_outlined;
  if (section.contains('STREAMING')) return Icons.play_circle_outline_rounded;
  if (section.contains('COLLECTION')) return Icons.collections_bookmark_outlined;
  if (section.contains('ÉPISODES')) return Icons.subtitles_outlined;
  if (section.contains('CLASSEMENTS')) return Icons.leaderboard_outlined;
  if (section.contains('MANGA')) return Icons.menu_book_outlined;
  if (section.contains('RECHERCHE')) return Icons.search_rounded;
  if (section.contains('HISTORIQUE')) return Icons.history_rounded;
  if (section.contains('ÉTATS')) return Icons.checklist_rounded;
  if (section.contains('DÉTAIL')) return Icons.movie_filter_outlined;
  if (section.contains('ACCUEIL')) return Icons.home_outlined;
  if (section.contains('SECTIONS RÉUTILISABLES')) {
    return Icons.dashboard_customize_outlined;
  }
  if (section.contains('SECTIONS')) return Icons.view_carousel_outlined;
  return Icons.grid_view_rounded;
}

class _UnifiedSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _UnifiedSectionLabel({
    required this.icon,
    required this.label,
    this.count = 0,
  });

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
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: Colors.white10, thickness: 1, height: 1),
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
    const spacing = 18.0;
    const minimumTileWidth = 420.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columnCount = ((availableWidth + spacing) /
                (minimumTileWidth + spacing))
            .floor()
            .clamp(1, 3)
            .toInt();
        final tileWidth =
            (availableWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final component in components)
              SizedBox(
                width: tileWidth,
                child: _ComponentTile(component: component, state: state),
              ),
          ],
        );
      },
    );
  }
}

class _ComponentTile extends StatelessWidget {
  final _ComponentSpec component;
  final _GalleryState state;

  const _ComponentTile({required this.component, required this.state});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12171E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: 'Cliquer pour copier ${component.copyName}',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                var copied = false;
                try {
                  await Clipboard.setData(
                    ClipboardData(text: component.copyName),
                  );
                  copied = true;
                } catch (error) {
                  // Browser clipboard access can be denied by permissions or
                  // by the current browsing context. Keep this optional
                  // gallery action from surfacing as an uncaught app error.
                  debugPrint('[ComponentGallery] Clipboard copy failed: $error');
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        copied
                            ? '${component.copyName} copié'
                            : 'Impossible de copier ce nom dans le presse-papiers.',
                      ),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: .25),
                        ),
                      ),
                      child: Icon(component.icon, size: 17, color: accent),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            component.className,
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${component.title} · ${component.usage}',
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: Colors.white12,
              height: 1,
              thickness: 1,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1116),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: .05)),
            ),
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
      // ── Posters ──
      _PreviewKind.poster => const PosterSkeleton(width: 112),
      _PreviewKind.featured =>
        const PosterSkeleton(width: 180, ratio: 3 / 4, radius: 18),
      _PreviewKind.compactPoster =>
        const PosterSkeleton(width: 92, radius: 11, compact: true),
      _PreviewKind.carousel => const PosterSkeleton(width: 112, radius: 14),
      _PreviewKind.manga => const PosterSkeleton(width: 112),
      _PreviewKind.mangaHome => const PosterSkeleton(
          width: 168,
          radius: 16,
          titleInside: true,
        ),
      _PreviewKind.searchGrid =>
        const PosterSkeleton(width: 112, ratio: 3 / 4),
      _PreviewKind.top3 => const Top3Skeleton(),
      _PreviewKind.ranked || _PreviewKind.rankedWide =>
        const RankedRailSkeleton(),
      // ── Landscape ──
      _PreviewKind.landscape => const LandscapeSkeleton(width: 220),
      _PreviewKind.saga => const LandscapeSkeleton(width: 200, ratio: 16 / 10),
      _PreviewKind.spotlight => const SpotlightSkeleton(),
      _PreviewKind.mini => const TonightMiniSkeleton(),
      _PreviewKind.tag => const TagSkeleton(),
      _PreviewKind.genre => const SizedBox(
          width: 260,
          height: 112,
          child: AppGenreTileShimmer(),
        ),
      _PreviewKind.mangaGenre => const SizedBox(
          width: 118,
          height: 84,
          child: AppGenreTileShimmer(),
        ),
      _PreviewKind.genreSection => const AppGenreGridShimmer(),
      _PreviewKind.mediaSection => const MediaSectionSkeleton(),
      _PreviewKind.providersSection => const AppStreamingServicesShimmer(),
      _PreviewKind.featuredStack => const FeaturedStackSkeleton(),
      _PreviewKind.homeHero => const HomeHeroSkeleton(),
      _PreviewKind.extensionHero => const HomeHeroSkeleton(height: 480),
      _PreviewKind.episode => const EpisodeCardSkeleton(withProgress: true),
      _PreviewKind.detailEpisode => const EpisodeCardSkeleton(),
      _PreviewKind.trailer => const TrailerSkeleton(),
      _PreviewKind.wallpaper || _PreviewKind.studio ||
      _PreviewKind.searchCinema => const WallpaperSkeleton(),
      _PreviewKind.season => const SeasonSkeleton(),
      _PreviewKind.cast || _PreviewKind.creator => const CastSkeleton(),
      _PreviewKind.searchList || _PreviewKind.history =>
        const ListRowSkeleton(width: 330),
      _PreviewKind.mangaList =>
        const ListRowSkeleton(width: 330, plain: true, thumb: 62),
      _PreviewKind.showcase => const ShowcaseSkeleton(),
      _PreviewKind.collection => const ExtensionCollectionCardShimmer(),
      _PreviewKind.banner => const BannerSkeleton(),
      _PreviewKind.mangaSpotlight => const BannerSkeleton(width: 320, ratio: 16 / 9),
      _PreviewKind.extensionGrid => const MediaSectionSkeleton(),
      _PreviewKind.historyGrid => const PosterGridSkeleton(),
      _PreviewKind.mangaUpdateFeed => const LatestUpdateSkeleton(),
      _PreviewKind.mangaCollection => const LatestCollectionSkeleton(),
      _PreviewKind.mangaRanking => const MangaRankingSkeleton(),
      _PreviewKind.mangaVote => const VoteSkeleton(),
      _PreviewKind.mangaTrending => const TrendingListSkeleton(),
      _PreviewKind.mangaScanGroup => const ScanGroupSkeleton(),
      _PreviewKind.empty || _PreviewKind.error => const SizedBox(
          width: 300,
          height: 174,
          child: AppShimmerBlock(radius: 18),
        ),
      _PreviewKind.swipeSection => const SwipeSectionSkeleton(),
      // ── Cartes riches ──
      _PreviewKind.richDetails => const _RichDetailsSkeleton(),
      _PreviewKind.richBackdrop => const _RichBackdropSkeleton(),
      _PreviewKind.richExpanded => const _RichExpandedSkeleton(),
      _PreviewKind.richInteractive || _PreviewKind.richHover =>
        const _RichInteractiveSkeleton(),
      _PreviewKind.richQuickView => const _RichQuickViewSkeleton(),
      _PreviewKind.richPreview => const PosterSkeleton(width: 132),
      _PreviewKind.richModal => const _RichModalSkeleton(),
      // ── Streaming ──
      _PreviewKind.streamContinue =>
        const LandscapeSkeleton(width: 300, ratio: 4 / 3),
      _PreviewKind.streamContinueItem => const ListRowSkeleton(width: 380),
      _PreviewKind.streamResume =>
        const PosterSkeleton(width: 220, ratio: 1 / 1.3),
      _PreviewKind.streamRecently => const _StreamPanelSkeleton(),
      _PreviewKind.streamWatchAgain =>
        const PosterSkeleton(width: 200, ratio: 4 / 3),
      _PreviewKind.streamNowPlaying =>
        const LandscapeSkeleton(width: 380, ratio: 16 / 10),
      _PreviewKind.streamUpNext =>
        const LandscapeSkeleton(width: 240, ratio: 1 / 1.28),
      _PreviewKind.streamNextEpisode =>
        const LandscapeSkeleton(width: 240, ratio: 1 / 1.28),
      _PreviewKind.streamEpisode => const _StreamEpisodeListSkeleton(),
      _PreviewKind.streamSeason =>
        const LandscapeSkeleton(width: 280, ratio: 16 / 10),
      _PreviewKind.streamSeriesEpisode =>
        const ListRowSkeleton(width: 400, thumb: 58),
      _PreviewKind.streamWatchProgress =>
        const ListRowSkeleton(width: 400, thumb: 70),
      _PreviewKind.streamProgressMedia =>
        const ListRowSkeleton(width: 400, thumb: 70),
      // ── Collections & franchises ──
      _PreviewKind.collCollection => const _CollectionSkeleton(),
      _PreviewKind.collMovieCollection =>
        const _CollectionSkeleton(width: 400),
      _PreviewKind.collFranchise => const _CollectionSkeleton(width: 400),
      _PreviewKind.collSaga => const _CollectionSkeleton(width: 400),
      _PreviewKind.collStudio => const _CollectionSkeleton(width: 400),
      _PreviewKind.collNetwork => const _CollectionSkeleton(width: 400),
      _PreviewKind.collGenre => const _CollectionSkeleton(width: 400),
      _PreviewKind.collActor => const _CollectionSkeleton(width: 400),
      _PreviewKind.collDirector => const _CollectionSkeleton(width: 400),
      _PreviewKind.collCharacter => const _CollectionSkeleton(width: 400),
      _PreviewKind.collRelated => const _CollectionSkeleton(width: 400),
      _PreviewKind.collSimilar => const _PosterRowSkeleton(),
      _PreviewKind.collTrending => const _PosterRowSkeleton(count: 5),
      _PreviewKind.collPopular => const _PosterRowSkeleton(),
      _PreviewKind.collTopRated => const _PosterRowSkeleton(),
      _PreviewKind.collRanked => const _PosterRowSkeleton(count: 5),
      _PreviewKind.collNumbered => const _PosterRowSkeleton(count: 5, withHeader: false),
      _PreviewKind.collFeatured => const WallpaperSkeleton(),
      _PreviewKind.collSpotlight => const WallpaperSkeleton(),
      _PreviewKind.collRecommendation => const _PosterRowSkeleton(),
      _PreviewKind.collCarousel => const _PosterRowSkeleton(width: 420),
      // ── Épisodes & saisons ──
      _PreviewKind.epCompact => const ListRowSkeleton(width: 340, thumb: 70),
      _PreviewKind.epThumbnail => const EpisodeCardSkeleton(width: 240),
      _PreviewKind.epPreview => const ListRowSkeleton(width: 400),
      _PreviewKind.epListItem => const _StreamEpisodeListSkeleton(),
      _PreviewKind.epSeasonDetail =>
        const LandscapeSkeleton(width: 260, ratio: 4 / 3),
      _PreviewKind.epFeatured => const PosterSkeleton(width: 200, ratio: 2 / 3),
      _PreviewKind.epNextHero => const LandscapeSkeleton(width: 380, ratio: 2.2),
      _PreviewKind.epLatest => const WallpaperSkeleton(),
      _PreviewKind.epSelector => const _CollectionSkeleton(width: 420),
      _PreviewKind.epSeriesList => const _StreamEpisodeListSkeleton(),
      _PreviewKind.epProgress => const ListRowSkeleton(width: 380, thumb: 70),
      _PreviewKind.epMediaProgress =>
        const ListRowSkeleton(width: 380, thumb: 70),
      _PreviewKind.epUpNextCompact =>
        const LandscapeSkeleton(width: 240, ratio: 3 / 2),
      _PreviewKind.epSeasonEpisode =>
        const ListRowSkeleton(width: 380, thumb: 74),
      _PreviewKind.epSeriesBanner => const WallpaperSkeleton(),
      _PreviewKind.epCarousel =>
        const _PosterRowSkeleton(count: 5, withHeader: false),
      _PreviewKind.epSeasonBanner =>
        const LandscapeSkeleton(width: 420, ratio: 2.8),
      _PreviewKind.epEpisodeList => const _StreamEpisodeListSkeleton(),
      _PreviewKind.epSeriesGrid => const PosterGridSkeleton(),
      // ── Classements & Top 10 ──
      _PreviewKind.rankMovies => const _PosterRowSkeleton(),
      _PreviewKind.rankSeries => const _PosterRowSkeleton(),
      _PreviewKind.rankAnime => const _PosterRowSkeleton(),
      _PreviewKind.rankByGenre => const _PosterRowSkeleton(),
      _PreviewKind.rankByCountry => const _PosterRowSkeleton(),
      _PreviewKind.rankGlobal => const _PosterRowSkeleton(),
      _PreviewKind.rankTopRated => const _PosterRowSkeleton(),
      _PreviewKind.rankTrending => const _PosterRowSkeleton(),
      _PreviewKind.rankByDecade => const _PosterRowSkeleton(),
      _PreviewKind.rankMustWatch => const _PosterRowSkeleton(),
    };
    return card;
  }
}

/// ─── Skeleton building blocks ───────────────────────────────────────────

/// Skeleton for a poster card: image block + two title lines.
class PosterSkeleton extends StatelessWidget {
  const PosterSkeleton({
    this.width = 112,
    this.ratio = 2 / 3,
    this.radius = 12,
    this.compact = false,
    this.titleInside = false,
    super.key,
  });

  final double width;
  final double ratio;
  final double radius;
  final bool compact;

  /// Titles drawn over the image (MangaFeaturedCard style).
  final bool titleInside;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: radius),
                if (titleInside) ...[
                  const Positioned(
                    left: 10,
                    top: 10,
                    child: _ShimmerChip(width: 52, height: 16),
                  ),
                  const Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerLine(width: 110, height: 11),
                        SizedBox(height: 5),
                        _ShimmerLine(width: 46, height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!titleInside) ...[
            SizedBox(height: compact ? 5 : 6),
            const _ShimmerLine(width: 86, height: 11),
            const SizedBox(height: 5),
            const _ShimmerLine(width: 54, height: 9),
          ],
        ],
      ),
    );
  }
}

/// Horizontal rail of ranked posters (RankedCard / RankedDiscoveryCard).
class RankedRailSkeleton extends StatelessWidget {
  const RankedRailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 12),
                const Positioned(
                  left: 4,
                  bottom: 0,
                  child: _ShimmerChip(width: 26, height: 30, radius: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const _ShimmerLine(width: 96, height: 11),
        ],
      ),
    );
  }
}

/// 16:9 image + one title line (LandscapeCard and friends).
class LandscapeSkeleton extends StatelessWidget {
  const LandscapeSkeleton({
    this.width = 220,
    this.ratio = 16 / 9,
    super.key,
  });

  final double width;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: ratio,
            child: AppShimmerBlock(radius: 16),
          ),
          const SizedBox(height: 6),
          const _ShimmerLine(width: 150, height: 11),
          const SizedBox(height: 4),
          const _ShimmerLine(width: 40, height: 9),
        ],
      ),
    );
  }
}

/// Wide 2.5:1 spotlight card with overlay title.
class SpotlightSkeleton extends StatelessWidget {
  const SpotlightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: AspectRatio(
        aspectRatio: 2.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppShimmerBlock(radius: 18),
            const Positioned(
              left: 12,
              bottom: 12,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerLine(width: 150, height: 12),
                  SizedBox(height: 5),
                  _ShimmerLine(width: 90, height: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small landscape 1.44:1 tile + title (TmdbTonightMiniCard).
class TonightMiniSkeleton extends StatelessWidget {
  const TonightMiniSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.44,
            child: AppShimmerBlock(radius: 11),
          ),
          const SizedBox(height: 5),
          const _ShimmerLine(width: 120, height: 10),
        ],
      ),
    );
  }
}

/// Small tag pill row (TagCard).
class TagSkeleton extends StatelessWidget {
  const TagSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: AppShimmerBlock(radius: 8),
          ),
          SizedBox(width: 8),
          Expanded(child: _ShimmerLine(width: 140, height: 11)),
        ],
      ),
    );
  }
}

/// Section header + horizontal row of poster blocks
/// (ScrollingMovies / MediaGridSection / MediaPosterRail).
class MediaSectionSkeleton extends StatelessWidget {
  const MediaSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerLine(width: 110, height: 16),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                const Expanded(child: PosterSkeleton(width: 96)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Featured backdrop + secondary poster rail (TmdbFeaturedStack).
class FeaturedStackSkeleton extends StatelessWidget {
  const FeaturedStackSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerLine(width: 140, height: 16),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 340 / 230,
            child: AppShimmerBlock(radius: 18),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                const Expanded(child: PosterSkeleton(width: 100)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-height hero shimmer (MediaHeroCarousel / TmdbHeroCarousel).
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({this.height = 300, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AppShimmerBlock(radius: 0),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShimmerChip(width: 44, height: 18),
                SizedBox(height: 9),
                _ShimmerLine(width: 220, height: 20),
                SizedBox(height: 8),
                _ShimmerLine(width: 150, height: 11),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Center(
              child: _ShimmerChip(width: 56, height: 56, circle: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Episode card: 16:9 thumb with episode pill + progress inside,
/// then anime title + episode title.
class EpisodeCardSkeleton extends StatelessWidget {
  const EpisodeCardSkeleton({
    this.width = 220,
    this.withProgress = false,
    super.key,
  });

  final double width;
  final bool withProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 12),
                Positioned(
                  left: 8,
                  bottom: withProgress ? 14 : 8,
                  child: const _ShimmerLine(width: 34, height: 11),
                ),
                if (withProgress)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ShimmerLine(width: double.infinity, height: 3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _ShimmerLine(width: 150, height: 12),
          const SizedBox(height: 1),
          const _ShimmerLine(width: 110, height: 10),
        ],
      ),
    );
  }
}

/// Trailer slide: 16:9 thumb + one centered title line.
class TrailerSkeleton extends StatelessWidget {
  const TrailerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 12),
                Center(
                  child: _ShimmerChip(width: 44, height: 44, circle: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _ShimmerLine(width: 180, height: 11),
        ],
      ),
    );
  }
}

/// Detail wallpaper header: wide 320x180 block with title line below.
class WallpaperSkeleton extends StatelessWidget {
  const WallpaperSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppShimmerBlock(radius: 16),
            const Positioned(
              left: 14,
              bottom: 12,
              width: 180,
              child: _ShimmerLine(width: 180, height: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Season card: 2/3 poster with a bottom "Saison" band.
class SeasonSkeleton extends StatelessWidget {
  const SeasonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 12),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ShimmerLine(width: double.infinity, height: 26),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const _ShimmerLine(width: 70, height: 10),
        ],
      ),
    );
  }
}

/// Cast / creator circle avatar + two lines.
class CastSkeleton extends StatelessWidget {
  const CastSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 112,
      child: Column(
        children: [
          _ShimmerChip(width: 92, height: 92, circle: true),
          SizedBox(height: 8),
          _ShimmerLine(width: 80, height: 11),
          SizedBox(height: 3),
          _ShimmerLine(width: 56, height: 10),
        ],
      ),
    );
  }
}

/// History / search / manga-list row: thumb + title + subtitle.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({
    this.width = 330,
    this.plain = false,
    this.thumb = 76,
    super.key,
  });

  final double width;

  /// Transparent variant (MangaImageCardListTileWidget / MangaUpdateRow).
  final bool plain;

  /// Thumbnail width; the card height follows (thumb + padding).
  final double thumb;

  @override
  Widget build(BuildContext context) {
    final height = thumb + (plain ? 16 : 12);
    final content = Row(
      children: [
        SizedBox(
          width: thumb,
          height: thumb * 1.2,
          child: AppShimmerBlock(radius: 8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ShimmerLine(width: 150, height: 12),
              const SizedBox(height: 7),
              const _ShimmerLine(width: 110, height: 10),
              if (!plain) ...[
                const SizedBox(height: 7),
                const _ShimmerLine(width: double.infinity, height: 4),
              ],
            ],
          ),
        ),
        const SizedBox(width: 9),
        const _ShimmerChip(width: 18, height: 18),
      ],
    );
    if (plain) {
      return SizedBox(width: width, height: height, child: content);
    }
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}

/// Showcase layout: cover left, text right (MediaLandscapeRail style).
class ShowcaseSkeleton extends StatelessWidget {
  const ShowcaseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 202,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const SizedBox(
                  width: 92,
                  child: AppShimmerBlock(radius: 10),
                ),
                const SizedBox(width: 10),
                Expanded(child: AppShimmerBlock(radius: 10)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _ShimmerLine(width: 180, height: 13),
        ],
      ),
    );
  }
}

/// Full-width banner card with bottom title (MediaBannerRail, MangaBannerCard,
/// MangaSpotlightCard).
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({
    this.width = 340,
    this.ratio = 2.05,
    super.key,
  });

  final double width;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppShimmerBlock(radius: 18),
            const Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _ShimmerLine(width: 140, height: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top 3 triptych: three overlapping posters with a big rank number.
class Top3Skeleton extends StatelessWidget {
  const Top3Skeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: AppShimmerBlock(radius: 8)),
                ],
              ],
            ),
            const Positioned(
              left: 6,
              bottom: 2,
              child: _ShimmerLine(width: 26, height: 34),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of small posters + captions (LibraryGridViewWidget).
class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: AppShimmerBlock(radius: 10),
                  ),
                  const SizedBox(height: 5),
                  const _ShimmerLine(width: double.infinity, height: 9),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Latest-update feed card: portrait thumb + title + chapter rows.
class LatestUpdateSkeleton extends StatelessWidget {
  const LatestUpdateSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 92,
            height: 138,
            child: AppShimmerBlock(radius: 12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShimmerLine(width: 30, height: 10),
                const SizedBox(height: 6),
                const _ShimmerLine(width: 170, height: 14),
                const SizedBox(height: 12),
                for (var i = 0; i < 2; i++) ...[
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(child: _ShimmerLine(width: 120, height: 10)),
                      ],
                    ),
                  ),
                  if (i == 0) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top Ranking manga card: header + period toggle + 5 rank rows.
class MangaRankingSkeleton extends StatelessWidget {
  const MangaRankingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 430,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ShimmerChip(width: 20, height: 20, circle: true),
              const SizedBox(width: 8),
              const _ShimmerLine(width: 110, height: 15),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i == 1
                            ? Colors.white.withValues(alpha: .16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: _ShimmerLine(width: 52, height: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  const Expanded(child: _MangaRankRowSkeleton()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MangaRankRowSkeleton extends StatelessWidget {
  const _MangaRankRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ShimmerChip(width: 26, height: 26, circle: true),
        const SizedBox(width: 10),
        const SizedBox(
          width: 38,
          height: 54,
          child: AppShimmerBlock(radius: 8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ShimmerLine(width: 110, height: 12),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ShimmerChip(width: 13, height: 13, circle: true),
                  const SizedBox(width: 4),
                  const _ShimmerLine(width: 60, height: 10),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vote card: tilted cover stack + title + status pill + footer stats.
class VoteSkeleton extends StatelessWidget {
  const VoteSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      left: 0,
                      top: 8,
                      child: SizedBox(
                        width: 56,
                        height: 76,
                        child: AppShimmerBlock(radius: 8),
                      ),
                    ),
                    const Positioned(
                      left: 26,
                      top: 0,
                      child: SizedBox(
                        width: 60,
                        height: 84,
                        child: AppShimmerBlock(radius: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ShimmerLine(width: 150, height: 14),
                    const SizedBox(height: 10),
                    const _ShimmerChip(width: 110, height: 26),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _ShimmerChip(width: 16, height: 16, circle: true),
              const SizedBox(width: 5),
              const _ShimmerLine(width: 28, height: 11),
              const SizedBox(width: 14),
              _ShimmerChip(width: 16, height: 16, circle: true),
              const SizedBox(width: 5),
              const _ShimmerLine(width: 22, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Collection showcase: collage + big title + stats + author pill.
class LatestCollectionSkeleton extends StatelessWidget {
  const LatestCollectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 270,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(child: AppShimmerBlock(radius: 0)),
                    ],
                  ],
                ),
                const Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerLine(width: 230, height: 16),
                      SizedBox(height: 6),
                      _ShimmerLine(width: 160, height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                _ShimmerChip(width: 14, height: 14, circle: true),
                const SizedBox(width: 4),
                const _ShimmerLine(width: 44, height: 11),
              ],
              const Spacer(),
              _ShimmerChip(width: 30, height: 30, circle: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Trending list card: collage cover with badge + author row.
class TrendingListSkeleton extends StatelessWidget {
  const TrendingListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: 198,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(child: AppShimmerBlock(radius: 0)),
              ],
            ],
          ),
          const Positioned(
            left: 14,
            top: 14,
            child: _ShimmerChip(width: 104, height: 24),
          ),
          const Positioned(
            right: 14,
            top: 14,
            child: _ShimmerChip(width: 64, height: 20),
          ),
          const Positioned(
            left: 14,
            right: 74,
            bottom: 14,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AppShimmerBlock(radius: 8),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerLine(width: 120, height: 13),
                      SizedBox(height: 4),
                      _ShimmerLine(width: 84, height: 10),
                    ],
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

/// Scan group card: cover header + avatar + name + stats row.
class ScanGroupSkeleton extends StatelessWidget {
  const ScanGroupSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(child: AppShimmerBlock(radius: 0)),
                    ],
                  ],
                ),
                const Positioned(
                  left: 12,
                  top: 12,
                  child: _ShimmerChip(width: 38, height: 22),
                ),
                const Positioned(
                  right: 12,
                  top: 12,
                  child: _ShimmerChip(width: 52, height: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ShimmerChip(width: 56, height: 56, radius: 16),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: _ShimmerLine(width: 140, height: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ShimmerChip(width: 8, height: 8, circle: true),
                      const SizedBox(width: 7),
                      const _ShimmerLine(width: 170, height: 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 28),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ShimmerLine(width: 60, height: 14),
                            const SizedBox(height: 4),
                            _ShimmerLine(width: 56, height: 9),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe 3×3 section: header + 3 columns × 3 rows of small posters.
class SwipeSectionSkeleton extends StatelessWidget {
  const SwipeSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerLine(width: 90, height: 16),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (var r = 0; r < 3; r++)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: PosterSkeleton(width: 88, compact: true),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small shimmer pill / circle helper.
/// ─── Skeletons « cartes riches » ───────────────────────────────────────

/// MovieDetailsCard : poster + bloc texte + actions + rangée casting.
class _RichDetailsSkeleton extends StatelessWidget {
  const _RichDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 92,
                height: 138,
                child: AppShimmerBlock(radius: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerLine(width: 130, height: 14),
                    const SizedBox(height: 7),
                    _ShimmerLine(width: 90, height: 10),
                    const SizedBox(height: 10),
                    _ShimmerLine(width: 60, height: 11),
                    const SizedBox(height: 10),
                    _ShimmerLine(width: double.infinity, height: 9),
                    const SizedBox(height: 5),
                    _ShimmerLine(width: 140, height: 9),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(height: 32, child: AppShimmerBlock(radius: 11)),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 32, height: 32, child: AppShimmerBlock(radius: 11)),
              const SizedBox(width: 8),
              SizedBox(width: 32, height: 32, child: AppShimmerBlock(radius: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _ShimmerChip(width: 46, height: 46, circle: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// MovieDetailCard : bandeau image + texte + deux boutons.
class _RichBackdropSkeleton extends StatelessWidget {
  const _RichBackdropSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            width: double.infinity,
            child: AppShimmerBlock(radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerLine(width: 120, height: 14),
                const SizedBox(height: 7),
                _ShimmerLine(width: 100, height: 10),
                const SizedBox(height: 6),
                _ShimmerLine(width: 50, height: 10),
                const SizedBox(height: 10),
                _ShimmerLine(width: double.infinity, height: 9),
                const SizedBox(height: 4),
                _ShimmerLine(width: 130, height: 9),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(height: 32, child: AppShimmerBlock(radius: 11)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 84, height: 32, child: AppShimmerBlock(radius: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ExpandedMovieCard : poster + badge + lignes étendues.
class _RichExpandedSkeleton extends StatelessWidget {
  const _RichExpandedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 14),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _ShimmerChip(width: 56, height: 20, radius: 8),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _ShimmerChip(width: 28, height: 28, circle: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ShimmerLine(width: 130, height: 13),
          const SizedBox(height: 7),
          _ShimmerLine(width: 100, height: 10),
          const SizedBox(height: 6),
          _ShimmerLine(width: 50, height: 10),
          const SizedBox(height: 10),
          _ShimmerLine(width: double.infinity, height: 9),
          const SizedBox(height: 5),
          _ShimmerLine(width: 170, height: 9),
          const SizedBox(height: 5),
          _ShimmerLine(width: 150, height: 9),
        ],
      ),
    );
  }
}

/// InteractiveMovieCard / HoverMovieCard : plein poster + actions.
class _RichInteractiveSkeleton extends StatelessWidget {
  const _RichInteractiveSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppShimmerBlock(radius: 18),
            Positioned(
              right: 10,
              top: 10,
              child: _ShimmerChip(width: 28, height: 28, circle: true),
            ),
            const Positioned(
              left: 14,
              right: 40,
              bottom: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerLine(width: 110, height: 13),
                  SizedBox(height: 6),
                  _ShimmerLine(width: 70, height: 10),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  _ShimmerChip(width: 32, height: 32, circle: true),
                  const SizedBox(width: 7),
                  _ShimmerChip(width: 28, height: 28, circle: true),
                  const SizedBox(width: 7),
                  _ShimmerChip(width: 28, height: 28, circle: true),
                  const SizedBox(width: 7),
                  _ShimmerChip(width: 28, height: 28, circle: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MovieQuickView : bandeau image + résumé + deux boutons.
class _RichQuickViewSkeleton extends StatelessWidget {
  const _RichQuickViewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppShimmerBlock(radius: 0),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _ShimmerChip(width: 28, height: 28, circle: true),
                ),
                const Positioned(
                  left: 14,
                  bottom: 10,
                  child: _ShimmerLine(width: 120, height: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerLine(width: 50, height: 10),
                const SizedBox(height: 8),
                _ShimmerLine(width: double.infinity, height: 9),
                const SizedBox(height: 4),
                _ShimmerLine(width: 160, height: 9),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(height: 32, child: AppShimmerBlock(radius: 11)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, height: 32, child: AppShimmerBlock(radius: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// MovieDetailsModal : contenu de la feuille modale.
class _RichModalSkeleton extends StatelessWidget {
  const _RichModalSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12151B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 86,
                height: 129,
                child: AppShimmerBlock(radius: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerLine(width: 150, height: 16),
                    const SizedBox(height: 8),
                    _ShimmerLine(width: 110, height: 10),
                    const SizedBox(height: 8),
                    _ShimmerLine(width: 60, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ShimmerLine(width: double.infinity, height: 9),
          const SizedBox(height: 5),
          _ShimmerLine(width: double.infinity, height: 9),
          const SizedBox(height: 5),
          _ShimmerLine(width: 200, height: 9),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(height: 34, child: AppShimmerBlock(radius: 11)),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 90, height: 34, child: AppShimmerBlock(radius: 11)),
              const SizedBox(width: 8),
              SizedBox(width: 34, height: 34, child: AppShimmerBlock(radius: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Streaming panel skeleton: header line + three poster thumbnails.
class _StreamPanelSkeleton extends StatelessWidget {
  const _StreamPanelSkeleton({this.width = 470});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerLine(width: 150, height: 12),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                        aspectRatio: 2 / 3,
                        child: AppShimmerBlock(radius: 10),
                      ),
                      const SizedBox(height: 7),
                      const _ShimmerLine(width: 76, height: 10),
                      const SizedBox(height: 4),
                      const _ShimmerLine(width: 48, height: 8),
                    ],
                  ),
                ),
                if (i < 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Collections skeleton: main tile + column of three side tiles.
class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton({this.width = 420, this.height = 132});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: height,
              child: AppShimmerBlock(radius: 14),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            height: height,
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  const Expanded(child: AppShimmerBlock(radius: 8)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Poster row skeleton: header line + row of small posters with captions.
class _PosterRowSkeleton extends StatelessWidget {
  const _PosterRowSkeleton({
    this.width = 430,
    this.count = 4,
    this.withHeader = true,
  });

  final double width;
  final int count;
  final bool withHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withHeader) ...[
            const _ShimmerLine(width: 130, height: 12),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AspectRatio(
                        aspectRatio: 2 / 3,
                        child: AppShimmerBlock(radius: 10),
                      ),
                      const SizedBox(height: 6),
                      const _ShimmerLine(width: 56, height: 9),
                      const SizedBox(height: 4),
                      const _ShimmerLine(width: 34, height: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Streaming episode list skeleton: season header + three rows.
class _StreamEpisodeListSkeleton extends StatelessWidget {
  const _StreamEpisodeListSkeleton({this.width = 330});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerLine(width: 90, height: 12),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                const SizedBox(
                  width: 54,
                  height: 54,
                  child: AppShimmerBlock(radius: 9),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShimmerLine(width: 120, height: 11),
                      SizedBox(height: 5),
                      _ShimmerLine(width: 60, height: 9),
                    ],
                  ),
                ),
                const _ShimmerChip(width: 26, height: 26, circle: true),
              ],
            ),
            if (i < 2) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ShimmerChip extends StatelessWidget {
  const _ShimmerChip({
    required this.width,
    required this.height,
    this.circle = false,
    this.radius = 7,
  });

  final double width;
  final double height;
  final bool circle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppLoadingColors.of(context).shimmerBase,
      highlightColor: AppLoadingColors.of(context).shimmerHighlight,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

/// One shimmer line; inside a SizedBox of the given size.
class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const AppShimmerBlock(radius: 5),
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
  // ── CARTES RICHES (MoviesBox) ──
  _ComponentSpec(
    title: 'Carte détails complète',
    className: 'MovieDetailsCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Note, casting et actions rapides',
    section: 'CARTES RICHES',
    icon: Icons.movie_creation_outlined,
    kind: _PreviewKind.richDetails,
    result: (_) => MovieDetailsCard(
      data: _richCardData(_tmdbItems[0]),
      castNames: const ['Timothée Chalamet', 'Zendaya', 'Rebecca Ferguson', 'Josh Brolin'],
    ),
  ),
  _ComponentSpec(
    title: 'Carte détail compacte',
    className: 'MovieDetailCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Image en arrière-plan plein cadre',
    section: 'CARTES RICHES',
    icon: Icons.image_outlined,
    kind: _PreviewKind.richBackdrop,
    result: (_) => MovieDetailCard(data: _richCardData(_tmdbItems[1])),
  ),
  _ComponentSpec(
    title: 'Carte extensible',
    className: 'ExpandedMovieCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Infos supplémentaires dépliables',
    section: 'CARTES RICHES',
    icon: Icons.unfold_more_rounded,
    kind: _PreviewKind.richExpanded,
    result: (_) => ExpandedMovieCard(
      data: _richCardData(_tmdbItems[2]),
      director: 'Denis Villeneuve',
      actors: const ['Timothée Chalamet', 'Zendaya', 'Rebecca Ferguson'],
    ),
  ),
  _ComponentSpec(
    title: 'Carte extensible auto',
    className: 'ExpandableMovieCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Le tap étend/replie la carte',
    section: 'CARTES RICHES',
    icon: Icons.expand_more_rounded,
    kind: _PreviewKind.richExpanded,
    result: (_) => ExpandableMovieCard(
      data: _richCardData(_tmdbItems[3]),
      director: 'Denis Villeneuve',
      actors: const ['Timothée Chalamet', 'Zendaya'],
    ),
  ),
  _ComponentSpec(
    title: 'Carte interactive',
    className: 'InteractiveMovieCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Survol/clic révèle les actions rapides',
    section: 'CARTES RICHES',
    icon: Icons.touch_app_outlined,
    kind: _PreviewKind.richInteractive,
    result: (_) => InteractiveMovieCard(data: _richCardData(_tmdbItems[4])),
  ),
  _ComponentSpec(
    title: 'Carte effet survol',
    className: 'HoverMovieCard',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'La fiche glisse par-dessus le poster',
    section: 'CARTES RICHES',
    icon: Icons.mouse_rounded,
    kind: _PreviewKind.richHover,
    result: (_) => HoverMovieCard(data: _richCardData(_tmdbItems[0])),
  ),
  _ComponentSpec(
    title: 'Aperçu rapide',
    className: 'MovieQuickView',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Aperçu rapide avec fond image et fermer',
    section: 'CARTES RICHES',
    icon: Icons.quick_contacts_mail_outlined,
    kind: _PreviewKind.richQuickView,
    result: (_) =>
        MovieQuickView(data: _richCardData(_tmdbItems[1]), onClose: () {}),
  ),
  _ComponentSpec(
    title: 'Aperçu rapide média',
    className: 'MediaQuickView',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Alias générique de MovieQuickView',
    section: 'CARTES RICHES',
    icon: Icons.dashboard_customize_rounded,
    kind: _PreviewKind.richQuickView,
    result: (_) =>
        MediaQuickView(data: _richCardData(_tmdbItems[2]), onClose: () {}),
  ),
  _ComponentSpec(
    title: 'Aperçu poster',
    className: 'MoviePreview',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Poster + note + bouton play',
    section: 'CARTES RICHES',
    icon: Icons.preview_outlined,
    kind: _PreviewKind.richPreview,
    result: (_) => MoviePreview(data: _richCardData(_tmdbItems[3])),
  ),
  _ComponentSpec(
    title: 'Aperçu poster média',
    className: 'MediaPreview',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Alias générique de MoviePreview',
    section: 'CARTES RICHES',
    icon: Icons.preview_rounded,
    kind: _PreviewKind.richPreview,
    result: (_) => MediaPreview(data: _richCardData(_tmdbItems[4])),
  ),
  _ComponentSpec(
    title: 'Modale détails',
    className: 'MovieDetailsModal',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Feuille modale détails rapides',
    section: 'CARTES RICHES',
    icon: Icons.picture_in_picture_alt_rounded,
    kind: _PreviewKind.richModal,
    result: (_) => MovieDetailsModal(data: _richCardData(_tmdbItems[0])),
  ),
  _ComponentSpec(
    title: 'Modale détails média',
    className: 'MediaDetailsModal',
    path: 'lib/modules/media/rich_media_cards.dart',
    usage: 'Alias générique de MovieDetailsModal',
    section: 'CARTES RICHES',
    icon: Icons.picture_in_picture_alt_outlined,
    kind: _PreviewKind.richModal,
    result: (_) => MediaDetailsModal(data: _richCardData(_tmdbItems[1])),
  ),
  // ── STREAMING & PROGRESSION ──
  _ComponentSpec(
    title: 'Reprise de lecture',
    className: 'ContinueWatchingCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Visuel, progression et actions de reprise',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.play_circle_outline_rounded,
    kind: _PreviewKind.streamContinue,
    result: (_) => ContinueWatchingCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        remainingLabel: '18 min restantes',
        badge: 'En cours',
        progress: .62,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Élément compact à reprendre',
    className: 'ContinueWatchingItem',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Ligne compacte pour une liste à reprendre',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.format_list_bulleted_rounded,
    kind: _PreviewKind.streamContinueItem,
    result: (_) => ContinueWatchingItem(
      data: _streamCardData(
        _tmdbItems[3],
        seriesMeta: 'S3 • Ép. 5',
        remainingLabel: '18 min restantes',
        progress: .67,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Carte de reprise rapide',
    className: 'ResumeWatchingCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Chip, play et barre de progression',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.history_rounded,
    kind: _PreviewKind.streamResume,
    result: (_) => ResumeWatchingCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        badge: 'Reprise rapide',
        progress: .67,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Récemment regardés',
    className: 'RecentlyWatchedCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Panneau à trois posters + voir tout',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.recent_actors_outlined,
    kind: _PreviewKind.streamRecently,
    result: (_) => RecentlyWatchedCard(
      items: [
        _streamEpisode(_tmdbItems[3], meta: 'S3 • Ép. 5'),
        _streamEpisode(_tmdbItems[4], meta: 'S1 • Ép. 6'),
        _streamEpisode(_tmdbItems[2], meta: 'Film • 2h 30min'),
      ],
      onSeeAll: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Carte à revoir',
    className: 'WatchAgainCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Chip « À revoir » et bouton Revoir',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.refresh_rounded,
    kind: _PreviewKind.streamWatchAgain,
    result: (_) => WatchAgainCard(
      data: _streamCardData(
        _tmdbItems[3],
        seriesMeta: 'S1 • Ép. 1',
        badge: 'À revoir',
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Lecture en cours',
    className: 'NowPlayingCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Large visuel, badges HD et actions',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.live_tv_outlined,
    kind: _PreviewKind.streamNowPlaying,
    result: (_) => NowPlayingCard(
      data: _streamCardData(
        _tmdbItems[0],
        extraMeta: '© 2024 · Science-Fiction · 2h 46min',
        badge: 'En cours',
      ),
      hd: true,
    ),
  ),
  _ComponentSpec(
    title: 'Prochain épisode',
    className: 'UpNextCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Compte à rebours et rappel',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.update_rounded,
    kind: _PreviewKind.streamUpNext,
    result: (_) => UpNextCard(
      data: _streamCardData(
        _tmdbItems[3],
        seriesMeta: 'S4 • Ép. 5',
        extraMeta: '45 min',
      ),
      countdownLabel: 'J-1',
      countdownTime: '12h 36m',
      onReminder: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Épisode suivant',
    className: 'NextEpisodeCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Dispo imminente, play et progression',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.skip_next_rounded,
    kind: _PreviewKind.streamNextEpisode,
    result: (_) => NextEpisodeCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 8',
        progress: .12,
      ),
      availableLabel: 'Dans 5 min',
    ),
  ),
  _ComponentSpec(
    title: 'Liste d\'épisodes',
    className: 'EpisodeCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Saison dépliable, épisodes courant/verrouillé',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.playlist_play_rounded,
    kind: _PreviewKind.streamEpisode,
    result: (_) => EpisodeCard(
      seasonLabel: 'Saison 1',
      episodes: [
        _streamEpisode(
          _tmdbItems[4],
          title: 'Épisode 7',
          meta: '24 min',
        ),
        _streamEpisode(
          _tmdbItems[3],
          title: 'Épisode 8',
          meta: '24 min',
          isCurrent: true,
        ),
        _streamEpisode(
          _tmdbItems[2],
          title: 'Épisode 9',
          meta: '24 min',
          isLocked: true,
        ),
      ],
      onSeasonTap: () {},
    ),
  ),
  _ComponentSpec(
    title: 'Carte de saison',
    className: 'SeasonCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Voir la saison + sélecteur S1…S4',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.video_library_outlined,
    kind: _PreviewKind.streamSeason,
    result: (_) => SeasonCard(
      data: _streamCardData(_tmdbItems[3]),
      seasonLabel: 'Saison 4',
      episodesLabel: '10 épisodes • 2014',
      selectedSeason: 3,
      onSeasonSelected: (_) {},
    ),
  ),
  _ComponentSpec(
    title: 'Série + épisode compact',
    className: 'SeriesEpisodeCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Rangée horizontale avec play et chevron',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.tv_rounded,
    kind: _PreviewKind.streamSeriesEpisode,
    result: (_) => SeriesEpisodeCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        extraMeta: '42 min',
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Progression visuelle',
    className: 'WatchProgressCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Barre de progression et pourcentage',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.speed_rounded,
    kind: _PreviewKind.streamWatchProgress,
    result: (_) => WatchProgressCard(
      data: _streamCardData(
        _tmdbItems[3],
        seriesMeta: 'S3 • Ép. 5',
        progress: .68,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Barre de progression',
    className: 'ProgressMediaCard',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Style barre + bouton play',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.timelapse_rounded,
    kind: _PreviewKind.streamProgressMedia,
    result: (_) => ProgressMediaCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        progress: .72,
      ),
      style: ProgressMediaStyle.bar,
    ),
  ),
  _ComponentSpec(
    title: 'Barre de progression (%)',
    className: 'ProgressMediaCard(percent)',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Pourcentage affiché à droite',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.timelapse_rounded,
    kind: _PreviewKind.streamProgressMedia,
    result: (_) => ProgressMediaCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        progress: .72,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Barre de progression (chip)',
    className: 'ProgressMediaCard(chip)',
    path: 'lib/modules/media/streaming_cards.dart',
    usage: 'Pastille de pourcentage sur la vignette',
    section: 'STREAMING & PROGRESSION',
    icon: Icons.timelapse_rounded,
    kind: _PreviewKind.streamProgressMedia,
    result: (_) => ProgressMediaCard(
      data: _streamCardData(
        _tmdbItems[4],
        seriesMeta: 'S1 • Ép. 6',
        progress: .72,
      ),
      style: ProgressMediaStyle.chip,
    ),
  ),
  // ── COLLECTIONS & FRANCHISES ──
  _ComponentSpec(
    title: 'Collection de films/séries',
    className: 'CollectionCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Univers principal + tuiles d’autres collections',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.collections_bookmark_outlined,
    kind: _PreviewKind.collCollection,
    result: (_) => CollectionCard(
      data: _collectionData(
        _collItem(
          'Marvel Cinematic Universe',
          poster: _posterDune,
          backdrop: _backdropDune,
        ),
        stats: '32 films · 18 séries · 1 franchise',
        actionLabel: 'Voir la collection',
      ),
      sideEntries: [
        _collectionEntry('Star Wars', thumbUrl: _posterThrones),
        _collectionEntry('Harry Potter', thumbUrl: _posterInterstellar),
        _collectionEntry('DC', thumbUrl: _posterArcane),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Collection de films',
    className: 'MovieCollectionCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Trilogie / saga + posters latéraux',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.local_movies_outlined,
    kind: _PreviewKind.collMovieCollection,
    result: (_) => MovieCollectionCard(
      data: _collectionData(
        _collItem(
          'The Dark Knight Trilogy',
          poster: _posterInterstellar,
          backdrop: _backdropInterstellar,
        ),
        stats: '3 films · Action · Thriller',
        actionLabel: 'Voir la saga',
      ),
      sideEntries: [
        _collectionEntry('Batman Begins', thumbUrl: _posterThrones),
        _collectionEntry('The Dark Knight', thumbUrl: _posterArcane),
        _collectionEntry('The Dark Knight Rises', thumbUrl: _posterDune),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Franchise',
    className: 'FranchiseCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Franchise spécifique, titre en grand',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.public,
    kind: _PreviewKind.collFranchise,
    result: (_) => FranchiseCard(
      data: _collectionData(
        _collItem(
          'Fast & Furious',
          poster: _posterOppenheimer,
          backdrop: _backdropOppenheimer,
        ),
        stats: '9 films · Action · Crime',
        actionLabel: 'Voir la franchise',
      ),
      sideEntries: [
        _collectionEntry('Fast X', thumbUrl: _posterDune),
        _collectionEntry('Hobbs & Shaw', thumbUrl: _posterThrones),
        _collectionEntry('Tokyo Drift', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Saga',
    className: 'SagaCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Saga littéraire ou film',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.auto_stories_outlined,
    kind: _PreviewKind.collSaga,
    result: (_) => SagaCard(
      data: _collectionData(
        _collItem(
          'Le Seigneur des Anneaux',
          poster: _posterArcane,
          backdrop: _backdropArcane,
        ),
        stats: '3 films · Aventure · Fantastique',
        actionLabel: 'Voir la saga',
      ),
      sideEntries: [
        _collectionEntry('La Communauté', thumbUrl: _posterInterstellar),
        _collectionEntry('Les Deux Tours', thumbUrl: _posterOppenheimer),
        _collectionEntry('Le Retour du Roi', thumbUrl: _posterThrones),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Studio de production',
    className: 'StudioCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Studio + tuiles d’autres studios',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.business_center_outlined,
    kind: _PreviewKind.collStudio,
    result: (_) => StudioCard(
      data: _collectionData(
        _collItem(
          'Pixar Animation Studios',
          poster: _posterArcane,
          backdrop: _backdropArcane,
        ),
        stats: '28 films · Animation · Famille',
        actionLabel: 'Voir les films',
      ),
      sideEntries: [
        _collectionEntry('Marvel Studios', thumbUrl: _posterDune),
        _collectionEntry('DreamWorks', thumbUrl: _posterInterstellar),
        _collectionEntry('DC Studios', thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Réseau TV',
    className: 'NetworkCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Réseau / plateforme + tuiles voisines',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.live_tv_outlined,
    kind: _PreviewKind.collNetwork,
    result: (_) => NetworkCard(
      data: _collectionData(
        _collItem(
          'Netflix Originals',
          poster: _posterDune,
          backdrop: _backdropDune,
        ),
        stats: '120 titres · Séries · Films',
        actionLabel: 'Voir la sélection',
      ),
      sideEntries: [
        _collectionEntry('HBO Max', thumbUrl: _posterThrones),
        _collectionEntry('Disney+', thumbUrl: _posterArcane),
        _collectionEntry('Prime Video', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Genre de contenu',
    className: 'GenreCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Genre + rangées de genres voisins',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.category_outlined,
    kind: _PreviewKind.collGenre,
    result: (_) => GenreCard(
      data: _collectionData(
        _collItem(
          'Action',
          poster: _posterOppenheimer,
          backdrop: _backdropOppenheimer,
        ),
        stats: '1 248 titres',
        description:
            'Des films et séries pleins d’adrénaline, d’aventure et de combats.',
        actionLabel: 'Voir tout',
      ),
      sideEntries: [
        _collectionEntry('Romance', thumbUrl: _posterArcane),
        _collectionEntry('Science-Fiction', thumbUrl: _posterInterstellar),
        _collectionEntry('Fantastique', thumbUrl: _posterThrones),
        _collectionEntry('Horreur', thumbUrl: _posterDune),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Acteur / Actrice',
    className: 'ActorCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Portrait, âge et filmographie',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.face_outlined,
    kind: _PreviewKind.collActor,
    result: (_) => ActorCard(
      data: _collectionData(
        _collItem(
          'Tom Holland',
          poster: _posterDune,
          backdrop: _backdropInterstellar,
        ),
        subtitle: 'Acteur · 27 ans',
        actionLabel: 'Voir la filmographie',
      ),
      sideEntries: [
        _collectionEntry('Spider-Man', thumbUrl: _posterThrones),
        _collectionEntry('Uncharted', thumbUrl: _posterArcane),
        _collectionEntry('The Crowded Room', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Réalisateur',
    className: 'DirectorCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Portrait et films marquants',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.videocam_outlined,
    kind: _PreviewKind.collDirector,
    result: (_) => DirectorCard(
      data: _collectionData(
        _collItem(
          'Christopher Nolan',
          poster: _posterOppenheimer,
          backdrop: _backdropDune,
        ),
        subtitle: 'Réalisateur · 54 ans',
        actionLabel: 'Voir les films',
      ),
      sideEntries: [
        _collectionEntry('Inception', thumbUrl: _posterInterstellar),
        _collectionEntry('Interstellar', thumbUrl: _posterDune),
        _collectionEntry('The Dark Knight', thumbUrl: _posterThrones),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Personnage',
    className: 'CharacterCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Fiche personnage + autres rôles',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.theater_comedy_outlined,
    kind: _PreviewKind.collCharacter,
    result: (_) => CharacterCard(
      data: _collectionData(
        _collItem(
          'Darth Vader',
          poster: _posterThrones,
          backdrop: _backdropOppenheimer,
        ),
        subtitle: 'Star Wars',
        actionLabel: 'Voir la fiche',
      ),
      sideEntries: [
        _collectionEntry('Luke Skywalker', thumbUrl: _posterArcane),
        _collectionEntry('Yoda', thumbUrl: _posterInterstellar),
        _collectionEntry('Leia Organa', thumbUrl: _posterDune),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Contenu lié',
    className: 'RelatedMediaCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Même univers, même équipe…',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.link_rounded,
    kind: _PreviewKind.collRelated,
    result: (_) => RelatedMediaCard(
      data: _collectionData(
        _collItem(
          'The Witcher',
          poster: _posterInterstellar,
          backdrop: _backdropInterstellar,
        ),
        subtitle: 'Même univers',
        actionLabel: 'Voir les contenus',
      ),
      sideEntries: [
        _collectionEntry(
          'The Witcher: Blood Origin',
          meta: 'Série',
          thumbUrl: _posterArcane,
        ),
        _collectionEntry(
          'The Witcher',
          meta: 'Jeux vidéo',
          thumbUrl: _posterDune,
        ),
        _collectionEntry(
          'Séries similaires',
          meta: 'Sélection',
          thumbUrl: _posterThrones,
        ),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Contenus similaires',
    className: 'SimilarMediaCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Même genre, même ambiance',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.recommend_outlined,
    kind: _PreviewKind.collSimilar,
    result: (_) => SimilarMediaCard(
      items: [
        _collectionEntry('Shadow and Bone',
            meta: 'S1 · Fantaisie', thumbUrl: _posterArcane),
        _collectionEntry('The 100',
            meta: 'S7 · Drame', thumbUrl: _posterThrones),
        _collectionEntry('The Vampire Diaries',
            meta: 'S9 · Fantastique', thumbUrl: _posterDune),
        _collectionEntry('Supernatural',
            meta: 'S15 · Fantastique', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Contenu tendance',
    className: 'TrendingCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Top actuel avec rangs',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.trending_up_rounded,
    kind: _PreviewKind.collTrending,
    result: (_) => TrendingCard(
      onSeeAll: () {},
      items: [
        _collectionEntry('Dune',
            meta: 'Film', thumbUrl: _posterDune, rank: 1),
        _collectionEntry('The Last of Us',
            meta: 'Série', thumbUrl: _posterThrones, rank: 2),
        _collectionEntry('Oppenheimer',
            meta: 'Film', thumbUrl: _posterOppenheimer, rank: 3),
        _collectionEntry('Wednesday',
            meta: 'Série', thumbUrl: _posterArcane, rank: 4),
        _collectionEntry('The Boys',
            meta: 'Série', thumbUrl: _posterInterstellar, rank: 5),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Contenu populaire',
    className: 'PopularCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Le plus de vues',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.visibility_rounded,
    kind: _PreviewKind.collPopular,
    result: (_) => PopularCard(
      onSeeAll: () {},
      items: [
        _collectionEntry('One Piece',
            meta: 'Animé', thumbUrl: _posterThrones, viewsLabel: '9.8M'),
        _collectionEntry('Stranger Things',
            meta: 'Série', thumbUrl: _posterArcane, viewsLabel: '8.2M'),
        _collectionEntry('L’Attaque des Titans',
            meta: 'Animé', thumbUrl: _posterDune, viewsLabel: '7.5M'),
        _collectionEntry('Squid Game',
            meta: 'Série', thumbUrl: _posterOppenheimer, viewsLabel: '6.9M'),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Mieux notés',
    className: 'TopRatedCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Notes IMDb / TMDB',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.star_rounded,
    kind: _PreviewKind.collTopRated,
    result: (_) => TopRatedCard(
      onSeeAll: () {},
      items: [
        _collectionEntry('Breaking Bad',
            meta: 'Série', thumbUrl: _posterThrones, rating: 9.5),
        _collectionEntry('Planète Terre',
            meta: 'Documentaire', thumbUrl: _posterArcane, rating: 9.4),
        _collectionEntry('Le Parrain',
            meta: 'Film', thumbUrl: _posterOppenheimer, rating: 9.3),
        _collectionEntry('Interstellar',
            meta: 'Film', thumbUrl: _posterInterstellar, rating: 9.2),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Classement Top 10',
    className: 'RankedMediaCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Top 10 / top 50 avec grands numéros',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.leaderboard_outlined,
    kind: _PreviewKind.collRanked,
    result: (_) => RankedMediaCard(
      onSeeAll: () {},
      items: [
        _collectionEntry('Dune',
            meta: 'Film', thumbUrl: _posterDune, rank: 1),
        _collectionEntry('The Last of Us',
            meta: 'Série', thumbUrl: _posterThrones, rank: 2),
        _collectionEntry('Spider-Man',
            meta: 'Film', thumbUrl: _posterOppenheimer, rank: 3),
        _collectionEntry('Stranger Things',
            meta: 'Série', thumbUrl: _posterArcane, rank: 4),
        _collectionEntry('Breaking Bad',
            meta: 'Série', thumbUrl: _posterInterstellar, rank: 5),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Carte numérotée',
    className: 'NumberedCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Top 10 compact, sans en-tête',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.format_list_numbered_rounded,
    kind: _PreviewKind.collNumbered,
    result: (_) => NumberedCard(
      items: [
        _collectionEntry('Dune', thumbUrl: _posterDune, rank: 1),
        _collectionEntry('The Batman', thumbUrl: _posterThrones, rank: 2),
        _collectionEntry('Interstellar',
            thumbUrl: _posterInterstellar, rank: 3),
        _collectionEntry('Inception',
            thumbUrl: _posterOppenheimer, rank: 4),
        _collectionEntry('The Witcher', thumbUrl: _posterArcane, rank: 5),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Contenu à la une',
    className: 'FeaturedCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Grand visuel + points de carrousel',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.stars_rounded,
    kind: _PreviewKind.collFeatured,
    result: (_) => FeaturedCard(
      data: _collectionData(
        _collItem(
          'House of the Dragon',
          poster: _posterArcane,
          backdrop: _backdropArcane,
        ),
        badge: 'À la une',
        stats: 'S1 · S2 · Fantastique',
        actionLabel: 'Regarder',
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Coup de projecteur',
    className: 'SpotlightCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Événement, nouveauté',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.flash_on_rounded,
    kind: _PreviewKind.collSpotlight,
    result: (_) => SpotlightCard(
      data: _collectionData(
        _collItem(
          'The Last of Us',
          poster: _posterThrones,
          backdrop: _backdropOppenheimer,
        ),
        badge: 'Nouveauté',
        stats: 'S1 · Drame · 2023',
        actionLabel: 'Voir',
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Recommandations',
    className: 'RecommendationCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Parce que vous avez aimé…',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.thumb_up_alt_outlined,
    kind: _PreviewKind.collRecommendation,
    result: (_) => RecommendationCard(
      onSeeAll: () {},
      items: [
        _collectionEntry('Arcane',
            meta: 'S1 · Animation', thumbUrl: _posterArcane),
        _collectionEntry('L’Attaque des Titans',
            meta: 'S4 · Action', thumbUrl: _posterDune),
        _collectionEntry('The Boys',
            meta: 'S3 · Action', thumbUrl: _posterThrones),
        _collectionEntry('Interstellar',
            meta: 'S2 · Animation', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Carrousel d’univers',
    className: 'CarouselCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Collections / univers avec flèches',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.view_carousel_outlined,
    kind: _PreviewKind.collCarousel,
    result: (_) => CarouselCard(
      onPrevious: () {},
      onNext: () {},
      universes: [
        _collectionEntry(
          'Univers DC',
          meta: 'Films · Comics',
          thumbUrl: _backdropDune,
        ),
        _collectionEntry(
          'Univers Harry Potter',
          meta: 'Films · Livres',
          thumbUrl: _backdropInterstellar,
        ),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Univers (alias)',
    className: 'UniverseCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Alias générique de FranchiseCard',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.explore_outlined,
    kind: _PreviewKind.collFranchise,
    result: (_) => UniverseCard(
      data: _collectionData(
        _collItem(
          'Star Wars Universe',
          poster: _posterThrones,
          backdrop: _backdropArcane,
        ),
        stats: '12 films · 9 séries',
        actionLabel: 'Explorer l’univers',
      ),
      sideEntries: [
        _collectionEntry('Mandalorian', thumbUrl: _posterArcane),
        _collectionEntry('Andor', thumbUrl: _posterDune),
        _collectionEntry('Ahsoka', thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Catégorie (alias)',
    className: 'CategoryCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Alias générique de GenreCard',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.category_rounded,
    kind: _PreviewKind.collGenre,
    result: (_) => CategoryCard(
      data: _collectionData(
        _collItem(
          'Science-Fiction',
          poster: _posterInterstellar,
          backdrop: _backdropInterstellar,
        ),
        stats: '864 titres',
        description: 'Anticipations, space opera et dystopies.',
        actionLabel: 'Voir la catégorie',
      ),
      sideEntries: [
        _collectionEntry('Space opera', thumbUrl: _posterDune),
        _collectionEntry('Dystopie', thumbUrl: _posterOppenheimer),
        _collectionEntry('Cyberpunk', thumbUrl: _posterArcane),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Casting (alias)',
    className: 'CastCard',
    path: 'lib/modules/media/collection_cards.dart',
    usage: 'Alias générique de ActorCard',
    section: 'COLLECTIONS & FRANCHISES',
    icon: Icons.people_outline,
    kind: _PreviewKind.collActor,
    result: (_) => CastCard(
      data: _collectionData(
        _collItem(
          'Scarlett Johansson',
          poster: _posterArcane,
          backdrop: _backdropOppenheimer,
        ),
        subtitle: 'Actrice · 41 ans',
        actionLabel: 'Voir la filmographie',
      ),
      sideEntries: [
        _collectionEntry('Black Widow', thumbUrl: _posterThrones),
        _collectionEntry('Her', thumbUrl: _posterInterstellar),
        _collectionEntry('Lucy', thumbUrl: _posterDune),
      ],
    ),
  ),
  // ── ÉPISODES & SAISONS ──
  _ComponentSpec(
    title: 'Épisode (format compact)',
    className: 'CompactEpisodeCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'EpisodeCard — carte d\'épisode simple',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.live_tv_outlined,
    kind: _PreviewKind.epCompact,
    result: (_) => CompactEpisodeCard(
      entry: _episodeEntry(
        'The Last of Us',
        meta: 'S1 · Ép. 3',
        subtitle: 'Long, Long Time',
        duration: '52 min',
        genres: ['Action', 'Drame'],
        hd: true,
        thumbUrl: _posterThrones,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Miniature d\'épisode',
    className: 'EpisodeThumbnail',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Grand format 16:9 avec play et HD',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.image_outlined,
    kind: _PreviewKind.epThumbnail,
    result: (_) => EpisodeThumbnail(
      entry: _episodeEntry(
        'Long, Long Time',
        meta: 'S1 · Ép. 3',
        subtitle: 'The Last of Us',
        duration: '52 min',
        rating: 8.7,
        hd: true,
        thumbUrl: _posterThrones,
        backdropUrl: _backdropInterstellar,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Épisode avec aperçu',
    className: 'EpisodePreviewCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Visuel + description + progression',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.play_circle_outline,
    kind: _PreviewKind.epPreview,
    result: (_) => EpisodePreviewCard(
      entry: _episodeEntry(
        'The Walking Dead',
        meta: 'S8 · Ép. 6',
        subtitle: 'Honor',
        duration: '42 min',
        description: 'Le groupe découvre une nouvelle menace dans la région.',
        progress: .68,
        hd: true,
        thumbUrl: _posterDune,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Liste d\'épisodes numérotée',
    className: 'EpisodeListItem',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Élément de liste : vu ▵ / play / verrouillé',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.view_list_outlined,
    kind: _PreviewKind.epListItem,
    result: (_) => EpisodeListItem(
      episodes: [
        _episodeEntry('Pilot', meta: 'S1', duration: '42 min',
            number: 1, watched: true, thumbUrl: _posterDune),
        _episodeEntry('The Things We Lost', meta: 'S1', duration: '41 min',
            number: 2, thumbUrl: _posterInterstellar),
        _episodeEntry('Long, Long Time', meta: 'S1', duration: '52 min',
            number: 3, current: true, thumbUrl: _posterOppenheimer),
        _episodeEntry('Please Hold', meta: 'S1', duration: '48 min',
            number: 4, locked: true, thumbUrl: _posterArcane),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Carte de saison',
    className: 'SeasonDetailCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'SeasonCard — visuel, stats et description',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.calendar_today_outlined,
    kind: _PreviewKind.epSeasonDetail,
    result: (_) => SeasonDetailCard(
      season: _seasonEntry(
        'Stranger Things',
        seasonLabel: 'Saison 4',
        stats: '9 épisodes · 2022',
        description:
            'La lutte contre Vecna s’intensifie alors que Hawkins est plus en danger que jamais.',
        thumbUrl: _backdropArcane,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Épisode de série mis en avant',
    className: 'FeaturedEpisodeCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'SeriesEpisodeCard — poster avec chip de saison',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.star_rounded,
    kind: _PreviewKind.epFeatured,
    result: (_) => FeaturedEpisodeCard(
      entry: _episodeEntry(
        'Control',
        meta: 'S2 · Ép. 5',
        subtitle: 'The Boys',
        duration: '46 min',
        rating: 8.9,
        hd: true,
        thumbUrl: _posterOppenheimer,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Prochain épisode (héros)',
    className: 'NextEpisodeHeroCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'NextEpisodeCard — grand visuel et chip',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.skip_next_rounded,
    kind: _PreviewKind.epNextHero,
    result: (_) => NextEpisodeHeroCard(
      entry: _episodeEntry(
        'Game of Thrones',
        meta: 'S8 · Ép. 1 · 58 min',
        subtitle: 'Le Dernier de la Garde',
        actionLabel: 'Prochain épisode',
        progress: 0,
        thumbUrl: _posterThrones,
        backdropUrl: _backdropInterstellar,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Dernier épisode ajouté',
    className: 'LatestEpisodeCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Badge Nouveau + bouton Voir la série',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.fiber_new_rounded,
    kind: _PreviewKind.epLatest,
    result: (_) => LatestEpisodeCard(
      entry: _episodeEntry(
        'House of the Dragon',
        meta: 'S1 · Ép. 8 · 1h 12m',
        subtitle: 'The Lord of the Tides',
        badge: 'Nouveau',
        actionLabel: 'Voir la série',
        hd: true,
        thumbUrl: _posterOppenheimer,
        backdropUrl: _backdropOppenheimer,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Sélecteur de saison',
    className: 'SeasonSelectorCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Poster + chips S1-S5 + épisodes',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.tune_rounded,
    kind: _PreviewKind.epSelector,
    result: (_) => SeasonSelectorCard(
      selectedSeason: 1,
      onSeasonSelected: (_) {},
      seasons: [
        _seasonEntry('The Witcher', seasonLabel: 'S1', thumbUrl: _posterInterstellar),
        _seasonEntry('The Witcher', seasonLabel: 'S2', thumbUrl: _posterInterstellar),
        _seasonEntry('The Witcher', seasonLabel: 'S3', thumbUrl: _posterInterstellar),
        _seasonEntry('The Witcher', seasonLabel: 'S4', thumbUrl: _posterInterstellar),
        _seasonEntry('The Witcher', seasonLabel: 'S5', thumbUrl: _posterInterstellar),
      ],
      episodes: [
        _episodeEntry('A Grain of Truth', meta: 'S2 · Ép. 1',
            duration: '48 min', thumbUrl: _posterDune),
        _episodeEntry('Kaer Morhen', meta: 'S2 · Ép. 2',
            duration: '52 min', thumbUrl: _posterThrones),
        _episodeEntry('What’s Lost', meta: 'S2 · Ép. 3',
            duration: '47 min', thumbUrl: _posterArcane),
        _episodeEntry('Redanian Intelligence', meta: 'S2 · Ép. 4',
            duration: '50 min', locked: true, thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Liste compacte de série',
    className: 'SeriesEpisodeListCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'SeriesEpisodeCard (liste compacte)',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.list_alt_rounded,
    kind: _PreviewKind.epSeriesList,
    result: (_) => SeriesEpisodeListCard(
      episodes: [
        _episodeEntry('Wolf', meta: 'S1 · Ép. 1', duration: '49 min',
            watched: true, thumbUrl: _posterDune),
        _episodeEntry('Blood Moon', meta: 'S1 · Ép. 2', duration: '48 min',
            thumbUrl: _posterThrones),
        _episodeEntry('Alpha', meta: 'S1 · Ép. 3', duration: '52 min',
            thumbUrl: _posterArcane),
        _episodeEntry('The Pack', meta: 'S1 · Ép. 4', duration: '46 min',
            locked: true, thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Progression de visionnage',
    className: 'EpisodeProgressCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'WatchProgressCard — épisode en cours',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.access_time_rounded,
    kind: _PreviewKind.epProgress,
    result: (_) => EpisodeProgressCard(
      entry: _episodeEntry(
        'Teen Wolf',
        meta: 'S3 · Ép. 6 — Raw Talent',
        duration: '52 min',
        progress: .72,
        hd: true,
        thumbUrl: _posterArcane,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Média avec barre de progression',
    className: 'MediaProgressCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'ProgressMediaCard — temps restant et HD',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.speed_rounded,
    kind: _PreviewKind.epMediaProgress,
    result: (_) => MediaProgressCard(
      entry: _episodeEntry(
        'The 100',
        meta: 'S5 · Ép. 7 · The Warriors Will',
        duration: '41 min',
        progress: .45,
        hd: true,
        thumbUrl: _posterInterstellar,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Prochain épisode (compact)',
    className: 'UpNextCompactCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'UpNextCard — format paysage compact',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.update_rounded,
    kind: _PreviewKind.epUpNextCompact,
    result: (_) => UpNextCompactCard(
      entry: _episodeEntry(
        'Lucifer',
        meta: 'S6 · Ép. 4',
        subtitle: 'Épisode suivant',
        duration: '44 min',
        thumbUrl: _posterOppenheimer,
        backdropUrl: _backdropOppenheimer,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Épisode avec info saison',
    className: 'SeasonEpisodeCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'EpisodeCard (avec saison) et genres',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.live_tv_outlined,
    kind: _PreviewKind.epSeasonEpisode,
    result: (_) => SeasonEpisodeCard(
      entry: _episodeEntry(
        'The Mandalorian',
        meta: 'S2 · Ép. 8',
        subtitle: 'Chapitre 15',
        duration: '42 min',
        genres: ['Action', 'Aventure'],
        thumbUrl: _posterDune,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Bannière de série',
    className: 'SeriesBannerCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Bannière large avec infos et note',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.image_outlined,
    kind: _PreviewKind.epSeriesBanner,
    result: (_) => SeriesBannerCard(
      season: _seasonEntry(
        'Wednesday',
        stats: 'S1 · 2022 · Mystère · Fantastique',
        description:
            'Une enquête sombre à Nevermore, où Wednesday Addams découvre des secrets et des créatures.',
        rating: 8.5,
        thumbUrl: _backdropArcane,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Carrousel d\'épisodes',
    className: 'EpisodeCarousel',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Mini-cartes, sélection et flèches',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.view_carousel_outlined,
    kind: _PreviewKind.epCarousel,
    result: (_) => EpisodeCarousel(
      onPrevious: () {},
      onNext: () {},
      episodes: [
        _episodeEntry('Pilot', number: 1, thumbUrl: _posterDune),
        _episodeEntry('The Weir', number: 2, thumbUrl: _posterThrones),
        _episodeEntry('Long, Long Time', number: 3, current: true,
            thumbUrl: _posterOppenheimer),
        _episodeEntry('Please Hold', number: 4, thumbUrl: _posterArcane),
        _episodeEntry('Endure and Survive', number: 5,
            thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Saison (style horizontal)',
    className: 'SeasonBannerCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'SeasonCard horizontale avec note',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.play_circle_outline,
    kind: _PreviewKind.epSeasonBanner,
    result: (_) => SeasonBannerCard(
      season: _seasonEntry(
        'Breaking Bad',
        seasonLabel: 'Saison 5',
        stats: '16 épisodes · 2013',
        description: 'La fin épique pour Walter White et Jesse Pinkman.',
        rating: 9.5,
        thumbUrl: _backdropDune,
      ),
    ),
  ),
  _ComponentSpec(
    title: 'Liste avec vignettes',
    className: 'EpisodeListCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Épisodes avec vignettes 16:9',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.list_rounded,
    kind: _PreviewKind.epEpisodeList,
    result: (_) => EpisodeListCard(
      episodes: [
        _episodeEntry('The Pilot', meta: 'S1 · Ép. 1', duration: '58 min',
            watched: true, thumbUrl: _posterDune),
        _episodeEntry('The Cat’s in the Bag', meta: 'S1 · Ép. 2',
            duration: '52 min', thumbUrl: _posterThrones),
        _episodeEntry('Nothin’ But T…', meta: 'S1 · Ép. 3',
            duration: '52 min', thumbUrl: _posterArcane),
        _episodeEntry('Better Call Saul', meta: 'S1 · Ép. 4',
            duration: '47 min', locked: true, thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Grille de saisons',
    className: 'SeriesGridCard',
    path: 'lib/modules/media/episode_cards.dart',
    usage: 'Grille d\'épisodes / saisons',
    section: 'ÉPISODES & SAISONS',
    icon: Icons.grid_view_rounded,
    kind: _PreviewKind.epSeriesGrid,
    result: (_) => SeriesGridCard(
      seasons: [
        _seasonEntry('Saison 1', stats: '10 épisodes', thumbUrl: _backdropDune),
        _seasonEntry('Saison 2', stats: '10 épisodes', thumbUrl: _backdropInterstellar),
        _seasonEntry('Saison 3', stats: '10 épisodes', thumbUrl: _backdropOppenheimer),
        _seasonEntry('Saison 4', stats: '10 épisodes', thumbUrl: _backdropArcane),
        _seasonEntry('Saison 5', stats: '16 épisodes', thumbUrl: _backdropDune),
        _seasonEntry('Saison 6', stats: '16 épisodes', thumbUrl: _backdropInterstellar),
      ],
    ),
  ),
  // ── CLASSEMENTS & TOP 10 ──
  _ComponentSpec(
    title: 'Top 10 Films du moment',
    className: 'TopMoviesCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Films les plus populaires',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.whatshot_rounded,
    kind: _PreviewKind.rankMovies,
    result: (_) => TopMoviesCard(
      onSeeAll: () {},
      items: [
        _rankEntry('Dune: Part Two', meta: '2024', rating: 8.8, rank: 1,
            thumbUrl: _posterDune),
        _rankEntry('The Batman', meta: '2022', rating: 8.2, rank: 2,
            thumbUrl: _posterThrones),
        _rankEntry('Oppenheimer', meta: '2023', rating: 8.7, rank: 3,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Interstellar', meta: '2014', rating: 8.6, rank: 4,
            thumbUrl: _posterInterstellar),
        _rankEntry('Spider-Man: No Way Home', meta: '2021', rating: 8.3,
            rank: 5, thumbUrl: _posterArcane),
        _rankEntry('The Dark Knight', meta: '2008', rating: 9.0, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('Inception', meta: '2010', rating: 8.8, rank: 7,
            thumbUrl: _posterInterstellar),
        _rankEntry('Fight Club', meta: '1999', rating: 8.8, rank: 8,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Forrest Gump', meta: '1994', rating: 8.8, rank: 9,
            thumbUrl: _posterArcane),
        _rankEntry('The Shawshank Redemption', meta: '1994', rating: 9.3,
            rank: 10, thumbUrl: _posterThrones),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 Séries du moment',
    className: 'TopSeriesCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Séries les plus regardées',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.tv_rounded,
    kind: _PreviewKind.rankSeries,
    result: (_) => TopSeriesCard(
      onSeeAll: () {},
      items: [
        _rankEntry('The Last of Us', meta: 'S1 · 2023', rating: 9.0,
            rank: 1, thumbUrl: _posterThrones),
        _rankEntry('Breaking Bad', meta: 'S1-S5 · 2008', rating: 9.5,
            rank: 2, thumbUrl: _posterDune),
        _rankEntry('Game of Thrones', meta: 'S1-S8 · 2011', rating: 9.2,
            rank: 3, thumbUrl: _posterInterstellar),
        _rankEntry('Stranger Things', meta: 'S1-S4 · 2016', rating: 8.7,
            rank: 4, thumbUrl: _posterArcane),
        _rankEntry('Wednesday', meta: 'S1 · 2022', rating: 8.1, rank: 5,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Loki', meta: 'S1-S2 · 2021', rating: 8.2, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('The Walking Dead', meta: 'S1-S11 · 2010', rating: 8.1,
            rank: 7, thumbUrl: _posterThrones),
        _rankEntry('Peaky Blinders', meta: 'S1-S6 · 2013', rating: 8.8,
            rank: 8, thumbUrl: _posterArcane),
        _rankEntry('Lucifer', meta: 'S1-S6 · 2016', rating: 8.1, rank: 9,
            thumbUrl: _posterInterstellar),
        _rankEntry('Dark', meta: 'S1-S3 · 2017', rating: 8.8, rank: 10,
            thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 Animés',
    className: 'TopAnimeCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Animés les plus populaires',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.star_outline_rounded,
    kind: _PreviewKind.rankAnime,
    result: (_) => TopAnimeCard(
      onSeeAll: () {},
      items: [
        _rankEntry('Attack on Titan', meta: 'S1-S4 · 2013', rating: 9.1,
            rank: 1, thumbUrl: _posterDune),
        _rankEntry('Jujutsu Kaisen', meta: 'S1-S2 · 2020', rating: 8.8,
            rank: 2, thumbUrl: _posterThrones),
        _rankEntry('One Piece', meta: 'S1+ · 1999', rating: 9.0, rank: 3,
            thumbUrl: _posterInterstellar),
        _rankEntry('Demon Slayer', meta: 'S1-S4 · 2019', rating: 8.7,
            rank: 4, thumbUrl: _posterArcane),
        _rankEntry('Death Note', meta: 'S1 · 2006', rating: 8.9, rank: 5,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Naruto', meta: 'S1-S9 · 2002', rating: 9.3, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('Fullmetal Alchemist', meta: 'S1 · 2009', rating: 9.1,
            rank: 7, thumbUrl: _posterThrones),
        _rankEntry('Tokyo Ghoul', meta: 'S1-S2 · 2019', rating: 8.8,
            rank: 8, thumbUrl: _posterInterstellar),
        _rankEntry('Vinland Saga', meta: 'S1-S2 · 2019', rating: 8.8,
            rank: 9, thumbUrl: _posterArcane),
        _rankEntry('Hunter x Hunter', meta: 'S1-S6 · 2011', rating: 9.0,
            rank: 10, thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 par genre',
    className: 'TopByGenreCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Tuiles de genres 1-10',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.category_rounded,
    kind: _PreviewKind.rankByGenre,
    result: (_) => TopByGenreCard(
      onSeeAll: () {},
      items: [
        _rankEntry('Action', meta: '1-10', rank: 1,
            thumbUrl: _backdropDune, isLabelTile: true),
        _rankEntry('Aventure', meta: '1-10', rank: 2,
            thumbUrl: _backdropInterstellar, isLabelTile: true),
        _rankEntry('Comédie', meta: '1-10', rank: 3,
            thumbUrl: _backdropOppenheimer, isLabelTile: true),
        _rankEntry('Drame', meta: '1-10', rank: 4,
            thumbUrl: _backdropArcane, isLabelTile: true),
        _rankEntry('Fantastique', meta: '1-10', rank: 5,
            thumbUrl: _backdropDune, isLabelTile: true),
        _rankEntry('Horreur', meta: '1-10', rank: 6,
            thumbUrl: _backdropInterstellar, isLabelTile: true),
        _rankEntry('Romance', meta: '1-10', rank: 7,
            thumbUrl: _backdropOppenheimer, isLabelTile: true),
        _rankEntry('Science-Fiction', meta: '1-10', rank: 8,
            thumbUrl: _backdropArcane, isLabelTile: true),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 par pays',
    className: 'TopByCountryCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Tuiles de pays 1-10',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.public,
    kind: _PreviewKind.rankByCountry,
    result: (_) => TopByCountryCard(
      onSeeAll: () {},
      items: [
        _rankEntry('USA', meta: '1-10', rank: 1,
            thumbUrl: _backdropDune, isLabelTile: true),
        _rankEntry('UK', meta: '1-10', rank: 2,
            thumbUrl: _backdropInterstellar, isLabelTile: true),
        _rankEntry('France', meta: '1-10', rank: 3,
            thumbUrl: _backdropOppenheimer, isLabelTile: true),
        _rankEntry('Japon', meta: '1-10', rank: 4,
            thumbUrl: _backdropArcane, isLabelTile: true),
        _rankEntry('Corée du Sud', meta: '1-10', rank: 5,
            thumbUrl: _backdropDune, isLabelTile: true),
        _rankEntry('Allemagne', meta: '1-10', rank: 6,
            thumbUrl: _backdropInterstellar, isLabelTile: true),
        _rankEntry('Canada', meta: '1-10', rank: 7,
            thumbUrl: _backdropOppenheimer, isLabelTile: true),
        _rankEntry('Espagne', meta: '1-10', rank: 8,
            thumbUrl: _backdropArcane, isLabelTile: true),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Classement global',
    className: 'GlobalRankingCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Top 20 tous contenus confondus',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.emoji_events_outlined,
    kind: _PreviewKind.rankGlobal,
    result: (_) => GlobalRankingCard(
      onSeeAll: () {},
      items: [
        _rankEntry('The Last of Us', rating: 9.0, rank: 1,
            thumbUrl: _posterThrones),
        _rankEntry('Dune: Part Two', rating: 8.8, rank: 2,
            thumbUrl: _posterDune),
        _rankEntry('Breaking Bad', rating: 9.5, rank: 3,
            thumbUrl: _posterArcane),
        _rankEntry('Game of Thrones', rating: 9.2, rank: 4,
            thumbUrl: _posterInterstellar),
        _rankEntry('Avengers Endgame', rating: 8.4, rank: 5,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Stranger Things', rating: 8.7, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('Interstellar', rating: 8.6, rank: 7,
            thumbUrl: _posterThrones),
        _rankEntry('Spider-Man: NWH', rating: 8.3, rank: 8,
            thumbUrl: _posterArcane),
        _rankEntry('Inception', rating: 8.8, rank: 9,
            thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 des plus notés',
    className: 'TopRatedRankingCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Notes des utilisateurs',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.star_rounded,
    kind: _PreviewKind.rankTopRated,
    result: (_) => TopRatedRankingCard(
      onSeeAll: () {},
      items: [
        _rankEntry('Breaking Bad', rating: 9.5, rank: 1,
            thumbUrl: _posterDune),
        _rankEntry('Planet Earth II', rating: 9.4, rank: 2,
            thumbUrl: _posterThrones),
        _rankEntry('The Shawshank Redemption', rating: 9.3, rank: 3,
            thumbUrl: _posterOppenheimer),
        _rankEntry('The Godfather', rating: 9.2, rank: 4,
            thumbUrl: _posterArcane),
        _rankEntry('Band of Brothers', rating: 9.1, rank: 5,
            thumbUrl: _posterInterstellar),
        _rankEntry('Pulp Fiction', rating: 8.9, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('The Dark Knight', rating: 9.0, rank: 7,
            thumbUrl: _posterThrones),
        _rankEntry('Forrest Gump', rating: 8.8, rank: 8,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Fight Club', rating: 8.8, rank: 9,
            thumbUrl: _posterArcane),
        _rankEntry('Spirited Away', rating: 8.6, rank: 10,
            thumbUrl: _posterInterstellar),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 tendances',
    className: 'TrendingRankingCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Ce qui fait le plus parler',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.trending_up_rounded,
    kind: _PreviewKind.rankTrending,
    result: (_) => TrendingRankingCard(
      onSeeAll: () {},
      items: [
        _rankEntry('The Last of Us', rating: 9.0, rank: 1,
            thumbUrl: _posterThrones),
        _rankEntry('The Mandalorian', rating: 8.7, rank: 2,
            thumbUrl: _posterDune),
        _rankEntry('Wednesday', rating: 8.1, rank: 3,
            thumbUrl: _posterArcane),
        _rankEntry('Demon Slayer', rating: 8.7, rank: 4,
            thumbUrl: _posterOppenheimer),
        _rankEntry('Jujutsu Kaisen', rating: 8.8, rank: 5,
            thumbUrl: _posterInterstellar),
        _rankEntry('One Piece', rating: 9.0, rank: 6,
            thumbUrl: _posterDune),
        _rankEntry('Loki', rating: 8.2, rank: 7, thumbUrl: _posterThrones),
        _rankEntry('House of the Dragon', rating: 8.5, rank: 8,
            thumbUrl: _posterArcane),
        _rankEntry('Arcane', rating: 9.3, rank: 9,
            thumbUrl: _posterInterstellar),
        _rankEntry('Attack on Titan', rating: 9.1, rank: 10,
            thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 par décennie',
    className: 'TopByDecadeCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Tuiles de décennies',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.history_rounded,
    kind: _PreviewKind.rankByDecade,
    result: (_) => TopByDecadeCard(
      onSeeAll: () {},
      items: [
        _rankEntry('80’s', meta: '1-10', rank: 1,
            thumbUrl: _backdropDune, isLabelTile: true),
        _rankEntry('90’s', meta: '1-10', rank: 2,
            thumbUrl: _backdropInterstellar, isLabelTile: true),
        _rankEntry('2000’s', meta: '1-10', rank: 3,
            thumbUrl: _backdropOppenheimer, isLabelTile: true),
        _rankEntry('2010’s', meta: '1-10', rank: 4,
            thumbUrl: _backdropArcane, isLabelTile: true),
        _rankEntry('2020’s', meta: '1-10', rank: 5,
            thumbUrl: _backdropDune, isLabelTile: true),
      ],
    ),
  ),
  _ComponentSpec(
    title: 'Top 10 à voir absolument',
    className: 'MustWatchCard',
    path: 'lib/modules/media/ranking_cards.dart',
    usage: 'Sélection des incontournables',
    section: 'CLASSEMENTS & TOP 10',
    icon: Icons.favorite_rounded,
    kind: _PreviewKind.rankMustWatch,
    result: (_) => MustWatchCard(
      onSeeAll: () {},
      items: [
        _rankEntry('The Godfather', rating: 9.2, rank: 1,
            thumbUrl: _posterThrones),
        _rankEntry('The Dark Knight', rating: 9.0, rank: 2,
            thumbUrl: _posterDune),
        _rankEntry('Pulp Fiction', rating: 8.9, rank: 3,
            thumbUrl: _posterArcane),
        _rankEntry('Dune', rating: 8.8, rank: 4, thumbUrl: _posterDune),
        _rankEntry('Inception', rating: 8.8, rank: 5,
            thumbUrl: _posterInterstellar),
        _rankEntry('Forrest Gump', rating: 8.8, rank: 6,
            thumbUrl: _posterOppenheimer),
        _rankEntry('The Matrix', rating: 8.7, rank: 7,
            thumbUrl: _posterThrones),
        _rankEntry('Interstellar', rating: 8.6, rank: 8,
            thumbUrl: _posterInterstellar),
        _rankEntry('Fight Club', rating: 8.6, rank: 9,
            thumbUrl: _posterArcane),
        _rankEntry('The Prestige', rating: 8.5, rank: 10,
            thumbUrl: _posterOppenheimer),
      ],
    ),
  ),
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
    title: 'Classée découverte',
    className: 'RankedDiscoveryCard',
    path: 'lib/modules/home/widgets/discovery_card.dart',
    usage: 'Classements',
    icon: Icons.format_list_numbered_rounded,
    kind: _PreviewKind.ranked,
    result: (_) =>
        RankedDiscoveryCard(media: _animeItems[2], rank: 2, onTap: () {}),
  ),
  _ComponentSpec(
    title: 'Paysage découverte',
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
      child: ScrollingMovies(
        title: 'Popular',
        items: _tmdbItems,
        discoverPath: '/movie/popular',
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
      child: RankedMovies(
        title: 'Top 10 cette semaine',
        items: _tmdbItems,
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
      child: ScrollingLandscapeMovies(
        title: 'Now playing',
        items: _tmdbItems,
        discoverPath: '/movie/now_playing',
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
      child: FeaturedMovieRail(
        title: 'À découvrir',
        items: _tmdbItems,
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Rail des services',
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
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Hero plein écran',
    className: 'TmdbHeroCarousel',
    path: 'lib/modules/home/widgets/tmdb_cards.dart',
    usage: 'Carrousel auto du hub films/séries',
    icon: Icons.slideshow_rounded,
    kind: _PreviewKind.homeHero,
    result: (_) => SizedBox(
      width: 340,
      child: TmdbHeroCarousel(
        items: _tmdbItems.take(4).toList(growable: false),
        onTap: (_) {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'FILMS & SÉRIES · SECTIONS',
    title: 'Vedette + rail',
    className: 'TmdbFeaturedStack',
    path: 'lib/modules/home/widgets/tmdb_cards.dart',
    usage: 'Mise en avant du hub',
    icon: Icons.auto_awesome_rounded,
    kind: _PreviewKind.featuredStack,
    result: (context) => TmdbFeaturedStack(
      title: 'À voir cette semaine',
      icon: Icons.auto_awesome_rounded,
      color: Theme.of(context).colorScheme.primary,
      items: _tmdbItems,
      onTap: (_) {},
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
      height: 190,
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
      height: 130,
      child: MangaImageCardListTileWidget(
        source: _gallerySource,
        itemType: ItemType.manga,
        getMangaDetail: _extensionItems[1],
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Vedette manga',
    className: 'MangaFeaturedCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Rail "À la une" du home manga',
    icon: Icons.local_fire_department_rounded,
    kind: _PreviewKind.mangaHome,
    result: (_) => SizedBox(
      width: 168,
      child: MangaFeaturedCard(
        item: ContentItem.fromManga(_extensionItems[0]),
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Carte chapitre manga',
    className: 'MangaChapterCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Rails "Nouveaux chapitres"',
    icon: Icons.book_outlined,
    kind: _PreviewKind.mangaHome,
    result: (_) => SizedBox(
      width: 112,
      child: MangaChapterCard(
        item: ContentItem.fromManga(_extensionItems[1]),
        badge: '144',
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Reprise de lecture',
    className: 'MangaResumeCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Section "Reprendre la lecture"',
    icon: Icons.play_circle_outline_rounded,
    kind: _PreviewKind.mangaList,
    result: (_) => SizedBox(
      width: 330,
      child: MangaResumeCard(
        item: ContentItem.fromManga(_extensionItems[2]),
        subtitle: 'Chapitre 148 · il y a 2 h',
        progress: 0.42,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Spotlight manga',
    className: 'MangaSpotlightCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Hero du home manga',
    icon: Icons.auto_awesome_rounded,
    kind: _PreviewKind.mangaSpotlight,
    result: (_) => SizedBox(
      width: 320,
      child: MangaSpotlightCard(
        item: ContentItem.fromManga(_extensionItems[3]),
        height: 180,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Genre manga',
    className: 'MangaGenreCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Rail "Genres" du home manga',
    icon: Icons.category_outlined,
    kind: _PreviewKind.mangaGenre,
    result: (_) => SizedBox(
      width: 118,
      height: 84,
      child: MangaGenreCard(
        label: 'Shonen',
        imageUrl: _extensionItems[0].imageUrl,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Ligne mise à jour',
    className: 'MangaUpdateRow',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Liste "Dernières mises à jour"',
    icon: Icons.update_rounded,
    kind: _PreviewKind.searchList,
    result: (_) => SizedBox(
      width: 330,
      child: MangaUpdateRow(
        item: ContentItem.fromManga(_extensionItems[0]),
        subtitle: 'Chapitre 147',
        time: '2 h',
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Bannière manga',
    className: 'MangaBannerCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Section pleine largeur du home manga',
    icon: Icons.panorama_outlined,
    kind: _PreviewKind.banner,
    result: (_) => SizedBox(
      width: 320,
      child: MangaBannerCard(
        item: ContentItem.fromManga(_extensionItems[2]),
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Top 3 manga',
    className: 'MangaTop3Card',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Rail "Top 3" triptyque',
    icon: Icons.emoji_events_outlined,
    kind: _PreviewKind.top3,
    result: (_) => SizedBox(
      width: 132,
      child: MangaTop3Card(
        items: _extensionItems
            .take(3)
            .map(ContentItem.fromManga)
            .toList(growable: false),
        rank: 1,
        onTap: (_) {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Mise à jour chapitres',
    className: 'MangaLatestUpdateCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Feed "Latest Chapter Updates"',
    icon: Icons.schedule_rounded,
    kind: _PreviewKind.mangaUpdateFeed,
    result: (_) => SizedBox(
      width: 340,
      child: MangaLatestUpdateCard(
        item: ContentItem.fromManga(_extensionItems[0]),
        time: '10m',
        chapters: const [
          'Ch. 2 - The Border Villa…',
          'Vol. 1 Ch. 1 - The Border…',
        ],
        onChapterTap: (_) {},
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Top Ranking manga',
    className: 'MangaRankingCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Classement Daily / Weekly / Monthly',
    icon: Icons.emoji_events_rounded,
    kind: _PreviewKind.mangaRanking,
    result: (_) => SizedBox(
      width: 340,
      child: MangaRankingCard(
        items: _extensionItems
            .map(ContentItem.fromManga)
            .toList(growable: false),
        onOpen: (_) {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Vote communautaire',
    className: 'MangaVoteCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Carte vote type "Goonable tiers"',
    icon: Icons.how_to_vote_outlined,
    kind: _PreviewKind.mangaVote,
    result: (_) => SizedBox(
      width: 340,
      child: MangaVoteCard(
        title: 'Goonable tiers',
        imageUrl: _extensionItems[1].imageUrl,
        status: 'Voting closed',
        entries: 9,
        posts: 1,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Collection communautaire',
    className: 'MangaCollectionShowcaseCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Collage + titre + stats + auteur',
    icon: Icons.collections_bookmark_outlined,
    kind: _PreviewKind.mangaCollection,
    result: (_) => SizedBox(
      width: 340,
      child: MangaCollectionShowcaseCard(
        title: "Romance I'll never get to experience",
        covers: _extensionItems
            .map((e) => e.imageUrl)
            .whereType<String>()
            .toList(growable: false),
        views: '104377',
        likes: '824',
        reads: '47',
        author: 'ShiroX',
        authorAvatar: _extensionItems[1].imageUrl,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Liste tendance',
    className: 'MangaTrendingListCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Badge #N · TRENDING + rail de vote',
    icon: Icons.trending_up_rounded,
    kind: _PreviewKind.mangaTrending,
    result: (_) => SizedBox(
      width: 340,
      child: MangaTrendingListCard(
        rank: 1,
        title: 'Favorites',
        author: 'hideki1974',
        authorAvatar: _extensionItems[3].imageUrl,
        covers: _extensionItems
            .map((e) => e.imageUrl)
            .whereType<String>()
            .toList(growable: false),
        titleCount: '28 titles',
        votes: 1,
        onTap: () {},
      ),
    ),
  ),
  _ComponentSpec(
    section: 'MANGA & LECTURE',
    title: 'Groupe de scan',
    className: 'MangaScanGroupCard',
    path: 'lib/modules/manga/home/widgets/manga_home_cards.dart',
    usage: 'Classement groupes · followers / titles / staff',
    icon: Icons.groups_outlined,
    kind: _PreviewKind.mangaScanGroup,
    result: (_) => SizedBox(
      width: 340,
      child: MangaScanGroupCard(
        rank: 1,
        name: 'No-group',
        avatarText: 'N',
        covers: _extensionItems
            .map((e) => e.imageUrl)
            .whereType<String>()
            .toList(growable: false),
        likes: 3,
        followers: '3',
        titles: '8.1k',
        staff: '0',
        lastRelease: '2 days ago',
        onTap: () {},
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


/// Données d'aperçu partagées par les cartes streaming de la galerie.
StreamingCardData _streamCardData(
  TmdbMedia item, {
  String? seriesMeta,
  String? extraMeta,
  String? remainingLabel,
  String? badge,
  double? progress,
}) {
  return StreamingCardData(
    item: ContentItem.fromTmdb(item),
    seriesMeta: seriesMeta,
    extraMeta: extraMeta,
    remainingLabel: remainingLabel,
    badge: badge,
    progress: progress,
    onPlay: () {},
    onAddToList: () {},
    onMore: () {},
    onTap: () {},
  );
}

/// Entrée d'épisode / de reprise pour les aperçus streaming.
StreamingEpisode _streamEpisode(
  TmdbMedia item, {
  String? title,
  String? meta,
  bool isCurrent = false,
  bool isLocked = false,
}) {
  return StreamingEpisode(
    title: title ?? item.displayTitle,
    meta: meta,
    thumbUrl: item.bestCover,
    isCurrent: isCurrent,
    isLocked: isLocked,
    onTap: () {},
  );
}

// ─── Données d'aperçu des cartes collections / franchises ───

const _posterDune =
    'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg';
const _posterInterstellar =
    'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg';
const _posterOppenheimer =
    'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg';
const _posterThrones =
    'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg';
const _posterArcane =
    'https://image.tmdb.org/t/p/w500/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg';
const _backdropDune =
    'https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg';
const _backdropInterstellar =
    'https://image.tmdb.org/t/p/w1280/pbrkL804c8yAv3zBZR4QPEafpAR.jpg';
const _backdropOppenheimer =
    'https://image.tmdb.org/t/p/w1280/rLb2cwF3Pazuxaj0sRXQ037tGI1.jpg';
const _backdropArcane =
    'https://image.tmdb.org/t/p/w1280/rkB4LyZHo1NHXFEDHl8M3g1Q3Q.jpg';

/// [ContentItem] de démonstration pour les cartes collections.
ContentItem _collItem(
  String title, {
  String? poster,
  String? backdrop,
}) {
  return ContentItem(
    key: 'coll-$title',
    title: title,
    posterUrl: poster,
    backdropUrl: backdrop,
  );
}

/// Données d'aperçu partagées par les cartes collections de la galerie.
CollectionCardData _collectionData(
  ContentItem item, {
  String? stats,
  String? subtitle,
  String? description,
  String? badge,
  String? actionLabel,
}) {
  return CollectionCardData(
    item: item,
    stats: stats,
    subtitle: subtitle,
    description: description,
    badge: badge,
    actionLabel: actionLabel,
    onExplore: () {},
    onTap: () {},
  );
}

/// Entrée d'aperçu : poster de rangée, tuile latérale, univers de carrousel.
CollectionEntry _collectionEntry(
  String title, {
  String? meta,
  String? thumbUrl,
  double? rating,
  String? viewsLabel,
  int? rank,
}) {
  return CollectionEntry(
    title: title,
    meta: meta,
    thumbUrl: thumbUrl,
    rating: rating,
    viewsLabel: viewsLabel,
    rank: rank,
    onTap: () {},
  );
}

// ─── Données d'aperçu des cartes épisodes / classements ───

/// Entrée d'épisode pour les aperçus du catalogue Épisodes & Saisons.
EpisodeEntry _episodeEntry(
  String title, {
  String? meta,
  String? subtitle,
  String? duration,
  String? description,
  String? thumbUrl,
  String? backdropUrl,
  double? rating,
  double? progress,
  List<String> genres = const [],
  String? actionLabel,
  String? badge,
  int? number,
  bool watched = false,
  bool locked = false,
  bool current = false,
  bool hd = false,
}) {
  return EpisodeEntry(
    title: title,
    meta: meta,
    subtitle: subtitle,
    duration: duration,
    description: description,
    thumbUrl: thumbUrl,
    backdropUrl: backdropUrl,
    rating: rating,
    progress: progress,
    genres: genres,
    actionLabel: actionLabel,
    badge: badge,
    number: number,
    watched: watched,
    locked: locked,
    current: current,
    hd: hd,
    onTap: () {},
    onPlay: () {},
  );
}

/// Entrée de saison pour les aperçus du catalogue Épisodes & Saisons.
SeasonEntry _seasonEntry(
  String title, {
  String? seasonLabel,
  String? stats,
  String? description,
  String? thumbUrl,
  double? rating,
  bool selected = false,
}) {
  return SeasonEntry(
    title: title,
    seasonLabel: seasonLabel,
    stats: stats,
    description: description,
    thumbUrl: thumbUrl,
    rating: rating,
    selected: selected,
    onTap: () {},
  );
}

/// Entrée de classement pour les aperçus du catalogue Top 10.
RankingEntry _rankEntry(
  String title, {
  String? meta,
  double? rating,
  required int rank,
  String? thumbUrl,
  bool isLabelTile = false,
}) {
  return RankingEntry(
    title: title,
    meta: meta,
    rating: rating,
    rank: rank,
    thumbUrl: thumbUrl,
    isLabelTile: isLabelTile,
    onTap: () {},
  );
}

/// Données d'aperçu partagées par les cartes riches de la galerie.
RichMediaCardData _richCardData(TmdbMedia item) {
  return RichMediaCardData(
    item: ContentItem.fromTmdb(item),
    meta: (item.mediaType == 'tv'
            ? item.firstAirDate
            : item.releaseDate)
        ?.split('-')
        .first,
    genres: item.mediaType == 'tv' ? 'Action · Drame' : 'Science-fiction · Aventure',
    runtimeMinutes: item.mediaType == 'tv' ? 52 : 166,
    seasonNumber: item.mediaType == 'tv' ? 1 : null,
    onPlay: () {},
    onAddToList: () {},
    onMore: () {},
    onShare: () {},
  );
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
