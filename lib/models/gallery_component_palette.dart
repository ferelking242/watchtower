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

/// The section a [GalleryComponentParameter] belongs to, used by the
/// component detail sheet to keep a long parameter list readable.
enum GalleryParameterGroup { general, layout, effects, content }

extension GalleryParameterGroupLabel on GalleryParameterGroup {
  String get label => switch (this) {
    GalleryParameterGroup.general => 'Général',
    GalleryParameterGroup.layout => 'Disposition',
    GalleryParameterGroup.effects => 'Effets',
    GalleryParameterGroup.content => 'Contenu',
  };
}

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
    this.example,
    this.aliases = const [],
    this.group = GalleryParameterGroup.general,
  });

  final String key;
  final String label;
  final GalleryParameterKind kind;
  final String? description;
  final String? defaultValue;
  final List<String> options;

  /// A ready-to-paste value shown in the detail sheet, e.g. `#4CAF50`.
  final String? example;

  /// Other spellings accepted by the renderer (`auto-scroll` for
  /// `autoScroll`, `coverLeft` for `mirror`…).
  final List<String> aliases;

  final GalleryParameterGroup group;

  /// JSON type name shown in the detail sheet.
  String get typeName => switch (kind) {
    GalleryParameterKind.number => 'number',
    GalleryParameterKind.boolean => 'boolean',
    GalleryParameterKind.selection => 'string (choix)',
    GalleryParameterKind.text => 'string',
  };

  /// The value rendered when the layout omits this key.
  String get effectiveDefault =>
      defaultValue ?? switch (kind) {
        GalleryParameterKind.boolean => 'false',
        GalleryParameterKind.number => '—',
        GalleryParameterKind.selection => options.isEmpty ? '—' : options.first,
        GalleryParameterKind.text => '—',
      };

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
    // ── Général ───────────────────────────────────────────────────────────
    GalleryComponentParameter(
      key: 'title',
      label: 'Titre de la section',
      description:
          'Remplace le titre de la section. Le titre est rendu par la '
          'section (au-dessus de la carte), jamais par la carte elle-même.',
      example: 'Tendances de la semaine',
    ),
    GalleryComponentParameter(
      key: 'subtitle',
      label: 'Sous-titre de la section',
      example: 'Mis à jour il y a 2 h',
    ),
    GalleryComponentParameter(
      key: 'icon',
      label: 'Icône de la section',
      description:
          'Nom stable d\'icône Material. Voir le catalogue d\'icônes de la '
          'documentation.',
      example: 'whatshot',
      aliases: ['headerIcon'],
    ),
    GalleryComponentParameter(
      key: 'seeAll',
      label: 'Action « Tout voir »',
      kind: GalleryParameterKind.boolean,
      description:
          'Affiche l\'action « Tout voir » dans l\'en-tête de la section.',
    ),
    GalleryComponentParameter(
      key: 'items',
      label: 'Nombre de cartes',
      kind: GalleryParameterKind.number,
      description: 'Limite le nombre de cartes affichées.',
      example: '6',
      group: GalleryParameterGroup.content,
    ),
    // ── Disposition ───────────────────────────────────────────────────────
    GalleryComponentParameter(
      key: 'layout',
      label: 'Disposition',
      kind: GalleryParameterKind.selection,
      options: ['row', 'grid'],
      defaultValue: 'row',
      description: 'Rangée horizontale défilante ou grille fixe.',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'columns',
      label: 'Colonnes (grille)',
      kind: GalleryParameterKind.number,
      description: 'Nombre de colonnes quand la disposition est « grid ».',
      example: '3',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'rows',
      label: 'Lignes (grille)',
      kind: GalleryParameterKind.number,
      description:
          'Nombre de lignes affichées quand la disposition est '
          '« grid ». Laisse vide pour tout afficher.',
      example: '2',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'width',
      label: 'Largeur (px)',
      kind: GalleryParameterKind.number,
      description: 'Largeur des cartes. Vide = largeur de design ou cellule.',
      example: '430',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'height',
      label: 'Hauteur (px)',
      kind: GalleryParameterKind.number,
      description: 'Hauteur forcée pour les cartes qui la supportent.',
      example: '150',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'spacing',
      label: 'Espacement (px)',
      kind: GalleryParameterKind.number,
      description:
          'Espace entre les cartes d\'une même rangée (horizontal) ou d\'une '
          'même colonne (vertical).',
      example: '12',
      aliases: ['gap', 'spaceBetween'],
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'spacingX',
      label: 'Espacement horizontal (px)',
      kind: GalleryParameterKind.number,
      description:
          'Espace gauche-droite entre deux cartes. Prioritaire sur '
          '`spacing` dans le sens horizontal.',
      example: '12',
      aliases: ['horizontalSpacing', 'spaceBetweenX'],
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'spacingY',
      label: 'Espacement vertical (px)',
      kind: GalleryParameterKind.number,
      description:
          'Espace haut-bas entre deux rangées de cartes. Prioritaire sur '
          '`spacing` dans le sens vertical.',
      example: '12',
      aliases: ['verticalSpacing', 'spaceBetweenY'],
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'fill',
      label: 'Pleine largeur',
      kind: GalleryParameterKind.boolean,
      description: 'Étire les cartes composites à la largeur du conteneur.',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'flat',
      label: 'Sans panneau',
      kind: GalleryParameterKind.boolean,
      description:
          'Retire le cadre de panneau autour des cartes. Les cartes n\'ont de '
          'toute façon plus de panneau en production ; ce paramètre ne sert '
          'qu\'à l\'aperçu isolé de la galerie.',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'scroll',
      label: 'Défilement',
      kind: GalleryParameterKind.boolean,
      description:
          'Fait défiler la rangée horizontalement au lieu de l\'empiler en '
          'grille (cartes de tuiles : pays, genres…).',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'scrollDirection',
      label: 'Sens de défilement',
      kind: GalleryParameterKind.selection,
      options: ['horizontal', 'vertical'],
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'hero',
      label: 'Bandeau héro',
      kind: GalleryParameterKind.boolean,
      group: GalleryParameterGroup.layout,
    ),
    // ── Effets ────────────────────────────────────────────────────────────
    GalleryComponentParameter(
      key: 'color',
      label: 'Couleur d\'accent',
      description:
          'Nom de couleur (`green`, `red`, `orange`, `blue`, `purple`…) ou '
          'code hexadécimal `#RRGGBB` / `#AARRGGBB`. Vide = couleur du thème.',
      example: '#4CAF50',
      aliases: ['accent'],
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'animation',
      label: 'Animation',
      kind: GalleryParameterKind.boolean,
      description:
          'Anime le remplissage de la barre de progression et les entrées de '
          'carte.',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'chevron',
      label: 'Chevron',
      kind: GalleryParameterKind.boolean,
      description:
          'Ajoute un chevron à droite de la carte, qui indique qu\'elle '
          'ouvre une page de détail.',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'mirror',
      label: 'Effet miroir',
      kind: GalleryParameterKind.boolean,
      description:
          'Place le visuel à droite au lieu de la gauche (le texte reste '
          'aligné à gauche).',
      aliases: ['coverLeft', 'flip', 'inverted'],
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'reverse',
      label: 'Effet inversé',
      kind: GalleryParameterKind.boolean,
      description:
          'Effet miroir complet : visuel à droite **et** texte aligné à '
          'droite.',
      aliases: ['reversed'],
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'tilt',
      label: 'Inclinaison (rad)',
      kind: GalleryParameterKind.number,
      description:
          'Inclinaison des visuels du carrousel d\'univers (0 = droit, 0.05 = '
          'léger penché vers le haut à droite).',
      example: '0.05',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'autoScroll',
      label: 'Défilement automatique',
      kind: GalleryParameterKind.boolean,
      description:
          'Fait défiler la rangée en continu. Un glissement de l\'utilisateur '
          'le suspend.',
      aliases: ['auto-scroll', 'autoplay'],
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'speed',
      label: 'Vitesse de défilement',
      kind: GalleryParameterKind.number,
      description: 'Vitesse du défilement automatique, en pixels par seconde.',
      example: '24',
      aliases: ['scrollSpeed'],
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'percent',
      label: 'Pourcentage',
      kind: GalleryParameterKind.boolean,
      description:
          'Force l\'affichage du pourcentage. Vide = suit le `style` de la '
          'carte de progression.',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'style',
      label: 'Style de carte',
      kind: GalleryParameterKind.selection,
      options: ['percent', 'bar', 'chip', 'series'],
      description:
          'Variante de la carte de progression : `percent` (barre + '
          'pourcentage), `bar` (barre seule), `chip` (pastille sur la '
          'vignette), `series` (bloc série).',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'compact',
      label: 'Compact',
      kind: GalleryParameterKind.boolean,
      description: 'Réduit les marges internes de la carte.',
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'labelTiles',
      label: 'Légendes des tuiles',
      kind: GalleryParameterKind.boolean,
      group: GalleryParameterGroup.effects,
    ),
    GalleryComponentParameter(
      key: 'coverWidth',
      label: 'Largeur du visuel (px)',
      kind: GalleryParameterKind.number,
      description: 'Largeur de la vignette latérale des cartes horizontales.',
      example: '118',
      group: GalleryParameterGroup.layout,
    ),
    GalleryComponentParameter(
      key: 'tileWidth',
      label: 'Largeur de tuile (px)',
      kind: GalleryParameterKind.number,
      description: 'Largeur d\'une tuile d\'épisode dans un carrousel.',
      example: '96',
      group: GalleryParameterGroup.layout,
    ),
    // ── Contenu ───────────────────────────────────────────────────────────
    GalleryComponentParameter(key: 'badge', label: 'Pastille'),
    GalleryComponentParameter(
      key: 'actionLabel',
      label: 'Libellé du bouton',
      description: 'Texte du bouton d\'action des cartes riches.',
      example: 'Voir la collection',
    ),
    GalleryComponentParameter(
      key: 'stats',
      label: 'Statistiques',
      description: 'Ligne de statistiques affichée sous le titre.',
      example: '32 films · 18 séries',
    ),
    GalleryComponentParameter(
      key: 'seriesMeta',
      label: 'Métadonnées de série',
      description: 'Saison, épisodes ou statut de diffusion.',
      example: 'S3 · Ép. 5',
    ),
    GalleryComponentParameter(
      key: 'remaining',
      label: 'Temps restant',
      description: 'Libellé du temps restant (progression streaming).',
      example: '12 min restantes',
    ),
    GalleryComponentParameter(
      key: 'time',
      label: 'Horodatage',
      description: 'Moment affiché par les cartes de lecture.',
      example: 'Hier',
    ),
    GalleryComponentParameter(
      key: 'cast',
      label: 'Casting',
      description: 'Noms séparés par des virgules.',
      example: 'Pedro Pascal, Bella Ramsey',
    ),
    GalleryComponentParameter(
      key: 'tags',
      label: 'Étiquettes',
      description: 'Étiquettes séparées par des virgules.',
      example: 'Action, Drame',
    ),
    GalleryComponentParameter(
      key: 'runtime',
      label: 'Durée (min)',
      kind: GalleryParameterKind.number,
      example: '52',
    ),
    GalleryComponentParameter(
      key: 'rank',
      label: 'Rang',
      kind: GalleryParameterKind.number,
      description: 'Rang de départ des cartes classées.',
      example: '1',
    ),
    GalleryComponentParameter(
      key: 'progress',
      label: 'Progression (0–1)',
      kind: GalleryParameterKind.number,
      description: 'Avancement affiché par les cartes de progression.',
      example: '0.68',
    ),
    GalleryComponentParameter(
      key: 'numbered',
      label: 'Numéroter',
      kind: GalleryParameterKind.boolean,
      description: 'Affiche le rang en tête de chaque carte.',
    ),
    GalleryComponentParameter(
      key: 'hd',
      label: 'Badge HD',
      kind: GalleryParameterKind.boolean,
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
      GalleryComponentParameter(key: 'genres', label: 'Sous-titre des cartes'),
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
  /// This is the single source of truth for the manga home order: the
  /// production screen, the gallery previews and the layout editor all read
  /// this list, so the manga home composes the exact cards the developer
  /// gallery previews without shipping a second implementation.
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
