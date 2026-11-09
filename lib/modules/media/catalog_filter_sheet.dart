/// Denseur d'affichage choisi dans la section « Affichage » de la feuille.
///
/// Les modes reprennent ceux de la bibliothèque pour que toutes les surfaces
/// catalogue (recherche, « voir tout », studios) exposent le même jeu.
enum CatalogLayout { grid, comfortable, list, compact, coverOnly }

/// Libellé français d'un [CatalogLayout], partagé par toutes les surfaces qui
/// proposent le sélecteur « Affichage » (catalogue, recherche, studios).
String catalogLayoutLabel(CatalogLayout layout) => switch (layout) {
  CatalogLayout.grid => 'Grille',
  CatalogLayout.comfortable => 'Grille espacée',
  CatalogLayout.list => 'Liste',
  CatalogLayout.compact => 'Grille compacte',
  CatalogLayout.coverOnly => 'Grille avec seulement la couverture',
};

/// Nombre de colonnes effectif d'une grille de catalogue : un réglage explicite
/// (1–6) l'emporte, sinon le mode d'affichage ajuste le nombre de colonnes de
/// l'appareil. Partagé par toutes les grilles pour rester cohérent.
int catalogDisplayColumns({
  required int deviceColumns,
  required CatalogLayout layout,
  required int columns,
}) {
  if (columns > 0) return columns.clamp(1, 6);
  return switch (layout) {
    CatalogLayout.comfortable => (deviceColumns - 1).clamp(1, deviceColumns),
    CatalogLayout.compact => (deviceColumns + 1).clamp(1, 6),
    _ => deviceColumns,
  };
}

/// Le titre se superpose à la couverture sauf en grille espacée (titre dessous)
/// et en mode « couverture seule » (pas de titre du tout).
bool catalogLayoutTitleOnCover(CatalogLayout layout) =>
    layout != CatalogLayout.comfortable && layout != CatalogLayout.coverOnly;

/// Le titre est affiché partout sauf en mode « couverture seule ».
bool catalogLayoutShowTitle(CatalogLayout layout) =>
    layout != CatalogLayout.coverOnly;

/// Un choix de la section « Type » (ex. Film, Série, Animation…).
class CatalogTypeOption {
  final String label;
  final String value;
  const CatalogTypeOption(this.label, this.value);
}

/// Un choix de la section « Ordre ».
class CatalogSortOption {
  final String label;
  final String value;
  const CatalogSortOption(this.label, this.value);
}

/// État de filtres partagé par la coquille catalogue « voir tout ».
/// Réutilisable par TMDB, AniList et les extensions.
class CatalogFilterState {
  /// `'all'` ou la valeur d'une [CatalogTypeOption] du mode courant.
  String type;

  /// Années minimale / maximale incluses ; `null` = sans filtre d'années.
  int? minYear;
  int? maxYear;

  /// Note minimale (0 = toutes les notes).
  double minRating;

  /// Genres sélectionnés (libellés exacts, comparaison insensible à la casse).
  final Set<String> genres;

  /// Clé d'une [CatalogSortOption].
  String sortMode;

  /// Densité d'affichage de la grille.
  CatalogLayout layout;

  /// Nombre de colonnes explicite. `0` laisse la page choisir selon l’écran.
  int columns;

  CatalogFilterState({
    this.type = 'all',
    this.minYear,
    this.maxYear,
    this.minRating = 0,
    Set<String>? genres,
    this.sortMode = 'popular',
    this.layout = CatalogLayout.grid,
    this.columns = 0,
  }) : genres = {...?genres};

  CatalogFilterState copy() => CatalogFilterState()
    ..type = type
    ..minYear = minYear
    ..maxYear = maxYear
    ..minRating = minRating
    ..genres.addAll(genres)
    ..sortMode = sortMode
    ..layout = layout
    ..columns = columns;

  void reset() {
    type = 'all';
    minYear = null;
    maxYear = null;
    minRating = 0;
    genres.clear();
    sortMode = 'popular';
    layout = CatalogLayout.grid;
    columns = 0;
  }

  bool get isDefault =>
      type == 'all' &&
      minYear == null &&
      maxYear == null &&
      minRating <= 0 &&
      genres.isEmpty &&
      sortMode == 'popular' &&
      layout == CatalogLayout.grid &&
      columns == 0;

  /// Une année donnée passe-t-elle le filtre d'années ? Un item sans année
  /// n'est masqué que si l'utilisateur a explicitement borné les années.
  bool matchesYears(int? year) {
    if (minYear == null && maxYear == null) return true;
    if (year == null) return false;
    if (minYear != null && year < minYear!) return false;
    if (maxYear != null && year > maxYear!) return false;
    return true;
  }

  /// Les genres d'un item couvrent-ils tous les genres sélectionnés ?
  bool matchesGenres(Iterable<String> itemGenres) {
    if (genres.isEmpty) return true;
    final lowercase = itemGenres.map((g) => g.toLowerCase()).toSet();
    return genres.every((g) => lowercase.contains(g.toLowerCase()));
  }
}

/// The catalogue filter *state* lives here; its UI moved to
/// `overlay_filter_menu.dart` (`CatalogFilterOverlay`), which renders inside
/// the shared glass panel instead of a bottom sheet.
