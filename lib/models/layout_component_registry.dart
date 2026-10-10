import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/gallery_component_palette.dart';

/// Contexts in which a layout component can be rendered.
enum LayoutComponentContext {
  home,
  homeMangaCard,
  homeEpisodeCard,
  chapter,
  browse,
  search,
  // Intentionally empty until a detail-page adapter can render registered
  // components from the persisted Manga/Chapter models and current layout data.
  detail,
  // Separate from the video player context; the manga reader still renders
  // pages through its own gesture-, archive-, and mode-aware pipeline.
  reader,
  player,
}

/// Renderer families implemented by the extension home screen.
enum LayoutComponentRenderer {
  spotlight,
  banner,
  ranked,
  landscape,
  grid,
  collections,
  posterRail,
  mangaFeaturedCard,
  mangaChapterCard,
  homeEpisodeCard,
  chapterCard,
}

/// Loading placeholders used by the extension home renderer.
enum LayoutComponentLoadingPreview {
  hero,
  ranked,
  landscape,
  grid,
  categoryPills,
  collections,
  row,
}

/// The JSON-facing definition of a component supported by a layout context.
class LayoutComponentDefinition {
  const LayoutComponentDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.description,
    required this.renderer,
    required this.loadingPreview,
    required this.legacyLayout,
    this.aliases = const [],
    this.supportedContexts = const {LayoutComponentContext.home},
    this.requiredProperties = const {},
    this.selectable = true,
    this.galleryFamily,
  });

  /// Set when the definition is a gallery component rendered by
  /// `GalleryComponentRenderer`. `null` for the hand-written legacy
  /// definitions, which use the extension rail renderers directly.
  final GalleryComponentFamily? galleryFamily;

  /// Stable identifier written to layout JSON.
  final String id;
  final String label;
  final String category;
  final String description;
  final LayoutComponentRenderer renderer;
  final LayoutComponentLoadingPreview loadingPreview;
  final String legacyLayout;
  final List<String> aliases;
  final Set<LayoutComponentContext> supportedContexts;
  final Set<String> requiredProperties;

  /// Compatibility-only entries remain valid in existing JSON, but are not
  /// suggested as new choices in the visual picker.
  final bool selectable;

  Set<String> get configurableProperties {
    const shared = {
      'title',
      'icon',
      'accent',
      'seeAll',
      'paginated',
      'requiresAuth',
      'monthSelector',
    };
    // Gallery-backed definitions expose the palette parameters for their
    // family (layout, columns, rows, width, height, spacing…) so an editor can
    // configure every card without hard-coding the list per component.
    if (galleryFamily != null) {
      return {
        ...shared,
        for (final parameter in GalleryComponentPalette.forFamily(galleryFamily!))
          parameter.key,
      };
    }
    if (renderer != LayoutComponentRenderer.grid) return shared;
    return {
      ...shared,
      'columns',
      'rows',
      'cardStyle',
      'gridOrder',
      'scrollDirection',
    };
  }
}

/// Single source of truth for JSON component IDs, aliases, contexts and
/// renderer families. Keep the picker and runtime renderer aligned here.
class LayoutComponentRegistry {
  LayoutComponentRegistry._();

