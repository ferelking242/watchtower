/// Denseur d'affichage choisi dans la section « Affichage » de la feuille.
enum CatalogLayout { grid, comfortable, list, compact }

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
