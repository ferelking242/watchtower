import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class IconCacheService {
  IconCacheService._();
  static final IconCacheService _instance = IconCacheService._();
  static IconCacheService get instance => _instance;

  final Map<String, Uint8List> _mem = {};
  Directory? _cacheDir;

  /// A process-independent name lets extension icons survive app restarts.
  static String cacheKeyFor(int? sourceId, String iconUrl) {
    final urlDigest = sha256.convert(utf8.encode(iconUrl.trim()));
    return 'icon_${sourceId ?? 0}_$urlDigest';
  }

  Future<Directory> get cacheDir async {
    _cacheDir ??= Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'icon_cache'),
    );
    await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  Future<Uint8List?> getIcon(int? sourceId, String? iconUrl) async {
    final url = iconUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    final key = cacheKeyFor(sourceId, url);
    final cached = _mem[key];
    if (cached != null) return cached;

    try {
      final dir = await cacheDir;
      final bytes = await _readPersistentIcon(dir, sourceId, key);
      if (bytes != null) {
        _mem[key] = bytes;
        return bytes;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

      final bytes = response.bodyBytes;
      _mem[key] = bytes;
      try {
        final dir = await cacheDir;
        await File(p.join(dir.path, '$key.img')).writeAsBytes(
          bytes,
          flush: true,
        );
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
}


class ExtensionIconWidget extends StatefulWidget {
  final int? sourceId;
  final String? iconUrl;
  final double size;

  const ExtensionIconWidget({
    super.key,
    required this.sourceId,
    required this.iconUrl,
    this.size = 30,
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
    if (old.iconUrl != widget.iconUrl || old.sourceId != widget.sourceId) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.extension_rounded,
          size: widget.size * 0.6,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}