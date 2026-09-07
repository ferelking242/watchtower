/// Étape 1 du pipeline de normalisation : Tokenisation.
///
/// Transforme un nom de fichier brut en liste de tokens bruts.
/// Exemples :
///   "[Nyaa] Naruto_Shippuden_S02E014_VOSTFR_1080p_x265_AAC.mkv"
///   → ["Nyaa", "Naruto", "Shippuden", "S02E014", "VOSTFR", "1080p", "x265", "AAC"]
class Tokenizer {
  // Séparateurs courants dans les noms de fichiers de release
  static final _sepPattern = RegExp(r'[\s_\.\-\+]+');

  // Supprime l'extension et le chemin, ne garde que le nom de fichier
  static final _extPattern = RegExp(r'\.[a-zA-Z0-9]{2,5}$');

  /// Extrait les tokens bruts d'un nom de fichier.
  static List<String> tokenize(String filename) {
    // 1. Ne garder que le basename (sans dossier)
    var name = _basename(filename);

    // 2. Retirer l'extension
    name = name.replaceFirst(_extPattern, '');

    // 3. Extraire et retirer les blocs entre [] et () avant split
    //    (ils seront re-injectés comme tokens spéciaux)
    final List<String> bracketTokens = [];
    name = name.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]|\(([^)]*)\)'),
      (m) {
        final content = (m.group(1) ?? m.group(2) ?? '').trim();
        if (content.isNotEmpty) bracketTokens.add(content);
        return ' ';
      },
    );

    // 4. Splitter sur les séparateurs
    final raw = name
        .split(_sepPattern)
        .where((t) => t.isNotEmpty)
        .toList();

    // 5. Ajouter les tokens extraits des brackets
    return [...raw, ...bracketTokens];
  }

  /// Extrait le basename d'un chemin (cross-platform).
  static String _basename(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? path.substring(i + 1) : path;
  }
}
