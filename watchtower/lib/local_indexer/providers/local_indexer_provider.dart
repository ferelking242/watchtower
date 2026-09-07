import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/local_indexer/engine/indexer_engine.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';
import 'package:watchtower/local_indexer/search/search_result.dart';
import 'package:watchtower/main.dart' show isar;

part 'local_indexer_provider.g.dart';

// ── Singleton : SearchEngine en mémoire ────────────────────────────────────────

/// Instance partagée du moteur de recherche en mémoire.
/// Construite une seule fois et réutilisée sur toute la session.
final _sharedSearchEngine = LocalSearchEngine();

// ── Provider du moteur ──────────────────────────────────────────────────────────

/// Fournit l'[IndexerEngine] initialisé.
/// Dispose automatiquement quand plus personne ne l'écoute.
@riverpod
IndexerEngine localIndexerEngine(Ref ref) {
  final engine = IndexerEngine(
    isar: isar,
    searchEngine: _sharedSearchEngine,
  );

  ref.onDispose(() => engine.dispose());
  return engine;
}

// ── Provider de statut ──────────────────────────────────────────────────────────

/// Stream du statut courant de l'indexeur.
@riverpod
Stream<IndexerStatus> indexerStatus(Ref ref) {
  final engine = ref.watch(localIndexerEngineProvider);
  return engine.status;
}

// ── Provider de scan ───────────────────────────────────────────────────────────

/// Lance ou recharge un scan sur les dossiers donnés.
@riverpod
class LocalIndexerScan extends _$LocalIndexerScan {
  @override
  AsyncValue<IndexerStats?> build() => const AsyncValue.data(null);

  /// Démarre un scan sur [roots].
  Future<void> scan(List<String> roots) async {
    state = const AsyncValue.loading();
    final engine = ref.read(localIndexerEngineProvider);
    try {
      await engine.initialize();
      final stats = await engine.scan(roots);
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Démarre la surveillance temps réel après un premier scan.
  Future<void> startWatching(List<String> roots) async {
    final engine = ref.read(localIndexerEngineProvider);
    await engine.startWatching(roots);
  }
}

// ── Provider de recherche ──────────────────────────────────────────────────────

/// Provider de résultats de recherche — réactif à la saisie.
///
/// Usage :
/// ```dart
/// final results = ref.watch(localSearchProvider('naruto'));
/// ```
@riverpod
List<LocalSearchResult> localSearch(Ref ref, String query) {
  if (query.trim().isEmpty) return [];
  return _sharedSearchEngine.search(query, limit: 50);
}

/// Retourne tous les items d'un type de média donné.
@riverpod
List<LocalIndexedItem> localItemsByKind(Ref ref, LocalMediaKind kind) {
  return _sharedSearchEngine.getByKind(kind);
}

/// Retourne toutes les variantes d'une œuvre (même clé canonique).
@riverpod
List<LocalIndexedItem> localItemVariants(Ref ref, String canonicalKey) {
  return _sharedSearchEngine.getVariants(canonicalKey);
}

// ── Provider de comptage ───────────────────────────────────────────────────────

/// Nombre total d'items indexés (depuis Isar).
@riverpod
Future<int> localIndexedCount(Ref ref) async {
  return isar.localIndexedItems.count();
}

/// Nombre d'items par type de média (depuis Isar).
@riverpod
Future<Map<LocalMediaKind, int>> localIndexedCountByKind(Ref ref) async {
  final all = await isar.localIndexedItems.where().findAll();
  final result = <LocalMediaKind, int>{};
  for (final item in all) {
    result[item.kind] = (result[item.kind] ?? 0) + 1;
  }
  return result;
}

// ── Provider de requête Isar directe ──────────────────────────────────────────

/// Récupère les items récemment indexés (triés par date d'indexation).
@riverpod
Future<List<LocalIndexedItem>> recentlyIndexed(
  Ref ref, {
  int limit = 20,
}) async {
  return isar.localIndexedItems
      .where()
      .sortByIndexedAtDesc()
      .limit(limit)
      .findAll();
}

/// Récupère un item par chemin de fichier.
@riverpod
Future<LocalIndexedItem?> localItemByPath(Ref ref, String path) async {
  return isar.localIndexedItems
      .where()
      .filePathEqualTo(path)
      .findFirst();
}
