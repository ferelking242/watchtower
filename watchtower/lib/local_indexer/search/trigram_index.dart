/// Index de trigrammes pour la recherche floue.
///
/// Un trigramme est une sous-chaîne de 3 caractères consécutifs.
/// Ex : "naruto" → { "nar", "aru", "rut", "uto" }
///
/// La recherche par trigramme tolère les fautes de frappe, les abréviations
/// et les approximations de titre.
///
/// Usage :
/// ```dart
/// final idx = TrigramIndex();
/// idx.add(42, 'Naruto Shippuden');
/// idx.add(43, 'Naruto');
/// final results = idx.search('nruto'); // retrouve 42 et 43 malgré la faute
/// ```
class TrigramIndex {
  /// Map trigramme → ensemble d'IDs de documents.
  final Map<String, Set<int>> _index = {};

  /// Map id → texte original (pour calcul de score Jaccard).
  final Map<int, String> _docs = {};

  // ── Construction ──────────────────────────────────────────────────────────

  /// Ajoute un document à l'index.
  void add(int id, String text) {
    final clean = _normalize(text);
    _docs[id] = clean;
    for (final tg in _trigrams(clean)) {
      (_index[tg] ??= {}).add(id);
    }
  }

  /// Supprime un document de l'index.
  void remove(int id) {
    final text = _docs.remove(id);
    if (text == null) return;
    for (final tg in _trigrams(text)) {
      _index[tg]?.remove(id);
      if (_index[tg]?.isEmpty == true) _index.remove(tg);
    }
  }

  /// Met à jour un document existant.
  void update(int id, String newText) {
    remove(id);
    add(id, newText);
  }

  /// Reconstruction complète de l'index depuis un map id→texte.
  void rebuild(Map<int, String> docs) {
    _index.clear();
    _docs.clear();
    docs.forEach(add);
  }

  // ── Recherche ─────────────────────────────────────────────────────────────

  /// Recherche les documents correspondant à [query] et retourne un map
  /// id → score Jaccard (0.0–1.0).
  ///
  /// [minScore] : seuil minimum (défaut 0.2 pour tolérer les fautes).
  Map<int, double> search(String query, {double minScore = 0.2}) {
    if (query.isEmpty) return {};

    final qNorm = _normalize(query);
    final qTrigrams = _trigrams(qNorm);
    if (qTrigrams.isEmpty) return {};

    // Compte les trigrammes en commun pour chaque document candidat
    final hits = <int, int>{};
    for (final tg in qTrigrams) {
      for (final id in _index[tg] ?? <int>{}) {
        hits[id] = (hits[id] ?? 0) + 1;
      }
    }

    // Calcul du score Jaccard : |intersection| / |union|
    final results = <int, double>{};
    for (final entry in hits.entries) {
      final id = entry.key;
      final inter = entry.value;
      final docTg = _trigrams(_docs[id]!).length;
      final union = qTrigrams.length + docTg - inter;
      if (union <= 0) continue;
      final score = inter / union;
      if (score >= minScore) results[id] = score;
    }

    return results;
  }

  /// Nombre de documents indexés.
  int get length => _docs.length;

  bool get isEmpty => _docs.isEmpty;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Normalise le texte avant indexation / recherche.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Génère l'ensemble des trigrammes d'une chaîne.
  static Set<String> _trigrams(String text) {
    final padded = ' $text '; // padding pour les bords
    final result = <String>{};
    for (var i = 0; i < padded.length - 2; i++) {
      result.add(padded.substring(i, i + 3));
    }
    return result;
  }
}
