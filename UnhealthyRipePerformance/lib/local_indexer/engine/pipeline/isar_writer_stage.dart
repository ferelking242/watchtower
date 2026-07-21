import 'dart:async';
import 'package:isar_community/isar.dart';
import 'package:watchtower/local_indexer/cache/file_cache.dart';
import 'package:watchtower/local_indexer/engine/pipeline/analysis_stage.dart';
import 'package:watchtower/local_indexer/models/local_file_cache.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';

/// Étape 3 du pipeline : Écriture batch dans Isar + mise à jour du cache.
///
/// Principes :
///   - Accumule les résultats jusqu'à [batchSize] ou [flushInterval].
///   - Écrit tout en une seule transaction Isar (coût de write divisé par N).
///   - Met à jour le [LocalSearchEngine] en mémoire après chaque flush.
///   - Gère la déduplication : si deux fichiers ont la même episodeKey,
///     l'entrée existante est enrichie d'un `duplicateId`.
class IsarWriterStage {
  final Isar _isar;
  final FileCache _cache;
  final LocalSearchEngine _searchEngine;

  final int batchSize;
  final Duration flushInterval;

  final List<AnalysisResult> _buffer = [];
  Timer? _flushTimer;

  // Statistiques de session
  int _written = 0;
  int _skipped = 0;
  int _duplicates = 0;

  IsarWriterStage({
    required Isar isar,
    required FileCache cache,
    required LocalSearchEngine searchEngine,
    this.batchSize = 200,
    this.flushInterval = const Duration(seconds: 3),
  })  : _isar = isar,
        _cache = cache,
        _searchEngine = searchEngine;

  // ── API publique ───────────────────────────────────────────────────────────

  /// Ajoute un résultat d'analyse au buffer.
  /// Flush automatique si le buffer atteint [batchSize].
  Future<void> add(AnalysisResult result) async {
    _buffer.add(result);
    if (_buffer.length >= batchSize) await flush();
  }

  /// Ajoute un lot de résultats et flush si nécessaire.
  Future<void> addAll(List<AnalysisResult> results) async {
    _buffer.addAll(results);
    if (_buffer.length >= batchSize) await flush();
  }

  /// Démarre le timer de flush automatique.
  void startAutoFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  /// Arrête le timer et flush le buffer restant.
  Future<void> close() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }

  /// Force l'écriture immédiate du buffer dans Isar.
  Future<int> flush() async {
    if (_buffer.isEmpty) return 0;

    final toWrite = List<AnalysisResult>.from(_buffer);
    _buffer.clear();

    final now = DateTime.now().millisecondsSinceEpoch;

    // ── Construire les LocalIndexedItem ────────────────────────────────────
    final newItems = <LocalIndexedItem>[];
    final cacheEntries = <LocalFileCache>[];

    // Map canonique+episode → item pour la déduplication dans ce batch
    final episodeMap = <String, LocalIndexedItem>{};

    for (final r in toWrite) {
      final file = r.discoveredFile;

      final item = LocalIndexedItem()
        ..canonicalKey = r.canonicalKey
        ..title = r.title
        ..kind = r.kind
        ..season = r.season
        ..episode = r.episode
        ..chapter = r.chapter
        ..volume = r.volume
        ..part = r.part
        ..quality = r.quality
        ..codec = r.codec
        ..audioCodec = r.audioCodec
        ..language = r.language
        ..releaseGroup = r.releaseGroup
        ..filePath = file.path
        ..fileSize = file.size
        ..modifiedAt = file.modifiedAt
        ..mimeType = r.mimeType
        ..rawFilename = file.basename
        ..confidence = r.confidence
        ..indexedAt = now
        ..updatedAt = now;

      // Clé de déduplication : canonique + épisode précis
      final epKey = _episodeKey(r);
      if (episodeMap.containsKey(epKey)) {
        // Doublon dans ce batch → marquer
        _duplicates++;
        // On conserve quand même toutes les versions (VF vs VOSTFR, etc.)
      } else {
        episodeMap[epKey] = item;
      }

      newItems.add(item);

      // Entrée de cache
      cacheEntries.add(
        LocalFileCache()
          ..filePath = file.path
          ..fileSize = file.size
          ..modifiedAt = file.modifiedAt
          ..cachedAt = now
          ..scanCount = 1,
      );
    }

    if (newItems.isEmpty) return 0;

    // ── Écriture Isar en une seule transaction ─────────────────────────────
    await _isar.writeTxn(() async {
      // Upsert des items (put = insert or replace par filePath unique)
      await _isar.localIndexedItems.putAll(newItems);

      // Mettre à jour les IDs dans le cache
      for (var i = 0; i < cacheEntries.length; i++) {
        final itemId = newItems[i].id;
        cacheEntries[i].indexedItemId = itemId;
      }

      // Upsert du cache
      await _isar.localFileCaches.putAll(cacheEntries);
    });

    // ── Post-déduplication : relier les doublons ───────────────────────────
    await _linkDuplicates(newItems);

    // ── Mettre à jour l'index de recherche en mémoire ─────────────────────
    _searchEngine.upsertAll(newItems);

    _written += newItems.length;
    return newItems.length;
  }

  /// Statistiques de la session d'écriture courante.
  WriterStats get stats => WriterStats(
        written: _written,
        skipped: _skipped,
        duplicates: _duplicates,
      );

  // ── Privé ──────────────────────────────────────────────────────────────────

  String _episodeKey(AnalysisResult r) {
    final parts = [r.canonicalKey];
    if (r.season != null) parts.add('s${r.season}');
    if (r.episode != null) parts.add('e${r.episode}');
    if (r.chapter != null) parts.add('c${r.chapter}');
    return parts.join('_');
  }

  /// Relie les entrées doublons entre elles via [LocalIndexedItem.duplicateIds].
  Future<void> _linkDuplicates(List<LocalIndexedItem> items) async {
    // Grouper par clé canonique + épisode
    final groups = <String, List<LocalIndexedItem>>{};
    for (final item in items) {
      final key = _itemEpisodeKey(item);
      (groups[key] ??= []).add(item);
    }

    // Pour les groupes avec plusieurs éléments, relier les IDs
    final toUpdate = <LocalIndexedItem>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      final allIds = group.map((i) => i.id).toList();
      for (final item in group) {
        item.duplicateIds = allIds.where((id) => id != item.id).toList();
        toUpdate.add(item);
      }
    }

    if (toUpdate.isNotEmpty) {
      await _isar.writeTxn(() => _isar.localIndexedItems.putAll(toUpdate));
    }
  }

  String _itemEpisodeKey(LocalIndexedItem item) {
    final parts = [item.canonicalKey];
    if (item.season != null) parts.add('s${item.season}');
    if (item.episode != null) parts.add('e${item.episode}');
    if (item.chapter != null) parts.add('c${item.chapter}');
    return parts.join('_');
  }
}

class WriterStats {
  final int written;
  final int skipped;
  final int duplicates;

  const WriterStats({
    required this.written,
    required this.skipped,
    required this.duplicates,
  });

  @override
  String toString() =>
      'WriterStats(written=$written, skipped=$skipped, duplicates=$duplicates)';
}
