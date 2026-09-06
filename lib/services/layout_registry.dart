// lib/services/layout_registry.dart
// In-memory + disk cache for parsed UiLayout objects.
// One layout per source, keyed by source.id.
// Loaded from disk on demand; refreshed on extension install/update.

import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/utils/log/logger.dart';

class LayoutRegistry {
  LayoutRegistry._();
  static final LayoutRegistry instance = LayoutRegistry._();

  final Map<int, UiLayout> _cache = {};

  /// Returns the [UiLayout] for [source], or [UiLayout.empty] if not loaded.
  UiLayout get(Source source) {
    final id = source.id;
    if (id == null) return UiLayout.empty;
    return _cache[id] ?? UiLayout.empty;
  }

  /// Returns true if a layout is already in memory for this source.
  bool has(Source source) =>
      source.id != null && _cache.containsKey(source.id);

  /// Load layout from disk for [source] and update the memory cache.
  /// No-op on web or if no id. Safe to call multiple times.
  Future<void> load(Source source) async {
    if (kIsWeb || source.id == null) return;
    if (_cache.containsKey(source.id)) return; // already loaded
    try {
      final file = await _layoutFile(source);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _cache[source.id!] = UiLayout.fromJson(json);
      AppLogger.log(
        '[LayoutRegistry] Loaded ${source.name}',
        tag: LogTag.extension_,
      );
    } catch (e) {
      AppLogger.log(
        '[LayoutRegistry] Load failed for ${source.name}: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    }
  }

  /// Persist [jsonContent] to disk and update the memory cache.
  /// Called by [LayoutDownloader] after a successful download.
  Future<void> save(Source source, String jsonContent) async {
    if (kIsWeb || source.id == null) return;
    try {
      final file = await _layoutFile(source);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonContent);
      final json = jsonDecode(jsonContent) as Map<String, dynamic>;
      _cache[source.id!] = UiLayout.fromJson(json);
      AppLogger.log(
        '[LayoutRegistry] Saved ${source.name}',
        tag: LogTag.extension_,
      );
    } catch (e) {
      AppLogger.log(
        '[LayoutRegistry] Save failed for ${source.name}: $e',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
    }
  }

  /// Remove layout from memory and disk (called on extension uninstall).
  Future<void> remove(Source source) async {
    if (source.id == null) return;
    _cache.remove(source.id);
    if (kIsWeb) return;
    try {
      final file = await _layoutFile(source);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Evict one source from the memory cache (forces reload on next access).
  void evict(Source source) {
    if (source.id != null) _cache.remove(source.id);
  }

  /// Clear all in-memory layouts (call on full app reload).
  void clear() => _cache.clear();

  static Future<File> _layoutFile(Source source) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/layouts/${source.id}.json');
  }
}
