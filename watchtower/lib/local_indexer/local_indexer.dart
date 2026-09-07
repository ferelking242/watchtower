/// Local Indexer — Moteur d'indexation local de Watchtower.
///
/// Ce module transforme automatiquement tout le stockage local de l'appareil
/// en une bibliothèque organisée (Anime, Séries, Films, Manga, Novels).
///
/// ## Architecture
///
/// ```
/// local_indexer/
/// ├── models/
/// │   ├── local_indexed_item.dart   ← Isar collection : item indexé
/// │   └── local_file_cache.dart     ← Isar collection : cache fichier
/// ├── normalizer/
/// │   ├── tokenizer.dart            ← Étape 1 : tokenisation du nom
/// │   ├── noise_remover.dart        ← Étape 3 : suppression tags de release
/// │   ├── episode_detector.dart     ← Étape 5 : S/E/Chapitre/Volume
/// │   ├── quality_detector.dart     ← Étape 7+8 : résolution, codec
/// │   ├── language_detector.dart    ← Étape 6 : VOSTFR, VF, EN…
/// │   ├── canonical_key.dart        ← Clé canonique de regroupement
/// │   └── name_normalizer.dart      ← Orchestrateur du pipeline
/// ├── search/
/// │   ├── trigram_index.dart        ← Index trigramme (recherche floue)
/// │   ├── search_engine.dart        ← Moteur multi-index en mémoire
/// │   └── search_result.dart        ← Modèle de résultat
/// ├── cache/
/// │   └── file_cache.dart           ← Cache intelligent (RAM + Isar)
/// ├── engine/
/// │   ├── isolate_pool.dart         ← Pool d'isolates dynamique
/// │   ├── pipeline/
/// │   │   ├── discovery_stage.dart  ← Découverte des fichiers
/// │   │   ├── analysis_stage.dart   ← Analyse en isolate
/// │   │   └── isar_writer_stage.dart← Écriture batch + déduplication
/// │   └── watcher/
/// │       ├── fs_watcher.dart       ← Surveillance FS native
/// │       └── android_media_store.dart ← Android MediaStore bridge
/// └── providers/
///     └── local_indexer_provider.dart ← Riverpod providers
/// ```
///
/// ## Utilisation rapide
///
/// ```dart
/// // Dans un widget Riverpod :
///
/// // 1. Lancer un scan
/// ref.read(localIndexerScanProvider.notifier).scan([
///   '/storage/emulated/0/Watchtower',
///   '/storage/emulated/0/Movies',
/// ]);
///
/// // 2. Observer le statut
/// final status = ref.watch(indexerStatusProvider);
///
/// // 3. Rechercher
/// final results = ref.watch(localSearchProvider('naruto'));
///
/// // 4. Lister par type
/// final animes = ref.watch(localItemsByKindProvider(LocalMediaKind.anime));
/// ```
///
/// ## Principes de performance
///
/// - **Cache intelligent** : signature (taille + mtime) évite tout rescan.
/// - **Isolate pool** : analyse répartie sur tous les cœurs CPU.
/// - **Pipeline** : découverte → analyse → normalisation → écriture batch.
/// - **Index en mémoire** : recherche O(1) par exact, O(k) par préfixe,
///   O(n·trigrams) pour le flou — jamais de scan Isar à la volée.
/// - **Surveillance FS** : inotify/FSEvents/Windows ReadDirectoryChangesW
///   pour des mises à jour en temps réel sans rescan.

// Exports publics du module
export 'models/local_indexed_item.dart';
export 'models/local_file_cache.dart';
export 'normalizer/name_normalizer.dart' show NameNormalizer, NormalizeResult;
export 'normalizer/canonical_key.dart' show CanonicalKey;
export 'search/search_engine.dart' show LocalSearchEngine;
export 'search/search_result.dart' show LocalSearchResult, MatchType;
export 'cache/file_cache.dart' show FileCache, CacheStats;
export 'engine/indexer_engine.dart'
    show IndexerEngine, IndexerStatus, IndexerStats;
export 'engine/pipeline/discovery_stage.dart'
    show DiscoveryStage, DiscoveredFile, FileCategory;
export 'engine/watcher/fs_watcher.dart' show FsWatcher, FsEvent, FsEventType;
export 'engine/watcher/android_media_store.dart'
    show AndroidMediaStore, MediaStoreEntry;
export 'providers/local_indexer_provider.dart';
