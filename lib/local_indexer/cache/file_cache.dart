import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/local_indexer/models/local_file_cache.dart';

/// Gestionnaire du cache de fichiers.
///
/// Le cache évite de rescanner un fichier dont la taille et la date de
/// modification n'ont pas changé depuis le dernier index.
///
/// Architecture :
///   - Tier 1 (RAM) : LRU map des entrées récentes (accès O(1))
///   - Tier 2 (Isar) : persistance complète sur disque
class FileCache {
  final Isar _isar;

  // Cache LRU en mémoire (capacité fixe)
  static const _ramCapacity = 50000;
  final _ramCache = <String, LocalFileCache>{};
  final _accessOrder = <String>[];

  FileCache(this._isar);

  // ── API publique ───────────────────────────────────────────────────────────

  /// Vérifie si un fichier est déjà dans le cache et non modifié.
  ///
  /// Retourne l'entrée de cache si le fichier n'a pas changé, `null` sinon.
  Future<LocalFileCache?> check(File file) async {
    final path = file.path;
    final stat = await file.stat();
    final currentSize = stat.size;
    final currentMtime = stat.modified.millisecondsSinceEpoch;

    // Tier 1 : RAM
    final ram = _ramCache[path];
    if (ram != null && ram.isUnchanged(currentSize, currentMtime)) {
      _touch(path);
      return ram;
    }

    // Tier 2 : Isar
    final db = await _isar.localFileCaches
        .where()
        .filePathEqualTo(path)
        .findFirst();

    if (db != null && db.isUnchanged(currentSize, currentMtime)) {
      _putRam(path, db);
      return db;
    }

    return null; // fichier nouveau ou modifié
  }

  /// Enregistre ou met à jour une entrée de cache.
  Future<void> put(LocalFileCache entry) async {
    await _isar.writeTxn(() => _isar.localFileCaches.put(entry));
    _putRam(entry.filePath, entry);
  }

  /// Enregistre un lot d'entrées en une seule transaction.
  Future<void> putBatch(List<LocalFileCache> entries) async {
    await _isar.writeTxn(() => _isar.localFileCaches.putAll(entries));
    for (final e in entries) {
      _putRam(e.filePath, e);
    }
  }

  /// Supprime une entrée du cache (fichier supprimé du disque).
  Future<void> evict(String path) async {
    _ramCache.remove(path);
    _accessOrder.remove(path);
    await _isar.writeTxn(() async {
      final entry = await _isar.localFileCaches
          .where()
          .filePathEqualTo(path)
          .findFirst();
      if (entry?.id != null) await _isar.localFileCaches.delete(entry!.id);
    });
  }

  /// Supprime toutes les entrées dont le fichier n'existe plus sur le disque.
  /// Retourne le nombre d'entrées supprimées.
  Future<int> purgeOrphans() async {
    final all = await _isar.localFileCaches.where().findAll();
    final toDelete = <int>[];

    for (final e in all) {
      if (!File(e.filePath).existsSync()) {
        toDelete.add(e.id);
        _ramCache.remove(e.filePath);
        _accessOrder.remove(e.filePath);
      }
    }

    if (toDelete.isNotEmpty) {
      await _isar.writeTxn(() => _isar.localFileCaches.deleteAll(toDelete));
    }

    return toDelete.length;
  }

  /// Statistiques du cache.
  Future<CacheStats> stats() async {
    final total = await _isar.localFileCaches.count();
    return CacheStats(
      diskEntries: total,
      ramEntries: _ramCache.length,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _putRam(String path, LocalFileCache entry) {
    if (!_ramCache.containsKey(path)) {
      if (_ramCache.length >= _ramCapacity) _evictLru();
      _accessOrder.add(path);
    }
    _ramCache[path] = entry;
    _touch(path);
  }

  void _touch(String path) {
    _accessOrder.remove(path);
    _accessOrder.add(path);
  }

  void _evictLru() {
    if (_accessOrder.isEmpty) return;
    final oldest = _accessOrder.removeAt(0);
    _ramCache.remove(oldest);
  }
}

class CacheStats {
  final int diskEntries;
  final int ramEntries;

  const CacheStats({
    required this.diskEntries,
    required this.ramEntries,
  });

  @override
  String toString() =>
      'CacheStats(disk=$diskEntries, ram=$ramEntries)';
}
