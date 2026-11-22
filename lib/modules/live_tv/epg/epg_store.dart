import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';

/// Hive cache for the parsed guide.
///
/// A guide is expensive to fetch and parse, so it is stored as one JSON blob
/// next to the other Live TV preferences and re-read on launch. Entries expire
/// because a stale guide shows the wrong programme as "now", which is worse
/// than showing nothing.
class EpgStore {
  EpgStore({Box<dynamic>? box}) : _box = box;

  static const boxName = 'live_tv_epg';
  static const _guideKey = 'guide';
  static const _urlKey = 'url';

  /// A guide older than this is refreshed on next open.
  static const maxAge = Duration(hours: 12);

  final Box<dynamic>? _box;

  Box<dynamic>? get _store =>
      _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);

  /// The cached guide, or null when absent, unreadable or expired.
  EpgGuide? read({bool ignoreExpiry = false}) {
    final raw = _store?.get(_guideKey);
    if (raw is! String || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final guide = EpgGuide.fromJson(Map<String, dynamic>.from(json));
      if (guide == null) return null;
      if (!ignoreExpiry &&
          DateTime.now().difference(guide.fetchedAt) > maxAge) {
        return null;
      }
      return guide;
    } catch (error) {
      debugPrint('EpgStore: cache illisible ($error)');
      return null;
    }
  }

  /// Reads the cache even when expired, so the guide screen can show the last
  /// known schedule while a refresh runs.
  EpgGuide? readStale() => read(ignoreExpiry: true);

  Future<void> write(EpgGuide guide, {String? url}) async {
    final box = _store;
    if (box == null) return;
    try {
      await box.put(_guideKey, jsonEncode(guide.toJson()));
      if (url != null) await box.put(_urlKey, url);
    } catch (error) {
      debugPrint('EpgStore: écriture impossible ($error)');
    }
  }

  /// URL the cached guide came from, so a refresh can reuse it.
  String? readUrl() {
    final raw = _store?.get(_urlKey);
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  Future<void> clear() async {
    final box = _store;
    if (box == null) return;
    await box.delete(_guideKey);
    await box.delete(_urlKey);
  }

  /// Size of the stored guide, for the settings screen.
  int get byteSize {
    final raw = _store?.get(_guideKey);
    return raw is String ? raw.length : 0;
  }
}
