import 'package:watchtower/local_indexer/models/local_indexed_item.dart';

/// Résultat d'une recherche dans l'index local.
class LocalSearchResult {
  /// L'élément trouvé.
  final LocalIndexedItem item;

  /// Score de pertinence (0.0 → 1.0). Plus proche de 1.0 = meilleur match.
  final double score;

  /// Type de correspondance obtenu.
  final MatchType matchType;

  /// Portion du titre qui correspond à la requête (pour highlighting).
  final String? matchedFragment;

  const LocalSearchResult({
    required this.item,
    required this.score,
    required this.matchType,
    this.matchedFragment,
  });

  @override
  String toString() =>
      'LocalSearchResult(title=${item.title}, score=${score.toStringAsFixed(3)}, type=$matchType)';
}

enum MatchType {
  /// Correspondance exacte sur le titre complet.
  exact,

  /// Correspondance par préfixe (début du mot/titre).
  prefix,

  /// Correspondance sur un mot du titre.
  word,

  /// Correspondance par trigramme (recherche floue / fautes de frappe).
  trigram,

  /// Correspondance sur la clé canonique.
  canonical,
}
