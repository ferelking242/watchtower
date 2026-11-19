import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/local_indexer/cache/file_cache.dart';
import 'package:watchtower/local_indexer/engine/isolate_pool.dart';
import 'package:watchtower/local_indexer/engine/pipeline/analysis_stage.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/local_indexer/engine/pipeline/isar_writer_stage.dart';
import 'package:watchtower/local_indexer/engine/watcher/android_media_store.dart';
import 'package:watchtower/local_indexer/engine/watcher/fs_watcher.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';

/// Résultat d'une requête MediaStore : les fichiers trouvés et si l'index
/// système peut être considéré comme complet pour ce mode.
class _MediaStoreQueryResult {
  final List<DiscoveredFile> files;
  final bool complete;
  const _MediaStoreQueryResult(this.files, {required this.complete});
}

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

  late DiscoveryStage _discovery;
  late final IsarWriterStage _writer;
  late final IsolatePool _pool;
  FsWatcher? _watcher;

  bool _initialized = false;
  bool _scanning = false;
  LocalScanMode _activeMode = LocalScanMode.videos;

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

    // Construire le pool d'isolates pour l'analyse parallèle.
    //
    // Name analysis is pure CPU work on a small payload, so one worker per
    // logical core is enough; more workers only add context-switch overhead.
    // Clamped so a low-end phone still gets parallelism and a 16-core desktop
    // does not spawn dozens of isolates for nothing.
    final cores = Platform.numberOfProcessors;
    _pool = await IsolatePool.create(
      entryPoint: AnalysisStage.isolateEntryPoint,
      maxWorkers: (cores - 1).clamp(2, 8),
    );

    _discovery = DiscoveryStage(
      batchSize: 300,
      policy: ScanPolicy.videos(),
    );

    _writer = IsarWriterStage(
      isar: _isar,
      cache: _cache,
      searchEngine: searchEngine,
      batchSize: 200,
    );

    // Charger l'index existant depuis Isar dans le SearchEngine en mémoire
    await _loadExistingIndex();

    _initialized = true;
    _emit(const IndexerStatus.idle());
  }

  // ── Scan ────────────────────────────────────────────────────────────────────

  /// Lance un scan complet des dossiers [roots].
  ///
  /// Grâce au cache intelligent, les fichiers non modifiés sont ignorés.
  /// Seuls les nouveaux fichiers ou les fichiers modifiés sont analysés.
  Future<IndexerStats> scan(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
  }) async {
    if (!_initialized) await initialize();
    if (_scanning) return IndexerStats.empty();
    _scanning = true;
    final policy = switch (mode) {
      LocalScanMode.manga => const ScanPolicy.manga(),
      LocalScanMode.music => const ScanPolicy.music(),
      LocalScanMode.videos => ScanPolicy.videos(),
    };
    _discovery = DiscoveryStage(batchSize: 300, policy: policy);
    _activeMode = mode;

    final stopwatch = Stopwatch()..start();
    int discovered = 0, cached = 0, analyzed = 0;

    _emit(const IndexerStatus.scanning(0, 0, phase: IndexerPhase.discovering));

    try {
      _writer.startAutoFlush();

      // ── 1. Découverte ──────────────────────────────────────────────────────
      // On Android, MediaStore est la source de vérité : le système a déjà
      // indexé chaque vidéo/audio au moment où le fichier a été créé. VLC,
      // PlayIt et consorts ne font rien d'autre — c'est ce qui leur permet de
      // lister des milliers de fichiers en quelques secondes. La marche
      // récursive du stockage partagé, elle, doit ouvrir chaque dossier et
      // stat-er chaque entrée : sur /storage/emulated/0 elle prend des
      // dizaines de minutes (Android/data, obb, caches d'applications…).
      //
      // MediaStore est donc utilisé seul quand il répond, et la marche FS ne
      // sert que de repli (permission refusée, bridge absent, desktop/iOS) ou
      // de complément pour les formats que MediaStore n'indexe pas (.cbz…).
      final mediaStore = await _queryMediaStore(mode);
      final allFiles = <DiscoveredFile>[];
      if (mediaStore != null) {
        allFiles.addAll(mediaStore.files);
        discovered = allFiles.length;
        _emit(IndexerStatus.scanning(
          discovered,
          0,
          total: discovered,
          phase: IndexerPhase.discovering,
        ));
      }

      final needsWalk = mediaStore == null ||
          !mediaStore.complete ||
          mode == LocalScanMode.manga;
      if (needsWalk) {
        // Formats non indexés par MediaStore : seule la marche FS les trouve.
        final walkRoots = mediaStore == null
            ? roots
            : _supplementaryRoots(roots, mode);
        await for (final batch in _discovery.discover(
          walkRoots,
          additionalFiles: const [],
        )) {
          allFiles.addAll(batch);
          discovered = allFiles.length;
          _emit(IndexerStatus.scanning(
            discovered,
            0,
            total: discovered,
            phase: IndexerPhase.discovering,
          ));
        }
      }

      // MediaStore rows and the FS walk can point at the same file; keep the
      // first occurrence so a film is not indexed twice.
      final seenPaths = <String>{};
      final uniqueFiles = <DiscoveredFile>[
        for (final file in allFiles)
          if (seenPaths.add(file.path)) file,
      ];
      allFiles
        ..clear()
        ..addAll(uniqueFiles);

      // ── 2 + 3 + 4. Cache, analyse parallèle, écriture batch ────────────────
      final total = allFiles.length;
      const chunkSize = 400;
      for (var start = 0; start < total; start += chunkSize) {
        final end = (start + chunkSize > total) ? total : start + chunkSize;
        final chunk = allFiles.sublist(start, end);

        // Batch cache check: one Isar query for the whole chunk instead of one
        // awaited query per file.
        final unchanged = await _cache.unchangedPaths(
          paths: [for (final f in chunk) f.path],
          sizes: [for (final f in chunk) f.size],
          modifiedAts: [for (final f in chunk) f.modifiedAt],
        );

        final toAnalyze = <DiscoveredFile>[];
        for (final file in chunk) {
          if (unchanged.contains(file.path)) {
            cached++;
          } else {
            toAnalyze.add(file);
          }
        }

        if (toAnalyze.isNotEmpty) {
          final analysisResults = await _analyzeParallel(toAnalyze);
          analyzed += analysisResults.length;
          await _writer.addAll(analysisResults);
        }

        _emit(IndexerStatus.scanning(
          discovered,
          analyzed,
          processed: cached + analyzed,
          total: total,
          phase: IndexerPhase.analyzing,
        ));
      }

      // Flush final
      await _writer.close();

      // Purge des orphelins du cache (fichiers supprimés)
      final orphans = await _cache.purgeOrphans(
        extensions: policy.allowedExtensions,
      );
      final missingIndexed = await _removeMissingIndexedItems(
        roots,
        extensions: policy.allowedExtensions,
      );

      stopwatch.stop();
      final stats = IndexerStats(
        discovered: discovered,
        cached: cached,
        analyzed: analyzed,
        orphansPurged: orphans + missingIndexed,
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
  Future<void> startWatching(
    List<String> roots, {
    LocalScanMode mode = LocalScanMode.videos,
  }) async {
    if (!_initialized) await initialize();
    await stopWatching();

    final watcher = FsWatcher(
      roots,
      mode: mode,
    );
    _watcher = watcher;
    await watcher.start();

    _watcherSub = watcher.events.listen(
      _handleFsEvent,
      onError: (e) => _emit(IndexerStatus.error('Watcher error: $e')),
    );
  }

  /// Arrête la surveillance FS.
  Future<void> stopWatching() async {
    await _watcherSub?.cancel();
    _watcherSub = null;
    await _watcher?.dispose();
    _watcher = null;
  }

  // ── Nettoyage ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopWatching();
    if (_initialized) await _pool.dispose();
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
          'analysisName': file.analysisName,
        }));

    final maps = await Future.wait(futures);
    return [
      for (var i = 0; i < files.length; i++)
        AnalysisStage.fromMap(maps[i], files[i]),
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

    late final FileStat stat;
    try {
      stat = file.statSync();
    } catch (_) {
      return;
    }
    final discovered = DiscoveredFile(
      path: path,
      size: stat.size,
      modifiedAt: stat.modified.millisecondsSinceEpoch,
      extension: _ext(path),
      analysisName: _activeMode == LocalScanMode.manga &&
              (DiscoveryStage.mangaPageExtensions.contains(_ext(path)) ||
                  DiscoveryStage.mangaArchiveExtensions.contains(_ext(path)))
          ? DiscoveryStage.mangaAnalysisName(path)
          : null,
    );
    if (_activeMode == LocalScanMode.manga &&
        DiscoveryStage.mangaPageExtensions.contains(_ext(path)) &&
        !DiscoveryStage.isLikelyMangaPath(path)) {
      return;
    }
    // The same quality gate the full scan applies, so a file dropped by the
    // scan is not silently re-added by the live watcher.
    final activePolicy = switch (_activeMode) {
      LocalScanMode.manga => const ScanPolicy.manga(),
      LocalScanMode.music => const ScanPolicy.music(),
      LocalScanMode.videos => ScanPolicy.videos(),
    };
    if (stat.size < activePolicy.minimumFileSize ||
        activePolicy.rejectsName(discovered.basename)) {
      return;
    }

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

  Future<int> _removeMissingIndexedItems(
    List<String> roots, {
    required Set<String> extensions,
  }) async {
    final items = await _isar.localIndexedItems.where().findAll();
    final normalizedRoots = roots.map(_normalizeRoot).toList();
    final candidates = <LocalIndexedItem>[];
    for (final item in items) {
      // MediaStore entries can be content:// URIs (Android 10+); File() can
      // never resolve those, so they would look deleted on every scan.
      if (item.filePath.startsWith('content://')) continue;
      final path = _normalizeRoot(item.filePath);
      final belongsToScan = normalizedRoots.any(
        (root) => path == root || path.startsWith('$root/'),
      );
      if (belongsToScan && extensions.contains(_ext(item.filePath))) {
        candidates.add(item);
      }
    }
    if (candidates.isEmpty) return 0;

    // Await each existence check: a synchronous existsSync per indexed item
    // blocked the UI isolate for the whole library and Android killed the app
    // before the scan could finish.
    final missing = <LocalIndexedItem>[];
    for (final item in candidates) {
      if (!await File(item.filePath).exists()) missing.add(item);
    }
    if (missing.isEmpty) return 0;

    await _isar.writeTxn(() async {
      await _isar.localIndexedItems.deleteAll(missing.map((item) => item.id).toList());
    });
    for (final item in missing) {
      searchEngine.remove(item.id);
    }
    return missing.length;
  }

  String _normalizeRoot(String value) =>
      value.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i >= 0 ? path.substring(i).toLowerCase() : '';
  }

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  /// Extension of a MediaStore entry.
  ///
  /// Android 10+ hides the absolute path, so [MediaStoreEntry.path] is a
  /// `content://` URI ending in the numeric row id and [_ext] returns `''`.
  /// The discovery stage drops every file whose extension is not in the
  /// allow-list, so such entries were silently discarded and the scan found
  /// nothing. [AndroidMediaStore.extensionOf] resolves the real extension from
  /// the display name or MIME type instead.
  String _mediaStoreExtension(MediaStoreEntry entry) =>
      AndroidMediaStore.extensionOf(entry);

  /// Interroge MediaStore pour [mode].
  ///
  /// Retourne `null` quand MediaStore n'est pas exploitable (plateforme non
  /// Android, bridge absent, permission refusée) : l'appelant retombe alors
  /// sur la marche FS. [complete] indique si l'index système couvre tout ce que
  /// le mode recherche ; sinon la marche FS vient en complément.
  Future<_MediaStoreQueryResult?> _queryMediaStore(LocalScanMode mode) async {
    if (!AndroidMediaStore.isAvailable) return null;
    final policy = switch (mode) {
      LocalScanMode.manga => const ScanPolicy.manga(),
      LocalScanMode.music => const ScanPolicy.music(),
      LocalScanMode.videos => ScanPolicy.videos(),
    };
    try {
      final entries = switch (mode) {
        LocalScanMode.music => await AndroidMediaStore.queryAudio(),
        // MediaStore n'indexe pas les archives manga ni les pages d'un
        // dossier ; la marche FS reste la seule source pour ce mode.
        LocalScanMode.manga => const <MediaStoreEntry>[],
        LocalScanMode.videos => await AndroidMediaStore.queryVideos(),
      };
      final files = <DiscoveredFile>[];
      for (final entry in entries) {
        final extension = _mediaStoreExtension(entry);
        // Same gates as the FS walk: MediaStore returns thumbnails, ringtones
        // and screen recordings too, and they are not films or tracks.
        if (entry.size < policy.minimumFileSize) continue;
        if (policy.minimumDurationMs > 0 &&
            entry.duration != null &&
            entry.duration! < policy.minimumDurationMs) {
          continue;
        }
        // rejectsName expects a basename: passing a full path made the
        // "sample"/"trailer" checks depend on the parent folder name.
        if (policy.rejectsName(
          _basename(entry.displayName ?? entry.path),
        )) {
          continue;
        }
        files.add(DiscoveredFile(
          path: entry.path,
          size: entry.size,
          modifiedAt: entry.modifiedAt,
          extension: extension,
          // Android 10+ may expose the file as a content:// URI whose last
          // path segment is the numeric MediaStore id. Analysing that would
          // title every entry "1234", so the real filename stands in — but
          // only there: for a real path the full path still drives the
          // /Anime/ folder classification.
          analysisName:
              entry.path.startsWith('content://') ? entry.displayName : null,
          durationMs: entry.duration,
        ));
      }
      return _MediaStoreQueryResult(
        files,
        // An empty answer is ambiguous: it can mean "no media on the device"
        // or "the media permission was denied and MediaStore silently
        // returned nothing". Treating it as complete would show an empty
        // library with no fallback, so the FS walk still runs in that case.
        complete: mode != LocalScanMode.manga && files.isNotEmpty,
      );
    } on MediaStoreException {
      // Permission refusée ou bridge indisponible : repli sur la marche FS.
      return null;
    }
  }

  /// Racines à parcourir quand MediaStore fournit déjà les vidéos/audio.
  ///
  /// Seuls les dossiers qui peuvent contenir des formats absents de l'index
  /// système sont visités — et seulement ceux qui existent réellement, ce qui
  /// évite de relancer la marche coûteuse de tout `/storage/emulated/0`.
  List<String> _supplementaryRoots(List<String> roots, LocalScanMode mode) {
    if (mode != LocalScanMode.manga) return const [];
    return roots;
  }

  void _emit(IndexerStatus status) {
    _lastStatus = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}