  static const definitions = <LayoutComponentDefinition>[
    LayoutComponentDefinition(
      id: 'spotlight',
      aliases: ['carousel'],
      label: 'Spotlight',
      category: 'HÉROS',
      description: 'Carrousel principal en grand format.',
      renderer: LayoutComponentRenderer.spotlight,
      loadingPreview: LayoutComponentLoadingPreview.hero,
      legacyLayout: 'spotlight',
    ),
    LayoutComponentDefinition(
      id: 'banner',
      label: 'Bannière',
      category: 'HÉROS',
      description: 'Rail de bannières éditoriales.',
      renderer: LayoutComponentRenderer.banner,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'banner',
    ),
    LayoutComponentDefinition(
      id: 'hero',
      label: 'Hero bannière',
      category: 'HÉROS',
      description: 'Alias historique du composant banner.',
      renderer: LayoutComponentRenderer.banner,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'banner',
    ),
    LayoutComponentDefinition(
      id: 'ranked',
      label: 'Classement',
      category: 'CLASSEMENTS',
      description: 'Rail de contenus classés.',
      renderer: LayoutComponentRenderer.ranked,
      loadingPreview: LayoutComponentLoadingPreview.ranked,
      legacyLayout: 'ranked',
    ),
    LayoutComponentDefinition(
      id: 'newHot',
      aliases: ['new_hot'],
      label: 'Nouveautés tendance',
      category: 'CLASSEMENTS',
      description: 'Rail classé de nouveautés populaires.',
      renderer: LayoutComponentRenderer.ranked,
      loadingPreview: LayoutComponentLoadingPreview.ranked,
      legacyLayout: 'new_hot',
    ),
    LayoutComponentDefinition(
      id: 'rankedWide',
      label: 'Classement horizontal',
      category: 'CLASSEMENTS',
      description: 'Classement avec cartes horizontales.',
      renderer: LayoutComponentRenderer.ranked,
      loadingPreview: LayoutComponentLoadingPreview.ranked,
      legacyLayout: 'rankedWide',
    ),
    LayoutComponentDefinition(
      id: 'showcase',
      label: 'Sélection showcase',
      category: 'RAILS',
      description: 'Rail panoramique de contenus mis en avant.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'landscapeStacked',
    ),
    LayoutComponentDefinition(
      id: 'creatorRow',
      label: 'Créateurs',
      category: 'RAILS',
      description: 'Rail de créateurs.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'ranked',
    ),
    LayoutComponentDefinition(
      id: 'landscapeStacked',
      label: 'Paysage empilé',
      category: 'RAILS',
      description: 'Rail de cartes panoramiques empilées.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'landscapeStacked',
    ),
    LayoutComponentDefinition(
      id: 'backdropWide',
      label: 'Fond large',
      category: 'RAILS',
      description: 'Rail panoramique avec fonds larges.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'backdropWide',
    ),
    LayoutComponentDefinition(
      id: 'studioExplorer',
      label: 'Studios',
      category: 'DÉCOUVERTE',
      description: 'Rail de découverte des studios.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'studioExplorer',
    ),
    LayoutComponentDefinition(
      id: 'universeExplorer',
      label: 'Exploration des univers',
      category: 'DÉCOUVERTE',
      description: 'Rail de découverte d’univers.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'universeExplorer',
    ),
    LayoutComponentDefinition(
      id: 'collectionTimeline',
      label: 'Chronologie de collection',
      category: 'COLLECTIONS',
      description: 'Collection présentée dans l’ordre chronologique.',
      renderer: LayoutComponentRenderer.landscape,
      loadingPreview: LayoutComponentLoadingPreview.landscape,
      legacyLayout: 'collectionTimeline',
    ),
    LayoutComponentDefinition(
      id: 'grid',
      label: 'Grille',
      category: 'GRILLES',
      description: 'Grille de contenus avec colonnes et lignes configurables.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'catalogue',
    ),
    LayoutComponentDefinition(
      id: 'catalogue',
      label: 'Catalogue',
      category: 'GRILLES',
      description: 'Grille de catalogue.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'catalogue',
    ),
    LayoutComponentDefinition(
      id: 'discoverGrid',
      label: 'Grille découverte',
      category: 'DÉCOUVERTE',
      description: 'Grille de découverte.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'discoverGrid',
    ),
    LayoutComponentDefinition(
      id: 'category',
      label: 'Catégories',
      category: 'CATÉGORIES',
      description: 'Grille de contenus par catégorie.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'category',
    ),
    LayoutComponentDefinition(
      id: 'categoryPills',
      label: 'Pastilles de catégories',
      category: 'CATÉGORIES',
      description: 'Présentation compacte des catégories.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.categoryPills,
      legacyLayout: 'category',
    ),
    LayoutComponentDefinition(
      id: 'doubleFeature',
      label: 'Double vedette',
      category: 'GRILLES',
      description: 'Grille à deux contenus mis en avant.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'doubleFeature',
    ),
    LayoutComponentDefinition(
      id: 'editorialSplit',
      label: 'Éditorial',
      category: 'GRILLES',
      description: 'Grille éditoriale.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'editorialSplit',
    ),
    LayoutComponentDefinition(
      id: 'masonry',
      label: 'Mosaïque',
      category: 'GRILLES',
      description: 'Grille mosaïque.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'masonry',
    ),
    LayoutComponentDefinition(
      id: 'feed',
      label: 'Flux',
      category: 'GRILLES',
      description: 'Contenus présentés sous forme de flux.',
      renderer: LayoutComponentRenderer.grid,
      loadingPreview: LayoutComponentLoadingPreview.grid,
      legacyLayout: 'spotlight',
    ),
    LayoutComponentDefinition(
      id: 'mangaFeaturedCard',
      label: 'Vedette manga',
      category: 'MANGA & LECTURE',
      description:
          'Affiche manga avec titre et badge, compatible avec les items Home et Search.',
      renderer: LayoutComponentRenderer.mangaFeaturedCard,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'catalogue',
      supportedContexts: {
        LayoutComponentContext.homeMangaCard,
        LayoutComponentContext.search,
      },
    ),
    LayoutComponentDefinition(
      id: 'mangaChapterCard',
      label: 'Carte manga avec sous-titre',
      category: 'MANGA & LECTURE',
      description:
          'Affiche portrait avec titre et description disponibles sur les items Home et Search.',
      renderer: LayoutComponentRenderer.mangaChapterCard,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'catalogue',
      supportedContexts: {
        LayoutComponentContext.homeMangaCard,
        LayoutComponentContext.search,
      },
    ),
    LayoutComponentDefinition(
      id: 'homeEpisodeCard',
      label: 'Carte épisode sans progression',
      category: 'ÉPISODES & SAISONS',
      description:
          'Carte d’épisode sans progression, depuis le titre, le numéro et le visuel fournis.',
      renderer: LayoutComponentRenderer.homeEpisodeCard,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'catalogue',
      supportedContexts: {LayoutComponentContext.homeEpisodeCard},
    ),
    LayoutComponentDefinition(
      id: 'chapterCard',
      label: 'Carte de chapitre',
      category: 'MANGA & LECTURE',
      description:
          'Carte de chapitre avec manga, titre de chapitre et vignette disponibles.',
      renderer: LayoutComponentRenderer.chapterCard,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'catalogue',
      supportedContexts: {LayoutComponentContext.chapter},
    ),
    LayoutComponentDefinition(
      id: 'collectionCards',
      label: 'Cartes de collection',
      category: 'COLLECTIONS',
      description: 'Rail de cartes de collections.',
      renderer: LayoutComponentRenderer.collections,
      loadingPreview: LayoutComponentLoadingPreview.collections,
      legacyLayout: 'collectionCards',
    ),
    LayoutComponentDefinition(
      id: 'playlistCarousel',
      label: 'Carrousel de playlists',
      category: 'COLLECTIONS',
      description: 'Rail de collections et de playlists.',
      renderer: LayoutComponentRenderer.collections,
      loadingPreview: LayoutComponentLoadingPreview.collections,
      legacyLayout: 'collectionCards',
    ),
    // Explicit compatibility entries for component IDs already used in JSON.
    LayoutComponentDefinition(
      id: 'compactRow',
      aliases: ['compact'],
      label: 'Rangée compacte',
      category: 'RAILS',
      description: 'Ancienne présentation compacte.',
      renderer: LayoutComponentRenderer.posterRail,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'compact',
      selectable: false,
    ),
    LayoutComponentDefinition(
      id: 'historyRow',
      label: 'Historique',
      category: 'RAILS',
      description: 'Ancienne rangée d’historique.',
      renderer: LayoutComponentRenderer.posterRail,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'spotlight',
      selectable: false,
    ),
    LayoutComponentDefinition(
      id: 'metadataPoster',
      label: 'Affiche avec métadonnées',
      category: 'RAILS',
      description: 'Ancienne présentation d’affiches avec métadonnées.',
      renderer: LayoutComponentRenderer.posterRail,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'metadataPoster',
      selectable: false,
    ),
    LayoutComponentDefinition(
      id: 'statusPoster',
      label: 'Affiche avec statut',
      category: 'RAILS',
      description: 'Ancienne présentation d’affiches avec statut.',
      renderer: LayoutComponentRenderer.posterRail,
      loadingPreview: LayoutComponentLoadingPreview.row,
      legacyLayout: 'statusPoster',
      selectable: false,
    ),
  ];

