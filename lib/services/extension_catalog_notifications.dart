import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/models/manga.dart';

class ExtensionPublicationNotice {
  const ExtensionPublicationNotice({
    required this.id,
    required this.name,
    required this.itemType,
    required this.version,
    required this.lang,
    this.iconUrl,
    this.publishedAt,
  });

  final int id;
  final String name;
  final ItemType itemType;
  final String version;
  final String lang;
  final String? iconUrl;
  final int? publishedAt;

  String get key => '${itemType.index}:$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'itemType': itemType.index,
    'version': version,
    'lang': lang,
    'iconUrl': iconUrl,
    'publishedAt': publishedAt,
  };

  factory ExtensionPublicationNotice.fromJson(Map<String, dynamic> json) {
    final typeIndex = (json['itemType'] as num?)?.toInt() ?? 0;
    final itemType = typeIndex >= 0 && typeIndex < ItemType.values.length
        ? ItemType.values[typeIndex]
        : ItemType.manga;
    return ExtensionPublicationNotice(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Extension',
      itemType: itemType,
      version: json['version'] as String? ?? '',
      lang: json['lang'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      publishedAt: (json['publishedAt'] as num?)?.toInt(),
    );
  }
}

/// Tracks catalogue IDs per repository so the initial catalogue import does
/// not look like hundreds of new releases, while later additions are announced
/// only once and remain visible in the in-app notification centre.
class ExtensionCatalogNotifications {
  ExtensionCatalogNotifications._();

  static const _seenPrefix = 'watchtower_extension_catalog_seen_v1:';
  static const _pendingKey = 'watchtower_extension_catalog_pending_v1';
  static const _pendingUpdatesKey = 'watchtower_extension_updates_pending_v1';
  static const _maxPending = 100;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static String _normalizedCatalogKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url.trim();
    return '${uri.host.toLowerCase()}${uri.path.toLowerCase()}';
  }

  static Future<List<ExtensionPublicationNotice>> observeCatalog({
    required String catalogUrl,
    required Iterable<ExtensionPublicationNotice> entries,
  }) {
    final catalogEntries = <String, ExtensionPublicationNotice>{
      for (final entry in entries) entry.key: entry,
    };

    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final seenKey = '$_seenPrefix${_normalizedCatalogKey(catalogUrl)}';
      final previousIds = prefs.getStringList(seenKey);
      final currentIds = catalogEntries.keys.toList()..sort();

      // Record the first successful fetch as the baseline instead of
      // notifying users about every extension that already exists.
      await prefs.setStringList(seenKey, currentIds);
      if (previousIds == null) return const [];

      final previous = previousIds.toSet();
      final newlyPublished = catalogEntries.values
          .where((entry) => !previous.contains(entry.key))
          .map(
            (entry) => ExtensionPublicationNotice(
              id: entry.id,
              name: entry.name,
              itemType: entry.itemType,
              version: entry.version,
              lang: entry.lang,
              iconUrl: entry.iconUrl,
              publishedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          )
          .toList(growable: false);
      if (newlyPublished.isEmpty) return const [];

      final pending = await _readPending(prefs);
      final pendingByKey = {for (final entry in pending) entry.key: entry};
      for (final entry in newlyPublished) {
        pendingByKey.putIfAbsent(entry.key, () => entry);
      }
      final merged = pendingByKey.values.toList()
        ..sort(
          (a, b) => (b.publishedAt ?? 0).compareTo(a.publishedAt ?? 0),
        );
      await prefs.setStringList(
        _pendingKey,
        merged
            .take(_maxPending)
            .map((entry) => jsonEncode(entry.toJson()))
            .toList(growable: false),
      );
      return newlyPublished;
    });
  }

  static Future<List<ExtensionPublicationNotice>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    return _readPending(prefs);
  }

  static Future<void> rememberPendingUpdates(
    Iterable<ExtensionPublicationNotice> updates,
  ) {
    final incoming = {for (final update in updates) update.key: update};
    if (incoming.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final current = await _readPending(prefs, _pendingUpdatesKey);
      final merged = {for (final update in current) update.key: update}
        ..addAll(incoming);
      final ordered = merged.values.toList()
        ..sort(
          (a, b) => (b.publishedAt ?? 0).compareTo(a.publishedAt ?? 0),
        );
      await prefs.setStringList(
        _pendingUpdatesKey,
        ordered
            .take(_maxPending)
            .map((entry) => jsonEncode(entry.toJson()))
            .toList(growable: false),
      );
    });
  }

  static Future<List<ExtensionPublicationNotice>> pendingUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return _readPending(prefs, _pendingUpdatesKey);
  }

  static Future<void> dismiss(ExtensionPublicationNotice notice) {
    return dismissById(id: notice.id, itemType: notice.itemType);
  }

  static Future<void> dismissById({
    required int id,
    required ItemType itemType,
  }) {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final targetKey = '${itemType.index}:$id';
      final remaining = (await _readPending(prefs))
          .where((entry) => entry.key != targetKey)
          .toList(growable: false);
      await prefs.setStringList(
        _pendingKey,
        remaining.map((entry) => jsonEncode(entry.toJson())).toList(),
      );
    });
  }

  static Future<void> dismissPendingUpdate({
    required int id,
    required ItemType itemType,
  }) {
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final targetKey = '${itemType.index}:$id';
      final remaining = (await _readPending(prefs, _pendingUpdatesKey))
          .where((entry) => entry.key != targetKey)
          .toList(growable: false);
      await prefs.setStringList(
        _pendingUpdatesKey,
        remaining.map((entry) => jsonEncode(entry.toJson())).toList(),
      );
    });
  }

  static Future<List<ExtensionPublicationNotice>> _readPending(
    SharedPreferences prefs, [
    String key = _pendingKey,
  ]) async {
    final notices = <ExtensionPublicationNotice>[];
    for (final raw in prefs.getStringList(key) ?? const <String>[]) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          notices.add(ExtensionPublicationNotice.fromJson(json));
        }
      } catch (_) {
        // Ignore a malformed persisted notice without hiding the rest.
      }
    }
    return notices;
  }
}
