import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/data/live_defaults.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Persistence for installed Live TV providers.
///
/// Kept in Hive next to the other preference boxes rather than Isar: providers
/// are a small, append-mostly list, and putting them in the same box family as
/// the rest of the settings means they travel with the existing auto-backup.
///
/// Builtin providers are merged on read, never trusted from disk: a shipped
/// provider must reappear even if its stored record was lost or the app
/// downgraded. A user edit to a builtin (enabled flag, version) still wins over
/// the shipped default, which is what makes "disable" and "update" stick.
class LiveProviderStore {
  LiveProviderStore({Box<dynamic>? box}) : _box = box;

  static const boxName = 'live_tv_providers';
  static const _key = 'providers';
  static const _statsKey = 'fetch_stats';

  final Box<dynamic>? _box;

  Box<dynamic>? get _store =>
      _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);

  /// Providers to show.
  List<LiveProvider> read() {
    final stored = _readRaw();
    final byId = {for (final provider in stored) provider.id: provider};

    // A provider that used to ship with the app points at an asset that no
    // longer exists; left in place it would fail on every fetch. Dropping it
    // here (rather than on write) also cleans installs that never write again.
    for (final id in LiveDefaults.retiredIds) {
      byId.remove(id);
    }

    return _sorted(byId.values.toList());
  }

  /// Adds a provider, replacing any existing one with the same id.
  Future<void> save(LiveProvider provider) async {
    final current = read().where((p) => p.id != provider.id).toList();
    await _write([...current, provider]);
  }

  Future<void> saveAll(List<LiveProvider> providers) => _write(providers);

  Future<void> remove(String id) async {
    final current = read();
    final target = current.where((p) => p.id == id).firstOrNull;
    // Builtins can be disabled but not deleted: the app would silently restore
    // them on the next launch, which reads as the delete having failed.
    if (target == null || target.isBuiltin) return;
    await _write(current.where((p) => p.id != id).toList());
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final current = read();
    final target = current.where((p) => p.id == id).firstOrNull;
    if (target == null) return;
    await _write([
      for (final provider in current)
        provider.id == id ? provider.copyWith(isEnabled: enabled) : provider,
    ]);
  }

  /// Applies catalogue versions to installed providers.
  ///
  /// Returns the providers whose version changed, so the UI can report what it
  /// updated instead of silently mutating rows under the user.
  Future<List<LiveProvider>> applyUpdates(
    List<LiveProviderCatalogEntry> catalogue,
  ) async {
    final current = read();
    final byId = {for (final entry in catalogue) entry.id: entry};
    final updated = <LiveProvider>[];
    final next = <LiveProvider>[];

    for (final provider in current) {
      final entry = byId[provider.id];
      if (entry == null || !_isNewer(entry.version, provider.version)) {
        next.add(provider);
        continue;
      }
      final upgraded = provider.copyWith(
        name: entry.name,
        source: entry.source,
        kind: entry.kind,
        isBundled: entry.kind == LiveProviderKind.bundled,
        iconUrl: entry.iconUrl,
        description: entry.description,
        author: entry.author,
        version: entry.version,
        updatedAt: DateTime.now(),
      );
      next.add(upgraded);
      updated.add(upgraded);
    }

    if (updated.isNotEmpty) await _write(next);
    return updated;
  }

  List<LiveProvider> _readRaw() {
    final raw = _store?.get(_key);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            ?LiveProvider.fromJson(item.cast<String, dynamic>()),
      ];
    } catch (error) {
      debugPrint('[live_tv] provider store unreadable: $error');
      return const [];
    }
  }

  Future<void> _write(List<LiveProvider> providers) async {
    final box = _store;
    if (box == null) return;
    await box.put(
      _key,
      jsonEncode([for (final provider in providers) provider.toJson()]),
    );
  }

  /// Builtins first, then user providers, alphabetical inside each group.
  static List<LiveProvider> _sorted(List<LiveProvider> providers) {
    final sorted = [...providers]
      ..sort((a, b) {
        if (a.isBuiltin != b.isBuiltin) return a.isBuiltin ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  /// Dotted-numeric comparison: `1.10.0` is newer than `1.9.0`.
  static bool _isNewer(String candidate, String installed) {
    final left = candidate.split('.').map(int.tryParse).toList();
    final right = installed.split('.').map(int.tryParse).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final a = i < left.length ? left[i] ?? 0 : 0;
      final b = i < right.length ? right[i] ?? 0 : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  /// Fetch results, stored beside the providers but read through their own
  /// provider so writing them never invalidates a channel fetch.
  Map<String, LiveFetchStat> readFetchStats() {
    final raw = _store?.get(_statsKey);
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map)
            entry.key as String: LiveFetchStat.fromJson(
              (entry.value as Map).cast<String, dynamic>(),
            ),
      };
    } catch (error) {
      debugPrint('[live_tv] fetch stats unreadable: $error');
      return const {};
    }
  }

  Future<void> recordFetch(String providerId, int channelCount) async {
    final box = _store;
    if (box == null) return;
    final stats = {...readFetchStats()};
    stats[providerId] = LiveFetchStat(
      channelCount: channelCount,
      fetchedAt: DateTime.now(),
    );
    await box.put(
      _statsKey,
      jsonEncode({for (final e in stats.entries) e.key: e.value.toJson()}),
    );
  }
}

/// What the last successful fetch of a provider reported.
class LiveFetchStat {
  const LiveFetchStat({required this.channelCount, required this.fetchedAt});

  final int channelCount;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
    'channelCount': channelCount,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  static LiveFetchStat fromJson(Map<String, dynamic> json) => LiveFetchStat(
    channelCount: (json['channelCount'] as num?)?.toInt() ?? 0,
    fetchedAt:
        DateTime.tryParse(json['fetchedAt'] as String? ?? '') ?? DateTime(1970),
  );
}