  /// Hand-written legacy definitions plus one definition per gallery
  /// component, so every card documented by the gallery can be selected in a
  /// layout JSON and rendered by the extension home screen.
  static final List<LayoutComponentDefinition> all = List.unmodifiable([
    ...definitions,
    ...GalleryComponentCatalog.descriptors.map(
      (descriptor) => LayoutComponentDefinition(
        id: descriptor.id,
        aliases: descriptor.aliases,
        label: descriptor.label,
        category: descriptor.category,
        description: descriptor.description,
        renderer: _rendererForGalleryFamily(descriptor.renderer),
        loadingPreview: descriptor.loadingPreview,
        legacyLayout: _legacyLayoutForGalleryFamily(descriptor.renderer),
        selectable: descriptor.selectable,
        galleryFamily: descriptor.renderer,
      ),
    ),
  ]);

  /// Catalog definitions only, keyed by id (used by the gallery picker).
  static final Map<String, LayoutComponentDefinition> galleryById = {
    for (final definition in all)
      if (definition.galleryFamily != null) ...{
        definition.id: definition,
        for (final alias in definition.aliases) alias: definition,
      },
  };

  static LayoutComponentRenderer _rendererForGalleryFamily(
    GalleryComponentFamily family,
  ) => switch (family) {
    GalleryComponentFamily.posterRail => LayoutComponentRenderer.posterRail,
    GalleryComponentFamily.spotlight => LayoutComponentRenderer.spotlight,
    GalleryComponentFamily.banner => LayoutComponentRenderer.banner,
    GalleryComponentFamily.ranked => LayoutComponentRenderer.ranked,
    GalleryComponentFamily.landscape => LayoutComponentRenderer.landscape,
    GalleryComponentFamily.grid => LayoutComponentRenderer.grid,
    // Every other family reuses the grid renderer, which delegates to
    // GalleryComponentRenderer for the real card.
    _ => LayoutComponentRenderer.grid,
  };

