/// Génération de la clé canonique.
///
/// La clé canonique permet de regrouper toutes les variantes d'une même
/// œuvre :
///   "Naruto Shippuden"
///   "Naruto_Shippuden"
///   "[SubsPlease] Naruto Shippuden"
///   "NARUTO SHIPPUDEN"
///   → toutes → "naruto shippuden"
///
/// Règles de normalisation :
///   1. Passer en minuscules.
///   2. Retirer les articles courants en début (the, a, an, le, la, les, un,
///      une, des).
///   3. Supprimer la ponctuation non significative.
///   4. Normaliser les espaces multiples.
///   5. Trim final.
class CanonicalKey {
  static final _punctuation = RegExp(r"[^\w\s']", unicode: true);
  static final _multispace = RegExp(r'\s+');
  static final _leadingArticles = RegExp(
    r'^(?:the|a|an|le|la|les|un|une|des|l)\s+',
    caseSensitive: false,
  );
  // Caractères accentués → ASCII simple (translittération basique)
  static const _accentMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n', 'ç': 'c',
    'À': 'a', 'Á': 'a', 'Â': 'a', 'Ä': 'a', 'Å': 'a',
    'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e',
    'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i',
    'Ò': 'o', 'Ó': 'o', 'Ô': 'o', 'Ö': 'o',
    'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u',
    'Ñ': 'n', 'Ç': 'c',
  };

  /// Génère la clé canonique à partir d'un titre nettoyé.
  static String generate(String title) {
    var key = title.toLowerCase();

    // Translittération basique des accents
    for (final entry in _accentMap.entries) {
      key = key.replaceAll(entry.key, entry.value);
    }

    // Retirer la ponctuation
    key = key.replaceAll(_punctuation, ' ');

    // Retirer les articles en début
    key = key.replaceAll(_leadingArticles, '');

    // Normaliser les espaces
    key = key.replaceAll(_multispace, ' ').trim();

    return key;
  }

  /// Génère une clé canonique incluant l'épisode/chapitre pour identifier
  /// l'épisode précisément (utilisé pour la déduplication).
  static String generateWithEpisode(
    String title, {
    int? season,
    int? episode,
    int? chapter,
    int? volume,
  }) {
    final base = generate(title);
    final parts = <String>[base];
    if (season != null) parts.add('s${season.toString().padLeft(2, '0')}');
    if (episode != null) parts.add('e${episode.toString().padLeft(3, '0')}');
    if (volume != null) parts.add('v${volume.toString().padLeft(2, '0')}');
    if (chapter != null) parts.add('c${chapter.toString().padLeft(4, '0')}');
    return parts.join('_');
  }
}
