import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/local_indexer/cache/file_cache.dart';
import 'package:watchtower/local_indexer/engine/isolate_pool.dart';
import 'package:watchtower/local_indexer/engine/pipeline/analysis_stage.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/engine/pipeline/isar_writer_stage.dart';
import 'package:watchtower/local_indexer/engine/watcher/fs_watcher.dart';
import 'package:watchtower/local_indexer/models/local_file_cache.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';

/// Moteur principal du Local Indexer.
///
/// Orchestre l'ensemble du pipeline :
///   1. Découverte des fichiers (DiscoveryStage)
///   2. Filtrage via cache (FileCache) — skip les fichiers inchangés
///   3. Analyse en parallèle (IsolatePool + AnalysisStage)
///   4. Normalisation + écriture batch (IsarWriterStage)
///   5. Surveillance en temps réel (FsWatcher) → mise à jour incrémentale
///
/// Principes :
///   - Premier scan complet → toutes les entrées en mémoire + Isar.
///   - Scans suivants → seuls les fichiers nouveaux/modifiés sont traités.
///   - Modifications en direct → FsWatcher déclenche une ré-analyse ciblée.
class IndexerEngine {
  final Isar _isar;
  final LocalSearchEngine searchEngine;
  final FileCache _cache;

  late final DiscoveryStage _discovery;
  late final IsarWriterStage _writer;
  late final IsolatePool _pool;
  late final FsWatcher _watcher;

  bool _initialized = false;
  bool _scanning = false;

  final _statusController = StreamController<IndexerStatus>.broadcast();
  StreamSubscription? _watcherSub;

  // Statistiques courantes
  IndexerStatus _lastStatus = const IndexerStatus.idle();

  IndexerEngine({required Isar isar, required LocalSearchEngine searchEngine})
      : _isar = isar,
        searchEngine = searchEngine,
        _cache = FileCache(isar);

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Initialise le moteur : pool d'isolates + chargement de l'index existant.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Construire le pool d'isolates pour l'analyse parallèle
    _pool = await IsolatePool.create(
      entryPoint: AnalysisStage.isolateEntryPoint,
    );

    _discovery = const DiscoveryStage(batchSize: 300);

    _writer = IsarWriterStage(
      isar: _isar,
      cache: _cache,
      searchEngine: searchEngine,
      batchSize: 200,
    );

    // Charger l'index existant depuis Isar dans le SearchEngine en mémoire
    await _loadExistingIndex();