// ── Statuts ────────────────────────────────────────────────────────────────────

enum IndexerStatusType { idle, scanning, done, error }

/// Which half of the scan is currently running.
///
/// The pipeline is two-phase now: it first walks the storage to collect every
/// candidate file, then analyses them. Discovery has no reliable denominator
/// (it is still counting), while analysis does — hence the distinction, so the
/// UI can show a spinner then a real percentage.
enum IndexerPhase { idle, discovering, analyzing }

class IndexerStatus {
  final IndexerStatusType type;
  final int? discovered;
  final int? analyzed;
  final String? errorMessage;
  final IndexerStats? stats;
  final IndexerPhase phase;

  /// Files already handled in the analysis phase (indexed + served from cache).
  final int processed;

  /// Total files the analysis phase must process. 0 while discovering.
  final int total;

  const IndexerStatus._({
    required this.type,
    this.discovered,
    this.analyzed,
    this.errorMessage,
    this.stats,
    this.phase = IndexerPhase.idle,
    this.processed = 0,
    this.total = 0,
  });

  const IndexerStatus.idle() : this._(type: IndexerStatusType.idle);

  const IndexerStatus.scanning(
    int discovered,
    int analyzed, {
    int processed = 0,
    int total = 0,
    IndexerPhase phase = IndexerPhase.analyzing,
  }) : this._(
          type: IndexerStatusType.scanning,
          discovered: discovered,
          analyzed: analyzed,
          processed: processed,
          total: total,
          phase: phase,
        );

  const IndexerStatus.done(IndexerStats stats)
      : this._(type: IndexerStatusType.done, stats: stats);

  const IndexerStatus.error(String message)
      : this._(type: IndexerStatusType.error, errorMessage: message);

  bool get isScanning => type == IndexerStatusType.scanning;
  bool get isDone => type == IndexerStatusType.done;
  bool get isError => type == IndexerStatusType.error;
  bool get isIdle => type == IndexerStatusType.idle;

  bool get isDiscovering => isScanning && phase == IndexerPhase.discovering;
  bool get isAnalyzing => isScanning && phase == IndexerPhase.analyzing;

  /// Analysis progress in the range 0..1, or null while it is still unknown
  /// (discovery, or a total of zero).
  double? get progress {
    if (!isAnalyzing || total <= 0) return null;
    return (processed / total).clamp(0.0, 1.0).toDouble();
  }
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