  static String _legacyLayoutForGalleryFamily(
    GalleryComponentFamily family,
  ) => switch (family) {
    GalleryComponentFamily.spotlight => 'spotlight',
    GalleryComponentFamily.banner => 'banner',
    GalleryComponentFamily.ranked => 'ranked',
    GalleryComponentFamily.landscape => 'landscapeStacked',
    _ => 'catalogue',
  };

  static final Map<String, LayoutComponentDefinition> _byId = {
    for (final definition in all) ...{
      definition.id: definition,
      for (final alias in definition.aliases) alias: definition,
    },
  };

  static LayoutComponentDefinition? resolve(String id) => _byId[id];

  static List<LayoutComponentDefinition> forContext(
    LayoutComponentContext context, {
    bool selectableOnly = false,
  }) => List.unmodifiable(
    all.where(
      (definition) =>
          definition.supportedContexts.contains(context) &&
          (!selectableOnly || definition.selectable),
    ),
  );

  static List<String> availableIds(LayoutComponentContext context) =>
      forContext(context)
          .expand((definition) => [definition.id, ...definition.aliases])
          .toSet()
          .toList(growable: false);

  static bool supports(String id, LayoutComponentContext context) =>
      resolve(id)?.supportedContexts.contains(context) ?? false;

  static String? legacyLayoutFor(String id) => resolve(id)?.legacyLayout;

  static String unknownComponentMessage(
    String id,
    LayoutComponentContext context,
  ) =>
      'Composant inconnu : $id. Composants disponibles : '
      '${availableIds(context).join(', ')}';
}
