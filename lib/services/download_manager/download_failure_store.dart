import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why a chapter download failed, kept per chapter so the queue row can show
/// it after the fact.
///
/// The download path already produces a precise reason ("HTTP 429", "3 pages
/// sur 40 n'ont pas pu être téléchargées"), but it only reached the user
/// through a toast. A toast is shown once and is dropped entirely when no
/// Overlay is live — which is the normal case for a batch download that keeps
/// running while the app is backgrounded. The user then saw a wall of red rows
/// with no reason and no way to tell a dead source from a throttle.
///
/// Deliberately kept out of Isar: adding a field to the [Download] collection
/// changes its schema, and the version gate in `storage_provider.dart` wipes
/// the whole database on a schema change.
@immutable
class DownloadFailure {
  final String message;

  /// True when the chapter is incomplete but partly usable (some pages landed).
  final bool partial;

  final int failedPages;
  final int totalPages;
  final DateTime at;

  const DownloadFailure({
    required this.message,
    required this.at,
    this.partial = false,
    this.failedPages = 0,
    this.totalPages = 0,
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'at': at.millisecondsSinceEpoch,
    'partial': partial,
    'failedPages': failedPages,
    'totalPages': totalPages,
  };

  static DownloadFailure? fromJson(Object? json) {
    if (json is! Map) return null;
    final message = json['message'];
    final at = (json['at'] as num?)?.toInt();
    if (message is! String || message.isEmpty || at == null) return null;
    return DownloadFailure(
      message: message,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      partial: json['partial'] == true,
      failedPages: (json['failedPages'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}

class DownloadFailureStore {
  DownloadFailureStore._();
  static final DownloadFailureStore instance = DownloadFailureStore._();

  static const _prefsKey = 'watchtower_download_failures';

  final ValueNotifier<Map<int, DownloadFailure>> failures =
      ValueNotifier<Map<int, DownloadFailure>>(const {});

  final StreamController<Map<int, DownloadFailure>> _changes =
      StreamController<Map<int, DownloadFailure>>.broadcast();

  /// Broadcast stream of the current map, replayed to each new listener so the
  /// queue renders a reason immediately instead of waiting for the next write.
  Stream<Map<int, DownloadFailure>> watch() async* {
    yield failures.value;
    yield* _changes.stream;
  }

  Map<int, DownloadFailure> _current = const {};
  bool _loaded = false;

  DownloadFailure? of(int chapterId) => _current[chapterId];

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final restored = <int, DownloadFailure>{};
      decoded.forEach((key, value) {
        final id = int.tryParse(key.toString());
        final parsed = DownloadFailure.fromJson(value);
        if (id != null && parsed != null) restored[id] = parsed;
      });
      if (restored.isEmpty) return;
      _current = Map<int, DownloadFailure>.unmodifiable(restored);
      _emit();
    } catch (_) {
      // Best-effort: a lost reason must never break the queue.
    }
  }

  void set(int chapterId, DownloadFailure failure) {
    final next = Map<int, DownloadFailure>.from(_current)
      ..[chapterId] = failure;
    _current = Map<int, DownloadFailure>.unmodifiable(next);
    _emit();
    _persist();
  }

  void clear(int chapterId) {
    if (!_current.containsKey(chapterId)) return;
    final next = Map<int, DownloadFailure>.from(_current)..remove(chapterId);
    _current = Map<int, DownloadFailure>.unmodifiable(next);
    _emit();
    _persist();
  }

  void _emit() {
    failures.value = _current;
    if (!_changes.isClosed) _changes.add(_current);
  }

  void _persist() {
    final payload = <String, dynamic>{
      for (final entry in _current.entries)
        entry.key.toString(): entry.value.toJson(),
    };
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(payload));
      } catch (_) {
        // Best-effort persistence.
      }
    }());
  }
}

/// Exposes per-chapter download failures to the queue UI.
final downloadFailuresProvider =
    StreamProvider<Map<int, DownloadFailure>>((ref) async* {
      final store = DownloadFailureStore.instance;
      await store.load();
      yield* store.watch();
    });
