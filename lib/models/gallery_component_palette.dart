import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/ui_layout.dart';

/// A gallery component preselected for a home stack.
class GalleryHomePreset {
  const GalleryHomePreset({
    required this.id,
    required this.component,
    required this.title,
    this.params = const {},
  });

  final String id;
  final String component;
  final String title;
  final Map<String, dynamic> params;
}

/// The kind of value a [GalleryComponentParameter] accepts.
enum GalleryParameterKind { text, number, boolean, selection }

/// A single configurable value of a gallery component.
///
/// Values are stored in `UiSection.params` (see `lib/models/ui_layout.dart`) so
/// the layout JSON keeps full control over what a component shows while the
/// component itself stays data-bound.
class GalleryComponentParameter {
  const GalleryComponentParameter({
    required this.key,
    required this.label,
    this.kind = GalleryParameterKind.text,
    this.description,
    this.defaultValue,
    this.options = const [],
  });

  final String key;
  final String label;
  final GalleryParameterKind kind;
  final String? description;
  final String? defaultValue;
  final List<String> options;

  Object? coerce(String? raw) {
    if (raw == null) return null;
    switch (kind) {
      case GalleryParameterKind.number:
        return num.tryParse(raw);
      case GalleryParameterKind.boolean:
        return raw == 'true' || raw == '1';
      case GalleryParameterKind.selection:
      case GalleryParameterKind.text:
        return raw;
    }
  }
}

/// The parameters each [GalleryComponentFamily] understands, with sensible
/// defaults, so every catalog component is immediately usable.
class GalleryComponentPalette {
  GalleryComponentPalette._();

  static const List<GalleryComponentParameter> common = [
    GalleryComponentParameter(
      key: 'title',
      label: 'Titre de la section',
      description: 'Remplace le titre déduit de la section.',
    ),
    GalleryComponentParameter(
      key: 'items',
      label: 'Nombre de cartes',
      kind: GalleryParameterKind.number,
      description: 'Limite le nombre de cartes affichées.',
    ),
    GalleryComponentParameter(
      key: 'layout',
      label: 'Disposition',
      kind: GalleryParameterKind.selection,
      options: ['row', 'grid'],
      defaultValue: 'row',
      description: 'Rangée horizontale défilante ou grille fixe.',
    ),
    GalleryComponentParameter(
      key: 'columns',
      label: 'Colonnes (grille)',
      kind: GalleryParameterKind.number,
      description: 'Nombre de colonnes quand la disposition est « grid ».',
    ),
    GalleryComponentParameter(
      key: 'rows',
      label: 'Lignes (grille)',
      kind: GalleryParameterKind.number,
      description: 'Nombre de lignes affichées quand la disposition est '
          '« grid ». Laisse vide pour tout afficher.',
    ),
    GalleryComponentParameter(
      key: 'height',
      label: 'Hauteur (px)',
      kind: GalleryParameterKind.number,
      description: 'Hauteur forcée pour les cartes qui la supportent.',
    ),
    GalleryComponentParameter(
      key: 'width',
      label: 'Largeur (px)',
      kind: GalleryParameterKind.number,
      description: 'Largeur des cartes. Vide = largeur de design ou cellule.',
    ),
    GalleryComponentParameter(
      key: 'spacing',
      label: 'Espacement (px)',
      kind: GalleryParameterKind.number,
      description: 'Espace entre les cartes d\'une rangée ou d\'une grille.',
    ),
    GalleryComponentParameter(
      key: 'subtitle',
      label: 'Sous-titre',
    ),
    GalleryComponentParameter(
      key: 'badge',
      label: 'Pastille',
    ),
    GalleryComponentParameter(
      key: 'hero',
      label: 'Bandeau héro',
      kind: GalleryParameterKind.boolean,
    ),
    GalleryComponentParameter(
      key: 'fill',
      label: 'Pleine largeur',
      kind: GalleryParameterKind.boolean,
      description: 'Étire les cartes composites à la largeur du conteneur.',
    ),
  ];

