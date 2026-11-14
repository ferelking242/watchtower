import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/services/cache_storage_manager.dart';
import 'package:watchtower/utils/image_bytes_lru_cache.dart';

class IconCacheService {
  IconCacheService._();
  static final IconCacheService _instance = IconCacheService._();
  static IconCacheService get instance => _instance;

  /// Bounded so a user with many installed extensions cannot grow it without
  /// limit; icons are small but there is no reason to keep them all forever.
  final ImageBytesLruCache<String, Uint8List> _mem = createIconMemoryCache();
  Directory? _cacheDir;

  /// A process-independent name lets extension icons survive app restarts.
  ///
  /// [version] is part of the key on purpose: an extension that ships a new
  /// icon usually keeps the same URL, so a URL-only key would keep serving the
  /// old artwork forever. Bumping the version writes a new file and orphans
  /// the previous one, which the cache storage manager then evicts.
  static String cacheKeyFor(int? sourceId, String iconUrl, [String? version]) {
    final urlDigest = sha256.convert(utf8.encode(iconUrl.trim()));
    final versionTag = (version ?? '').trim();
    return versionTag.isEmpty
        ? 'icon_${sourceId ?? 0}_$urlDigest'
        : 'icon_${sourceId ?? 0}_${_shortHash(versionTag)}_$urlDigest';
  }

  static String _shortHash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 12);

  Future<Directory> get cacheDir async {
    _cacheDir ??= Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'icon_cache'),
    );
    await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  Future<Uint8List?> getIcon(
    int? sourceId,
    String? iconUrl, [
    String? version,
  ]) async {
    final url = iconUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    final key = cacheKeyFor(sourceId, url, version);
    final cached = _mem.get(key);
    if (cached != null) return cached;

    try {
      final dir = await cacheDir;
      final bytes = await _readPersistentIcon(dir, sourceId, key);
      if (bytes != null) {
        _mem.put(key, bytes);
        return bytes;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

      final bytes = response.bodyBytes;
      _mem.put(key, bytes);
      try {
        final dir = await cacheDir;
        await File(p.join(dir.path, '$key.img')).writeAsBytes(
          bytes,
          flush: true,
        );
        CacheStorageManager.instance.noteWritten(bytes.length);
      } catch (_) {
        // The image still renders if storage is temporarily unavailable.
      }
      return bytes;
    } catch (_) {
      // Do not remember misses: the same installed extension should retry
      // after connectivity returns.
      return null;
    }
  }

  Future<Uint8List?> _readPersistentIcon(
    Directory dir,
    int? sourceId,
    String stableKey,
  ) async {
    final stableFile = File(p.join(dir.path, '$stableKey.img'));
    if (await stableFile.exists()) {
      final bytes = await stableFile.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
      await stableFile.delete();
    }

    // Older app versions stored a String.hashCode in the filename. Migrate
    // the newest matching entry once, then use the stable SHA-256 key.
    final prefix = 'icon_${sourceId ?? 0}_';
    File? newestLegacyFile;
    DateTime? newestModified;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(prefix) || !name.endsWith('.png')) continue;
      final modified = await entity.lastModified();
      if (newestModified == null || modified.isAfter(newestModified)) {
        newestLegacyFile = entity;
        newestModified = modified;
      }
    }
    if (newestLegacyFile == null) return null;

    final legacyBytes = await newestLegacyFile.readAsBytes();
    if (legacyBytes.isEmpty) return null;
    try {
      await stableFile.writeAsBytes(legacyBytes, flush: true);
    } catch (_) {}
    return legacyBytes;
  }

  /// Drops the in-memory icon bytes. The on-disk copies are untouched, so the
  /// next request re-reads them without a network round trip.
  void clearMemory() => _mem.clear();

  /// Number of icons currently held in memory.
  @visibleForTesting
  int get memoryEntryCount => _mem.length;

  /// Forgets the cached directory and in-memory icons. Tests swap the
  /// documents directory between cases, and the resolved [cacheDir] is cached
  /// on the singleton, so without this a later case would read the previous
  /// case's (deleted) folder.
  @visibleForTesting
  void resetForTesting() {
    _mem.clear();
    _cacheDir = null;
  }
}


class ExtensionIconWidget extends StatefulWidget {
  final int? sourceId;
  final String? iconUrl;
  final double size;

  /// Installed extension version. Part of the cache key so an extension that
  /// updates its icon in place invalidates the cached bytes.
  final String? version;

  /// Clip the icon into a circle instead of a rounded square. The reel screen
  /// shows the extension avatar as a disc, so it needs the round variant.
  final bool circular;

  const ExtensionIconWidget({
    super.key,
    required this.sourceId,
    required this.iconUrl,
    this.version,
    this.size = 30,
    this.circular = false,
  });

  @override
  State<ExtensionIconWidget> createState() => _ExtensionIconWidgetState();
}

class _ExtensionIconWidgetState extends State<ExtensionIconWidget> {
  Uint8List? _bytes;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ExtensionIconWidget old) {
    super.didUpdateWidget(old);
    if (old.iconUrl != widget.iconUrl ||
        old.sourceId != widget.sourceId ||
        old.version != widget.version) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _loading = true);
    final bytes = await IconCacheService.instance.getIcon(
      widget.sourceId,
      widget.iconUrl,
      widget.version,
    );
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: Icon(Icons.extension_rounded, size: 14)),
      );
    }
    if (_bytes == null) {
      return Icon(
        Icons.extension_rounded,
        size: widget.size * 0.6,
        color: Theme.of(context).hintColor,
      );
    }
    // Decode at the size actually drawn, not at the source resolution: the
    // Flutter image cache stores the decoded bitmap, so an extension icon
    // rendered at 12-37 px used to occupy a full-size bitmap per entry and
    // evict real content out of the decode cache.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final decodeSize = (widget.size * dpr).round();
    final image = Image.memory(
      _bytes!,
      width: widget.size,
      height: widget.size,
      cacheWidth: decodeSize,
      cacheHeight: decodeSize,
      fit: widget.circular ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.extension_rounded,
        size: widget.size * 0.6,
        color: Theme.of(context).hintColor,
      ),
    );
    return widget.circular
        ? ClipOval(child: image)
        : ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: image,
          );
  }
}