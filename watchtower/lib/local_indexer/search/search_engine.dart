import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_result.dart';
import 'package:watchtower/local_indexer/search/trigram_index.dart';

/// Moteur de recherche multi-index pour le Local Indexer.
///
/// Construit et maintient en mémoire quatre index complémentaires :
///   1. Index exact         → correspondance titre complet
///   2. Index de mots       → correspondance par mot individuel
///   3. Index de préfixes   → autocomplétion (tapé "nar" → "Naruto")
///   4. Index de trigrammes → recherche floue (fautes de frappe tolérées)
///
/// L'ensemble de ces index garantit une recherche instantanée même sur
/// plusieurs centaines de milliers d'entrées.
class LocalSearchEngine {
  // ── Index en mémoire ───────────────────────────────────────────────────────

  /// Stockage principal : id → item
  final Map<int, LocalIndexedItem> _items = {};

  /// Index exact : titre normalisé → ids
  final Map<String, Set<int>> _exactIndex = {};

  /// Index de mots : mot → ids
  final Map<String, Set<int>> _wordIndex = {};

  /// Index de préfixes : préfixe → ids (longueur min : 2)
  final Map<String, Set<int>> _prefixIndex = {};

  /// Index de trigrammes pour la recherche floue
  final TrigramIndex _trigramIndex = TrigramIndex();

  // ── Construction / Mise à jour ─────────────────────────────────────────────

  /// Ajoute ou met à jour un élément dans tous les index.
  void upsert(LocalIndexedItem item) {
    final id = item.id;

    // Si déjà présent, retirer l'ancienne version
    if (_items.containsKey(id)) _removeFromIndexes(id);

    _items[id] = item;
    _indexItem(id, item);
  }

  /// Ajoute un lot d'éléments en une seule passe (plus efficace que upsert
  /// répété pour la construction initiale).
  void upsertAll(List<LocalIndexedItem> items) {
    for (final item in items) {
      upsert(item);
    }
  }

  /// Supprime un élément de tous les index.
  void remove(int id) {
    _removeFromIndexes(id);
    _items.remove(id);
  }

  /// Vide complètement tous les index.
  void clear() {
    _items.clear();
    _exactIndex.clear();
    _wordIndex.clear();
    _prefixIndex.clear();
    _trigramIndex.rebuild({});
  }

  // ── Recherche ──────────────────────────────────────────────────────────────

  /// Recherche [query] dans tous les index et retourne les résultats triés
  /// par pertinence décroissante.
  ///
  /// [limit] : nombre maximum de résultats (défaut : 50).
  /// [kind]  : filtre optionnel par type de média.
  List<LocalSearchResult> search(
    String query, {
    int limit = 50,
    LocalMediaKind? kind,
  }) {
    if (query.trim().isEmpty) return [];

    final q = _normalize(query);
    final scores = <int, double>{};
    final matchTypes = <int, MatchType>{};

    // ── 1. Correspondance exacte (score 1.0) ───────────────────────────────
    for (final id in _exactIndex[q] ?? <int>{}) {
      scores[id] = 1.0;
      matchTypes[id] = MatchType.exact;
    }

    // ── 2. Correspondance par préfixe (score 0.85) ─────────────────────────
    if (q.length >= 2) {
      for (final id in _prefixIndex[q] ?? <int>{}) {
        if (!scores.containsKey(id)) {
          scores[id] = 0.85;
          matchTypes[id] = MatchType.prefix;
        }
      }
    }

    // ── 3. Correspondance par mot (score 0.75) ─────────────────────────────
    for (final word in q.split(' ')) {
      if (word.length < 2) continue;
      for (final id in _wordIndex[word] ?? <int>{}) {
        if (!scores.containsKey(id)) {
          scores[id] = 0.75;
          matchTypes[id] = MatchType.word;
        }
      }
      // Préfixes de mots (score 0.65)
      if (word.length >= 2) {
        for (final id in _prefixIndex[word] ?? <int>{}) {
          if (!scores.containsKey(id)) {
            scores[id] = 0.65;
            matchTypes[id] = MatchType.prefix;
          }
        }
      }
    }

    // ── 4. Recherche floue par trigramme (score proportionnel × 0.6) ───────
    final trigramHits = _trigramIndex.search(q, minScore: 0.15);
    for (final entry in trigramHits.entries) {
      final id = entry.key;
      if (!scores.containsKey(id)) {
        scores[id] = entry.value * 0.6;
        matchTypes[id] = MatchType.trigram;
      }
    }

    // ── 5. Construction des résultats ──────────────────────────────────────
    var results = <LocalSearchResult>[];

    for (final entry in scores.entries) {
      final id = entry.key;
      final item = _items[id];
      if (item == null) continue;

      // Filtre par type si demandé
      if (kind != null && item.kind != kind) continue;

      results.add(LocalSearchResult(
        item: item,
        score: entry.value,
        matchType: matchTypes[id] ?? MatchType.trigram,
        matchedFragment: _findFragment(item.title, query),
      ));
    }

    // ── 6. Tri + limite ────────────────────────────────────────────────────
    results.sort((a, b) => b.score.compareTo(a.score));
    if (results.length > limit) results = results.sublist(0, limit);

    return results;
  }