  static const Map<GalleryComponentFamily, List<GalleryComponentParameter>>
  _specific = {
    GalleryComponentFamily.richMedia: [
      GalleryComponentParameter(
        key: 'genres',
        label: 'Genres',
        description: 'Genres séparés par des virgules.',
      ),
    ],
    GalleryComponentFamily.posterRail: [
      GalleryComponentParameter(
        key: 'compact',
        label: 'Affiche compacte',
        kind: GalleryParameterKind.boolean,
        defaultValue: 'false',
      ),
    ],
    GalleryComponentFamily.mangaGenre: [
      GalleryComponentParameter(
        key: 'showCount',
        label: 'Afficher les compteurs',
        kind: GalleryParameterKind.boolean,
        defaultValue: 'true',
      ),
    ],
    GalleryComponentFamily.mangaReader: [
      GalleryComponentParameter(
        key: 'readingDirection',
        label: 'Sens de lecture',
        kind: GalleryParameterKind.selection,
        options: ['ltr', 'rtl', 'vertical'],
      ),
    ],
    GalleryComponentFamily.mangaStats: [
      GalleryComponentParameter(
        key: 'period',
        label: 'Période',
        kind: GalleryParameterKind.selection,
        options: ['daily', 'weekly', 'monthly'],
      ),
    ],
    GalleryComponentFamily.ranking: [
      GalleryComponentParameter(
        key: 'rankLabel',
        label: 'Libellé du classement',
        defaultValue: 'Top 10',
      ),
    ],
    GalleryComponentFamily.landscape: [
      GalleryComponentParameter(
        key: 'genres',
        label: 'Sous-titre des cartes',
      ),
    ],
  };

  static List<GalleryComponentParameter> forFamily(
    GalleryComponentFamily family,
  ) => List.unmodifiable([...common, ...?_specific[family]]);

  static List<GalleryComponentParameter> forDescriptor(
    GalleryComponentDescriptor descriptor,
  ) => forFamily(descriptor.renderer);

  /// Ready-to-render sections for the manga home stack.
  ///
  /// Each entry points at a gallery component and mirrors the
  /// `EnumMangaHomeWidget` cards, so the manga home composes the exact cards
  /// the developer gallery previews without shipping a second implementation.
  static const List<GalleryHomePreset> mangaHomeStack = [
    GalleryHomePreset(
      id: 'hero',
      component: 'manga-spotlight',
      title: 'Spotlight',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'featured',
      component: 'manga-featured',
      title: 'À la une',
      params: {'dataSource': 'latest'},
    ),
    GalleryHomePreset(
      id: 'chapters',
      component: 'manga-chapter',
      title: 'Nouveaux chapitres',
      params: {'dataSource': 'latest'},
    ),
    GalleryHomePreset(
      id: 'continue-reading',
      component: 'manga-resume',
      title: 'Reprendre la lecture',
      params: {'subtitle': 'Chapitre 148 · il y a 2 h'},
    ),
    GalleryHomePreset(
      id: 'genres',
      component: 'manga-genres',
      title: 'Genres',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'banner',
      component: 'manga-banner',
      title: 'Bannière',
      params: {'dataSource': 'latest'},
    ),
    GalleryHomePreset(
      id: 'top3',
      component: 'manga-top3',
      title: 'Top 3',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'updates',
      component: 'manga-update-row',
      title: 'Dernières mises à jour',
      params: {'dataSource': 'latest'},
    ),
    GalleryHomePreset(
      id: 'latest-updates',
      component: 'manga-latest-update',
      title: 'Latest Chapter Updates',
      params: {'dataSource': 'latest'},
    ),
    GalleryHomePreset(
      id: 'ranking',
      component: 'manga-ranking',
      title: 'Top Ranking',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'vote',
      component: 'manga-vote',
      title: 'Vote communautaire',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'collection',
      component: 'manga-collection-showcase',
      title: 'Collection communautaire',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'trending',
      component: 'manga-trending-list',
      title: 'Listes tendance',
      params: {'dataSource': 'popular'},
    ),
    GalleryHomePreset(
      id: 'scan-groups',
      component: 'manga-scan-group',
      title: 'Groupes de scan',
      params: {'dataSource': 'popular'},
    ),
  ];

  /// A gallery component preselected for a home stack.
  static List<UiSection> buildSections(List<GalleryHomePreset> presets) => [
    for (final preset in presets)
      UiSection(
        id: preset.id,
        component: preset.component,
        title: preset.title,
        params: preset.params,
      ),
  ];

  /// Merges catalog defaults with the values stored in the layout JSON.
  static Map<String, Object?> resolved(
    GalleryComponentFamily family,
    Map<String, dynamic> overrides,
  ) {
    final values = <String, Object?>{};
    for (final parameter in forFamily(family)) {
      if (parameter.defaultValue != null) {
        values[parameter.key] = parameter.coerce(parameter.defaultValue);
      }
    }
    values.addAll(overrides);
    return values;
  }
}
