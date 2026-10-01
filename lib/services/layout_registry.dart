// lib/services/layout_registry.dart
// In-memory + disk cache for parsed UiLayout objects.
// One layout per source, keyed by source.id.
// Loaded from disk on demand; refreshed on extension install/update.

import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/utils/log/logger.dart';

class LayoutRegistry {
  LayoutRegistry._();
  static final LayoutRegistry instance = LayoutRegistry._();

  final Map<int, UiLayout> _cache = {};
  final Map<int, String> _rawCache = {};

  /// Returns the [UiLayout] for [source], or [UiLayout.empty] if not loaded.
  UiLayout get(Source source) {
    final id = source.id;
    if (id == null) return UiLayout.empty;
    return _cache[id] ?? UiLayout.empty;
  }

  /// Returns true if a layout is already in memory for this source.
  bool has(Source source) => source.id != null && _cache.containsKey(source.id);

  /// Load layout from local storage for [source] and update the memory cache.
  /// Safe to call multiple times.
  Future<void> load(Source source) async {
    final id = source.id;
    if (id == null || _cache.containsKey(id)) return;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_webLayoutKey(id));
        if (content == null) return;
        _rawCache[id] = content;
        _cache[id] = UiLayout.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        return;
      }
      final file = await _layoutFile(source);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _rawCache[id] = content;
      _cache[id] = UiLayout.fromJson(json);
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
  Future<bool> save(Source source, String jsonContent) async {
    if (source.id == null) return false;
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('layout root must be an object');
      }
      final json = decoded;
      if (json['schemaVersion'] is! num ||
          (json['schemaVersion'] as num) < 1 ||
          json['home'] is! Map<String, dynamic>) {
        throw const FormatException('layout schemaVersion/home is missing');
      }
      final sections = (json['home'] as Map<String, dynamic>)['sections'];
      if (sections != null && sections is! List) {
        throw const FormatException('home.sections must be an array');
      }
      if (sections is List) {
        final ids = <String>{};
        for (final section in sections) {
          if (section is! Map<String, dynamic>) {
            throw const FormatException('each home section must be an object');
          }
          final id = section['id'];
          if (id is! String || id.trim().isEmpty || !ids.add(id)) {
            throw const FormatException(
              'each home section needs a unique, non-empty id',
            );
          }
          if (section['component'] is! String ||
              (section['component'] as String).trim().isEmpty) {
            throw const FormatException(
              'each home section needs a component name',
            );
          }
        }
      }
      final sourceId = source.id!;
      final layout = UiLayout.fromJson(json);
      _cache[sourceId] = layout;
      _rawCache[sourceId] = jsonContent;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.setString(_webLayoutKey(sourceId), jsonContent);
      }
      final file = await _layoutFile(source);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonContent);
      AppLogger.log(
        '[LayoutRegistry] Saved ${source.name}',
        tag: LogTag.extension_,
      );
      return true;
    } catch (e) {
      AppLogger.log(
        '[LayoutRegistry] Save failed for ${source.name}: $e',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
      return false;
    }
  }

  /// Remove layout from memory and disk (called on extension uninstall).
  Future<void> remove(Source source) async {
    if (source.id == null) return;
    _cache.remove(source.id);
    _rawCache.remove(source.id);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webLayoutKey(source.id!));
      return;
    }
    try {
      final file = await _layoutFile(source);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Evict one source from the memory cache (forces reload on next access).
  void evict(Source source) {
    if (source.id != null) {
      _cache.remove(source.id);
      _rawCache.remove(source.id);
    }
  }

  /// Clear all in-memory layouts (call on full app reload).
  void clear() {
    _cache.clear();
    _rawCache.clear();
  }

  /// Returns the original JSON text for the active local layout.
  Future<String?> readJson(Source source) async {
    if (source.id == null) return null;
    await load(source);
    return _rawCache[source.id!];
  }

  static Future<File> _layoutFile(Source source) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/layouts/${source.id}.json');
  }

  static String _webLayoutKey(int sourceId) =>
      'watchtower_layout_json_$sourceId';
}