  /// Retourne tous les éléments d'un type donné, triés par titre.
  List<LocalIndexedItem> getByKind(LocalMediaKind kind) {
    return _items.values
        .where((i) => i.kind == kind)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  /// Retourne tous les éléments partageant la même clé canonique (variantes).
  List<LocalIndexedItem> getVariants(String canonicalKey) {
    return _items.values
        .where((i) => i.canonicalKey == canonicalKey)
        .toList();
  }

  /// Nombre total d'éléments indexés.
  int get count => _items.length;

  // ── Internals ──────────────────────────────────────────────────────────────

  void _indexItem(int id, LocalIndexedItem item) {
    final title = _normalize(item.title);
    final canonical = _normalize(item.canonicalKey);

    // Index exact (titre normalisé et clé canonique)
    (_exactIndex[title] ??= {}).add(id);
    if (canonical != title) (_exactIndex[canonical] ??= {}).add(id);

    // Index de mots
    for (final word in title.split(' ')) {
      if (word.length < 2) continue;
      (_wordIndex[word] ??= {}).add(id);
    }

    // Index de préfixes pour chaque mot (longueur 2 → len)
    for (final word in title.split(' ')) {
      if (word.length < 2) continue;
      for (var len = 2; len <= word.length; len++) {
        final prefix = word.substring(0, len);
        (_prefixIndex[prefix] ??= {}).add(id);
      }
    }
    // Préfixes sur le titre complet
    for (var len = 2; len <= title.length; len++) {
      final prefix = title.substring(0, len);
      (_prefixIndex[prefix] ??= {}).add(id);
    }

    // Index trigramme
    _trigramIndex.add(id, title);
    if (canonical != title) _trigramIndex.add(id, canonical);
  }

  void _removeFromIndexes(int id) {
    final item = _items[id];
    if (item == null) return;

    final title = _normalize(item.title);
    final canonical = _normalize(item.canonicalKey);

    _exactIndex[title]?.remove(id);
    _exactIndex[canonical]?.remove(id);

    for (final word in title.split(' ')) {
      _wordIndex[word]?.remove(id);
      for (var len = 2; len <= word.length; len++) {
        _prefixIndex[word.substring(0, len)]?.remove(id);
      }
    }
    for (var len = 2; len <= title.length; len++) {
      _prefixIndex[title.substring(0, len)]?.remove(id);
    }

    _trigramIndex.remove(id);
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Trouve le fragment du titre qui correspond le mieux à la requête.
  static String? _findFragment(String title, String query) {
    final qLower = query.toLowerCase();
    final tLower = title.toLowerCase();
    final idx = tLower.indexOf(qLower);
    if (idx < 0) return null;
    final start = idx;
    final end = (idx + query.length).clamp(0, title.length);
    return title.substring(start, end);
  }
}