    _emit(const IndexerStatus.idle());
  }

  // ── Scan ────────────────────────────────────────────────────────────────────

  /// Lance un scan complet des dossiers [roots].
  ///
  /// Grâce au cache intelligent, les fichiers non modifiés sont ignorés.
  /// Seuls les nouveaux fichiers ou les fichiers modifiés sont analysés.
  Future<IndexerStats> scan(List<String> roots) async {
    if (!_initialized) await initialize();
    if (_scanning) return IndexerStats.empty();
    _scanning = true;

    final stopwatch = Stopwatch()..start();
    int discovered = 0, cached = 0, analyzed = 0;

    _emit(IndexerStatus.scanning(0, roots.length));

    try {
      _writer.startAutoFlush();

      // ── 1. Découverte ──────────────────────────────────────────────────────
      await for (final batch in _discovery.discover(roots)) {
        discovered += batch.length;
        _emit(IndexerStatus.scanning(discovered, 0));

        // ── 2. Filtrage cache ──────────────────────────────────────────────
        final toAnalyze = <DiscoveredFile>[];

        for (final file in batch) {
          final f = File(file.path);
          final cached_ = await _cache.check(f);
          if (cached_ != null) {
            cached++;
          } else {
            toAnalyze.add(file);
          }
        }

        if (toAnalyze.isEmpty) continue;

        // ── 3. Analyse parallèle via pool d'isolates ───────────────────────
        final analysisResults = await _analyzeParallel(toAnalyze);
        analyzed += analysisResults.length;

        // ── 4. Écriture batch ──────────────────────────────────────────────
        await _writer.addAll(analysisResults);

        _emit(IndexerStatus.scanning(discovered, analyzed));
      }

      // Flush final
      await _writer.close();

      // Purge des orphelins du cache (fichiers supprimés)
      final orphans = await _cache.purgeOrphans();

      stopwatch.stop();
      final stats = IndexerStats(
        discovered: discovered,
        cached: cached,
        analyzed: analyzed,
        orphansPurged: orphans,
        duration: stopwatch.elapsed,
        writerStats: _writer.stats,
      );

      _emit(IndexerStatus.done(stats));
      return stats;
    } catch (e) {
      _emit(IndexerStatus.error(e.toString()));
      rethrow;
    } finally {
      _scanning = false;
    }
  }

  // ── Surveillance temps réel ─────────────────────────────────────────────────

  /// Démarre la surveillance FS sur [roots].
  ///
  /// Chaque événement (create/modify/delete) déclenche une mise à jour
  /// ciblée de l'index — sans rescanner tout le disque.
  Future<void> startWatching(List<String> roots) async {
    if (!_initialized) await initialize();

    _watcher = FsWatcher(roots);
    await _watcher.start();

    _watcherSub = _watcher.events.listen(
      _handleFsEvent,
      onError: (e) => _emit(IndexerStatus.error('Watcher error: $e')),
    );
  }

  /// Arrête la surveillance FS.
  Future<void> stopWatching() async {
    await _watcherSub?.cancel();
    _watcherSub = null;
    await _watcher.dispose();
  }

  // ── Nettoyage ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopWatching();
    await _pool.dispose();
    await _statusController.close();
  }

  // ── Stream d'état ───────────────────────────────────────────────────────────

  /// Stream des mises à jour de statut (scanning, done, error, idle).
  Stream<IndexerStatus> get status => _statusController.stream;

  IndexerStatus get currentStatus => _lastStatus;

  // ── Internals ───────────────────────────────────────────────────────────────

  Future<void> _loadExistingIndex() async {
    // Charger par pages pour éviter de tout charger en RAM d'un coup
    const pageSize = 1000;
    int offset = 0;

    while (true) {
      final page = await _isar.localIndexedItems
          .where()
          .offset(offset)
          .limit(pageSize)
          .findAll();

      if (page.isEmpty) break;
      searchEngine.upsertAll(page);
      offset += page.length;
      if (page.length < pageSize) break;
    }
  }

  Future<List<AnalysisResult>> _analyzeParallel(
      List<DiscoveredFile> files) async {
    // Pour les petits lots, rester en process (évite la sérialisation)
    if (files.length <= 20 || _pool.workerCount == 0) {
      return files.map(AnalysisStage.analyzeSync).toList();
    }

    // Distribuer sur le pool d'isolates
    final futures = files.map((file) => _pool.submit<Map<String, dynamic>>({
          'path': file.path,
          'size': file.size,
          'modifiedAt': file.modifiedAt,
          'extension': file.extension,
        }));

    final maps = await Future.wait(futures);
    return [
      for (var i = 0; i < files.length; i++)
        AnalysisResult.fromMap(maps[i], files[i]),
    ];
  }

  Future<void> _handleFsEvent(FsEvent event) async {
    switch (event.type) {
      case FsEventType.created:
      case FsEventType.modified:
        await _reindexFile(event.path);

      case FsEventType.deleted:
        await _removeFile(event.path);

      case FsEventType.moved:
        await _removeFile(event.path);
        if (event.destPath != null) await _reindexFile(event.destPath!);
    }
  }

  Future<void> _reindexFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final stat = file.statSync();
    final discovered = DiscoveredFile(
      path: path,
      size: stat.size,
      modifiedAt: stat.modified.millisecondsSinceEpoch,
      extension: _ext(path),
    );

    final result = AnalysisStage.analyzeSync(discovered);
    await _writer.add(result);
    await _writer.flush();
  }

  Future<void> _removeFile(String path) async {
    // Supprimer de l'index Isar
    await _isar.writeTxn(() async {
      final item = await _isar.localIndexedItems
          .where()
          .filePathEqualTo(path)
          .findFirst();
      if (item != null) {
        await _isar.localIndexedItems.delete(item.id);
        searchEngine.remove(item.id);
      }
    });
    await _cache.evict(path);
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i >= 0 ? path.substring(i).toLowerCase() : '';
  }

  void _emit(IndexerStatus status) {
    _lastStatus = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}

// ── Statuts ────────────────────────────────────────────────────────────────────

enum IndexerStatusType { idle, scanning, done, error }

class IndexerStatus {
  final IndexerStatusType type;
  final int? discovered;
  final int? analyzed;
  final String? errorMessage;
  final IndexerStats? stats;

  const IndexerStatus._({
    required this.type,
    this.discovered,
    this.analyzed,
    this.errorMessage,
    this.stats,
  });

  const IndexerStatus.idle() : this._(type: IndexerStatusType.idle);

  const IndexerStatus.scanning(int discovered, int analyzed)
      : this._(
          type: IndexerStatusType.scanning,
          discovered: discovered,
          analyzed: analyzed,
        );

  const IndexerStatus.done(IndexerStats stats)
      : this._(type: IndexerStatusType.done, stats: stats);

  const IndexerStatus.error(String message)
      : this._(type: IndexerStatusType.error, errorMessage: message);

  bool get isScanning => type == IndexerStatusType.scanning;
  bool get isDone => type == IndexerStatusType.done;
  bool get isError => type == IndexerStatusType.error;
  bool get isIdle => type == IndexerStatusType.idle;
}

// ── Statistiques ──────────────────────────────────────────────────────────────

class IndexerStats {
  final int discovered;
  final int cached;
  final int analyzed;
  final int orphansPurged;
  final Duration duration;
  final WriterStats writerStats;

  const IndexerStats({
    required this.discovered,
    required this.cached,
    required this.analyzed,
    required this.orphansPurged,
    required this.duration,
    required this.writerStats,
  });

  factory IndexerStats.empty() => IndexerStats(
        discovered: 0,
        cached: 0,
        analyzed: 0,
        orphansPurged: 0,
        duration: Duration.zero,
        writerStats: const WriterStats(written: 0, skipped: 0, duplicates: 0),
      );

  @override
  String toString() =>
      'IndexerStats('
      'discovered=$discovered, '
      'cached=$cached, '
      'analyzed=$analyzed, '
      'orphans=$orphansPurged, '
      'duration=${duration.inMilliseconds}ms, '
      'writer=$writerStats'
      ')';
}
