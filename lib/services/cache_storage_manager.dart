import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/utils/log/logger.dart';

/// One on-disk image cache the manager is responsible for.
///
/// A cache is identified by its directory. `cacheimagecover` has two: the
/// persistent one under Application Support and the legacy one the older
/// releases wrote to the OS cache directory. Both are counted and evicted.
class CacheLocation {
  const CacheLocation(this.label, this.directory);

  final String label;
  final Directory directory;
}

/// Owns every on-disk image cache and keeps their **combined** size under a
/// single user-configurable ceiling.
///
/// ── Why a single owner ────────────────────────────────────────────────────
/// The app used to grow five independent caches (extension icons, extension
/// covers, library covers, `ExtendedImage.network` temp files, and
/// `flutter_cache_manager`) with no shared budget. The two that matter for
/// growth — the persistent cover cache and the icon cache — had no eviction at
/// all, so a heavy user could accumulate gigabytes.
///
/// The ceiling is a *global* one: the user picks "at most N GB of cache", and
/// the manager trims the least recently written files across every location
/// until the combined total fits. Evicting per-directory would let each of the
/// five grow to the ceiling on its own.
///
/// ── How eviction is bounded ───────────────────────────────────────────────
/// A full directory walk on every image write would be its own performance
/// bug, so a scan is throttled: it runs at most once per [scanCooldown], and
/// is forced early only when the bytes written since the last scan exceed
/// [overshootBudget]. That keeps the ceiling honest without a syscall storm.
class CacheStorageManager {
  CacheStorageManager._();

  static final CacheStorageManager instance = CacheStorageManager._();

  static const String _boxName = 'advanced_settings';
  static const String limitKey = 'cache_limit_bytes';

  /// Stable labels identifying each cache location. The settings screen passes
  /// them back to [clearLocations], so they must stay in sync.
  static const String coverLabel = 'Couvertures d\'extensions';
  static const String legacyCoverLabel = 'Couvertures d\'extensions (ancien)';
  static const String libraryCoverLabel = 'Couvertures de la bibliothèque';
  static const String readerTempLabel = 'Images de lecture temporaires';
  static const String iconLabel = 'Icônes d\'extensions';
  static const String readerLibLabel = 'Images mises en cache (lecteur)';

  /// Lower bound the user may pick. Below this the app would evict covers it
  /// is about to draw again, which is worse than the disk it saves.
  static const int minLimitBytes = 256 * 1024 * 1024; // 256 MB

  /// Upper bound. Also the value the "illimité" option maps to, so a single
  /// slider/counter covers every choice without a second code path.
  static const int maxLimitBytes = 8 * 1024 * 1024 * 1024; // 8 GB

  /// Minimum wall-clock gap between two directory walks.
  static const Duration scanCooldown = Duration(seconds: 45);

  /// Bytes written since the last scan that force an early one, so a burst of
  /// large images cannot overshoot the ceiling by an unbounded amount.
  static const int overshootBudget = 64 * 1024 * 1024; // 64 MB

  int? _cachedLimit;
  DateTime? _lastScanAt;
  int _bytesSinceScan = 0;
  Future<void>? _inFlightScan;

  /// Default ceiling for a device tier.
  ///
  /// Storage is far more abundant than RAM, so the tiers are generous; the
  /// point is to stop unbounded growth, not to run the cache lean.
  static int defaultLimitForTier(String tier) {
    switch (tier) {
      case 'low':
        return 512 * 1024 * 1024; // 512 MB
      case 'high':
        return 3 * 1024 * 1024 * 1024; // 3 GB
      default:
        return 1536 * 1024 * 1024; // 1.5 GB
    }
  }

