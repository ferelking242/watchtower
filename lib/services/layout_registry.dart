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
import 'package:watchtower/models/layout_component_registry.dart';
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
  ///
  /// The cached file is only trusted when it was written for the layout
  /// version the installed source declares. A layout is downloaded once at
  /// install time and then lives on disk, so without this check a catalogue
  /// that edits `ui-layouts/<slug>.json` and bumps `uiLayoutVersion` would
  /// never reach an installed app: the old JSON was served forever. A stale
  /// cache is discarded instead of loaded, which leaves [has] false so the
  /// caller (the home screen) downloads the current layout.
  Future<void> load(Source source) async {
    final id = source.id;
    if (id == null || _cache.containsKey(id)) return;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_webLayoutKey(id));
        if (content == null) return;
        final stamp = prefs.getString(_webVersionKey(id));
        if (_isStale(source, stamp)) {
          _logStale(source, stamp);
          await prefs.remove(_webLayoutKey(id));
          await prefs.remove(_webVersionKey(id));
          return;
        }
        _rawCache[id] = content;
        _cache[id] = UiLayout.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        return;
      }
      final file = await _layoutFile(source);
      if (!await file.exists()) return;
      final stamp = await _readVersionStamp(source);
      if (_isStale(source, stamp)) {
        _logStale(source, stamp);
        await file.delete();
        return;
      }
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
          final component = section['component'] as String;
          if (!LayoutComponentRegistry.supports(
            component,
            LayoutComponentContext.home,
          )) {
            throw FormatException(
              LayoutComponentRegistry.unknownComponentMessage(
                component,
                LayoutComponentContext.home,
              ),
            );
          }
        }
      }
      final browse = json['browse'];
      if (browse is Map<String, dynamic>) {
        _validateCardComponent(
          browse['popular'],
          LayoutComponentContext.browse,
          'browse.popular',
        );
        _validateCardComponent(
          browse['latest'],
          LayoutComponentContext.browse,
          'browse.latest',
        );
        final search = browse['search'];
        if (search is Map<String, dynamic>) {
          _validateCardComponent(
            search['results'],
            LayoutComponentContext.search,
            'browse.search.results',
          );
        }
      }
      final sourceId = source.id!;
      final layout = UiLayout.fromJson(json);
      _cache[sourceId] = layout;
      _rawCache[sourceId] = jsonContent;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_webLayoutKey(sourceId), jsonContent);
        return await _writeVersionStamp(source, prefs: prefs);
      }
      final file = await _layoutFile(source);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonContent);
      await _writeVersionStamp(source);
      AppLogger.log(
        '[LayoutRegistry] Saved ${source.name}',
        tag: LogTag.extension_,
      );
      return true;
    } on FormatException catch (e) {
      if (e.message.toString().startsWith('Composant inconnu :')) {
        rethrow;
      }
      AppLogger.log(
        '[LayoutRegistry] Save failed for ${source.name}: $e',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
      return false;
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
      await prefs.remove(_webVersionKey(source.id!));
      return;
    }
    try {
      final file = await _layoutFile(source);
      if (await file.exists()) await file.delete();
      final stamp = await _versionFile(source);
      if (await stamp.exists()) await stamp.delete();
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

  void _validateCardComponent(
    Object? value,
    LayoutComponentContext context,
    String path,
  ) {
    if (value is! Map<String, dynamic> || value['cardComponent'] == null) {
      return;
    }
    final component = value['cardComponent'];
    if (component is! String || component.trim().isEmpty) {
      throw FormatException('$path.cardComponent must be a non-empty string');
    }
    if (!LayoutComponentRegistry.supports(component, context)) {
      throw FormatException(
        LayoutComponentRegistry.unknownComponentMessage(component, context),
      );
    }
  }

  static Future<File> _layoutFile(Source source) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/layouts/${source.id}.json');
  }

  /// Sidecar recording which `uiLayoutVersion` the cached JSON belongs to.
  /// Sits next to the layout (`<id>.json.version`) so both live and die
  /// together, and reading it never depends on the platform directory twice.
  static Future<File> _versionFile(Source source) async {
    final layout = await _layoutFile(source);
    return File('${layout.path}.version');
  }

  Future<String?> _readVersionStamp(Source source) async {
    try {
      final file = await _versionFile(source);
      if (!await file.exists()) return null;
      return (await file.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeVersionStamp(
    Source source, {
    SharedPreferences? prefs,
  }) async {
    final version = source.uiLayoutVersion?.trim() ?? '';
    try {
      if (prefs != null) {
        await prefs.setString(_webVersionKey(source.id!), version);
        return true;
      }
      final file = await _versionFile(source);
      await file.parent.create(recursive: true);
      await file.writeAsString(version);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when the cached JSON was written for a different layout version.
  /// An unversioned catalogue entry (`uiLayoutVersion == null`) opts out: there
  /// is nothing to compare against, so the cache stays authoritative.
  static bool _isStale(Source source, String? cachedVersion) {
    final expected = source.uiLayoutVersion?.trim();
    if (expected == null || expected.isEmpty) return false;
    return (cachedVersion ?? '') != expected;
  }

  void _logStale(Source source, String? cachedVersion) {
    AppLogger.log(
      '[LayoutRegistry] Stale layout for ${source.name} '
      '(cached "${cachedVersion ?? "none"}", expected '
      '"${source.uiLayoutVersion}") — refetching',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
    );
  }

  static String _webLayoutKey(int sourceId) =>
      'watchtower_layout_json_$sourceId';

  static String _webVersionKey(int sourceId) =>
      'watchtower_layout_version_$sourceId';
}
