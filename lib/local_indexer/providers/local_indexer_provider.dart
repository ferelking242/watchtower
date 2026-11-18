import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/local_indexer/engine/indexer_engine.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/metadata/local_metadata_resolver.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/models/local_work.dart';
import 'package:watchtower/local_indexer/notifications/local_indexer_notification_service.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';
import 'package:watchtower/local_indexer/search/search_result.dart';
import 'package:watchtower/main.dart' show isar;

part 'local_indexer_provider.g.dart';

// ── Singleton : SearchEngine en mémoire ────────────────────────────────────────

/// Instance partagée du moteur de recherche en mémoire.
/// Construite une seule fois et réutilisée sur toute la session.
final _sharedSearchEngine = LocalSearchEngine();

/// Exposes the shared in-memory search engine so manual edits and renames can
/// keep it in sync with Isar without rebuilding the whole index.
final localSearchEngineProvider = Provider<LocalSearchEngine>(
  (ref) => _sharedSearchEngine,
);

// ── Provider du moteur ──────────────────────────────────────────────────────────

/// Fournit l'[IndexerEngine] initialisé.
/// Dispose automatiquement quand plus personne ne l'écoute.
@riverpod
IndexerEngine localIndexerEngine(Ref ref) {
  // A scan is started from an imperative action (`ref.read`) rather than
  // through a widget subscription. Keep the engine alive until the container
  // itself is disposed, otherwise Riverpod can dispose it while scan() is
  // awaiting filesystem or isolate work.
  ref.keepAlive();
  final engine = IndexerEngine(isar: isar, searchEngine: _sharedSearchEngine);

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

/// Phase of a Smart Library scan, from discovery through metadata enrichment.
enum SmartLibraryScanPhase {
  idle,
  discovering,
  analyzing,
  enriching,
  done,
  error,
}

/// Observable state of the current (or last) Smart Library scan.
class SmartLibraryScanState {
  final SmartLibraryScanPhase phase;
  final int discovered;
  final int processed;
  final int total;
  final int resolved;
  final int unmatched;
  final String? error;
  final bool tmdbUnavailable;

  const SmartLibraryScanState({
    this.phase = SmartLibraryScanPhase.idle,
    this.discovered = 0,
    this.processed = 0,
    this.total = 0,
    this.resolved = 0,
    this.unmatched = 0,
    this.error,
    this.tmdbUnavailable = false,
  });

  bool get isBusy =>
      phase == SmartLibraryScanPhase.discovering ||
      phase == SmartLibraryScanPhase.analyzing ||
      phase == SmartLibraryScanPhase.enriching;

  /// Analysis progress 0..1, or null when it is still unknown.
  double? get progress {
    if (total <= 0) return null;
    return (processed / total).clamp(0.0, 1.0).toDouble();
  }

  SmartLibraryScanState copyWith({
    SmartLibraryScanPhase? phase,
    int? discovered,
    int? processed,
    int? total,
    int? resolved,
    int? unmatched,
    String? error,
    bool? tmdbUnavailable,
  }) {
    return SmartLibraryScanState(
      phase: phase ?? this.phase,
      discovered: discovered ?? this.discovered,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      resolved: resolved ?? this.resolved,
      unmatched: unmatched ?? this.unmatched,
      error: error ?? this.error,
      tmdbUnavailable: tmdbUnavailable ?? this.tmdbUnavailable,
    );
  }
}

/// Drives a full Smart Library scan: indexing, live progress, metadata
/// enrichment and the system notification.
///
/// This lives in a keep-alive provider — not in the screen — so the scan keeps
/// running when the user leaves the page or backgrounds the app. Running it
/// from the widget is what caused
/// `Bad state: Using "ref" when a widget is about to or has been unmounted`,
/// because the widget's `ref`/`context` were touched after the screen closed.
@riverpod
class LocalIndexerScan extends _$LocalIndexerScan {
  StreamSubscription<IndexerStatus>? _statusSub;

  @override
  SmartLibraryScanState build() {
    // The scan is started imperatively (ref.read) and outlives the screen that
    // triggered it, so the provider must not auto-dispose mid-scan.
    ref.keepAlive();
    ref.onDispose(() => _statusSub?.cancel());
    return const SmartLibraryScanState();
  }

  /// Runs a scan over [roots] and enriches the result, mirroring progress into
  /// a system notification so it is visible with the app in the background.
  Future<void> scan(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
    Locale locale = const Locale('en'),
  }) async {
    if (state.isBusy) return;
    final notifications = LocalIndexerNotificationService.instance;
    final engine = ref.read(localIndexerEngineProvider);

    state = const SmartLibraryScanState(phase: SmartLibraryScanPhase.discovering);
    await notifications.start(mode, locale);

    IndexerStats? stats;
    _statusSub = engine.status.listen((status) {
      if (status.isDiscovering) {
        state = state.copyWith(
          phase: SmartLibraryScanPhase.discovering,
          discovered: status.discovered ?? 0,
        );
        unawaited(
          notifications.progress(
            mode,
            processed: 0,
            total: 0,
            discovered: status.discovered ?? 0,
          ),
        );
      } else if (status.isAnalyzing) {
        state = state.copyWith(
          phase: SmartLibraryScanPhase.analyzing,
          discovered: status.discovered ?? 0,
          processed: status.processed,
          total: status.total,
        );
        unawaited(
          notifications.progress(
            mode,
            processed: status.processed,
            total: status.total,
            discovered: status.discovered ?? 0,
          ),
        );
      } else if (status.isDone) {
        stats = status.stats;
      }
    });

    try {
      await engine.initialize();
      await engine.scan(roots, mode: mode);
      await engine.startWatching(roots, mode: mode);
      _invalidate();

      state = state.copyWith(phase: SmartLibraryScanPhase.enriching);
      final summary = await _enrich();

      state = state.copyWith(
        phase: SmartLibraryScanPhase.done,
        resolved: summary?.resolved ?? 0,
        unmatched: summary?.unmatched ?? 0,
        tmdbUnavailable: summary?.tmdbUnavailable ?? false,
      );
      await notifications.finish(
        mode,
        discovered: stats?.discovered ?? state.discovered,
        analyzed: stats?.analyzed ?? state.processed,
        resolved: summary?.resolved ?? 0,
        unmatched: summary?.unmatched ?? 0,
      );
    } catch (error) {
      state = state.copyWith(
        phase: SmartLibraryScanPhase.error,
        error: '$error',
      );
      await notifications.fail(mode, '$error');
    } finally {
      await _statusSub?.cancel();
      _statusSub = null;
    }
  }

  /// Refreshes the index without deleting persisted fingerprints.
  Future<void> refresh(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
    Locale locale = const Locale('en'),
  }) => scan(roots, mode: mode, locale: locale);

  /// A deliberate full verification still reuses unchanged file signatures.
  Future<void> fullRescan(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
    Locale locale = const Locale('en'),
  }) => scan(roots, mode: mode, locale: locale);

  /// Démarre la surveillance temps réel après un premier scan.
  Future<void> startWatching(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
  }) async {
    final engine = ref.read(localIndexerEngineProvider);
    await engine.startWatching(roots, mode: mode);
  }

  /// Clears the error/done banner so the next screen opening starts fresh.
  void acknowledge() {
    if (!state.isBusy) state = const SmartLibraryScanState();
  }

  void _invalidate() {
    ref.invalidate(localIndexedCountProvider);
    ref.invalidate(localIndexedCountByKindProvider);
    ref.invalidate(recentlyIndexedProvider);
    ref.invalidate(localWorksProvider);
  }

  Future<LocalMetadataEnrichmentSummary?> _enrich() async {
    try {
      final works = await ref.read(localWorksProvider.future);
      final items = [for (final work in works) work.files.first];
      final summary = await LocalMetadataResolver.instance.enrich(items);
      ref.invalidate(localWorksProvider);
      return summary;
    } catch (error) {
      debugPrint('[LocalIndexerScan] metadata enrichment failed: $error');
      return null;
    }
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
Future<List<LocalIndexedItem>> recentlyIndexed(Ref ref) async {
  return isar.localIndexedItems
      .where()
      .sortByIndexedAtDesc()
      .limit(80)
      .findAll();
}

/// Récupère un item par chemin de fichier.
@riverpod
Future<LocalIndexedItem?> localItemByPath(Ref ref, String path) async {
  return isar.localIndexedItems.where().filePathEqualTo(path).findFirst();
}

/// Regroupe l'index en « œuvres » — une entrée par clé canonique, par type et
/// par saison.
///
/// C'est la vue de la Smart Library : chaque fichier indexé devient un épisode
/// (ou un film) rattaché à son œuvre, ce qui permet d'afficher un vrai
/// catalogue (films et séries), de compter les épisodes présents et de repérer
/// les numéros manquants au lieu d'une simple liste de fichiers.
final localWorksProvider = FutureProvider<List<LocalWork>>((ref) async {
  final items = await isar.localIndexedItems.where().findAll();
  return LocalWork.group(items);
});