  /// The ceiling in effect, read from Hive once and then memoised.
  Future<int> getLimitBytes() async {
    final cached = _cachedLimit;
    if (cached != null) return cached;
    final fallback = defaultLimitForTier(DeviceCapabilities.ramTier);
    int value = fallback;
    try {
      final box = await Hive.openBox(_boxName);
      final stored = box.get(limitKey);
      if (stored is int && stored >= minLimitBytes) {
        value = stored.clamp(minLimitBytes, maxLimitBytes);
      }
    } catch (_) {
      // Hive not open yet (very early image load) or a read failure: use the
      // tier default rather than letting a cache read block image rendering.
    }
    _cachedLimit = value;
    return value;
  }

  /// Persist a new ceiling and trim immediately so the change is visible in
  /// the settings screen without waiting for the next scan.
  Future<void> setLimitBytes(int bytes) async {
    final clamped = bytes.clamp(minLimitBytes, maxLimitBytes);
    _cachedLimit = clamped;
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(limitKey, clamped);
    } catch (error) {
      AppLogger.log(
        'cache limit not persisted: $error',
        logLevel: LogLevel.warning,
      );
    }
    try {
      await enforceLimit(force: true);
    } catch (_) {
      // Trimming is best-effort: a failure must not stop the setting from
      // being applied on the next launch.
    }
  }

  /// Every cache location, with the label the settings screen shows.
  Future<List<CacheLocation>> locations() async {
    final storage = StorageProvider();
    final tempRoot = await getTemporaryDirectory();
    final documentsRoot = await getApplicationDocumentsDirectory();
    return [
      CacheLocation(
        coverLabel,
        await storage.getPersistentCacheDirectory('cacheimagecover'),
      ),
      CacheLocation(
        legacyCoverLabel,
        await storage.getCacheDirectory('cacheimagecover'),
      ),
      CacheLocation(
        libraryCoverLabel,
        await storage.getCacheDirectory('cacheimagemanga'),
      ),
      CacheLocation(
        readerTempLabel,
        Directory(p.join(tempRoot.path, 'cacheimage')),
      ),
      CacheLocation(
        iconLabel,
        Directory(p.join(documentsRoot.path, 'icon_cache')),
      ),
      CacheLocation(
        readerLibLabel,
        Directory(p.join(tempRoot.path, 'libCachedImageData')),
      ),
    ];
  }

  /// Combined size of every cache, in bytes.
  Future<int> totalSizeBytes() async {
    if (kIsWeb) return 0;
    var total = 0;
    for (final location in await locations()) {
      total += await directorySize(location.directory);
    }
    return total;
  }

  /// Trims the caches back under the ceiling.
  ///
  /// [force] skips the cooldown — used at startup, when the user changes the
  /// limit, and when a burst of writes has exceeded [overshootBudget].
  ///
  /// [overrideDirectories] and [overrideLimitBytes] are test seams: the real
  /// locations and the ceiling come from platform channels and Hive, so the
  /// eviction policy is exercised against temp directories instead of mocking
  /// the whole storage stack.
  Future<void> enforceLimit({
    bool force = false,
    List<Directory>? overrideDirectories,
    int? overrideLimitBytes,
  }) async {
    if (kIsWeb) return;
    final limit = overrideLimitBytes ?? await getLimitBytes();
    if (limit <= 0) return;

    final now = DateTime.now();
    final last = _lastScanAt;
    final cooling = last != null && now.difference(last) < scanCooldown;
    if (!force && cooling && _bytesSinceScan < overshootBudget) return;

    // Collapse concurrent scans: image writes fire in parallel, and running
    // several directory walks at once would be pure waste.
    final running = _inFlightScan;
    if (running != null) return running;

    final directories =
        overrideDirectories ??
        (await locations()).map((location) => location.directory).toList();
    final scan = _evictToFit(limit, directories);
    _inFlightScan = scan;
    try {
      await scan;
      _lastScanAt = DateTime.now();
      _bytesSinceScan = 0;
    } finally {
      if (identical(_inFlightScan, scan)) _inFlightScan = null;
    }
  }

  /// Called by the image pipeline after it writes [bytes] to disk.
  ///
  /// Keeps the overshoot counter so a burst of large images forces an early
  /// scan instead of silently blowing past the ceiling until the cooldown
  /// expires.
  void noteWritten(int bytes) {
    if (bytes <= 0) return;
    _bytesSinceScan += bytes;
    if (_bytesSinceScan >= overshootBudget) {
      unawaited(enforceLimit(force: true).catchError((Object _) {}));
    }
  }

  /// Deletes every cache file. Used by the "vider le cache" actions.
  Future<void> clearAll() async {
    if (kIsWeb) return;
    for (final location in await locations()) {
      await clearDirectory(location.directory);
    }
    _bytesSinceScan = 0;
  }

  /// Deletes the given cache locations only.
  Future<void> clearLocations(Iterable<String> labels) async {
    if (kIsWeb) return;
    final wanted = labels.toSet();
    for (final location in await locations()) {
      if (wanted.contains(location.label)) {
        await clearDirectory(location.directory);
      }
    }
    _bytesSinceScan = 0;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _evictToFit(int limit, List<Directory> directories) async {
    final files = <_CacheFile>[];
    var total = 0;
    for (final directory in directories) {
      for (final file in await _listFiles(directory)) {
        try {
          final stat = await file.stat();
          files.add(
            _CacheFile(
              file: file,
              size: stat.size,
              // Ordering uses the write time, not `accessed`. Android mounts
              // /data with relatime/noatime, so `accessed` reads back as the
              // epoch or as the current instant depending on the mount — the
              // order it produces is arbitrary, and an arbitrary order can
              // delete the entry that was just written. `modified` is always
              // maintained, so it gives a stable oldest-first order.
              lastWritten: stat.modified,
            ),
          );
          total += stat.size;
        } catch (_) {
          // Deleted between listing and stat.
        }
      }
    }
    if (total <= limit) return;

    // Oldest first: the file that has gone unwritten the longest goes first.
    files.sort((a, b) => a.lastWritten.compareTo(b.lastWritten));
    for (final entry in files) {
      if (total <= limit) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (error) {
        AppLogger.log(
          'cache eviction failed for ${entry.file.path}: $error',
          logLevel: LogLevel.debug,
        );
      }
    }
    AppLogger.log(
      'cache trimmed to ${_fmt(total)} (limit ${_fmt(limit)})',
      logLevel: LogLevel.debug,
    );
  }

  /// Total bytes held by [dir], recursively. Zero when it does not exist.
  Future<int> directorySize(Directory dir) async {
    var total = 0;
    for (final file in await _listFiles(dir)) {
      try {
        total += await file.length();
      } catch (_) {
        // Deleted between listing and length.
      }
    }
    return total;
  }

  /// Every file under [root], walking folder by folder.
  ///
  /// A single `list(recursive: true)` aborts the whole stream on the first
  /// `FileSystemException`, which would undercount the cache and let it stay
  /// over the ceiling. Listing one folder at a time keeps an unreadable
  /// subtree local to its own branch.
  Future<List<File>> _listFiles(Directory root) async {
    final files = <File>[];
    final pending = <Directory>[root];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      try {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is File) {
            files.add(entity);
          } else if (entity is Directory) {
            pending.add(entity);
          }
        }
      } catch (_) {
        // Unreadable or deleted mid-walk: skip this subtree.
      }
    }
    return files;
  }

  @visibleForTesting
  Future<void> clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (error) {
      AppLogger.log(
        'cache clear failed for ${dir.path}: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _cachedLimit = null;
    _lastScanAt = null;
    _bytesSinceScan = 0;
    _inFlightScan = null;
  }

  static String _fmt(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class _CacheFile {
  const _CacheFile({
    required this.file,
    required this.size,
    required this.lastWritten,
  });

  final File file;
  final int size;
  final DateTime lastWritten;
}
