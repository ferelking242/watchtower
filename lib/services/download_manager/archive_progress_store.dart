import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progress of the archive-packing ("compression") pass that runs after every
/// manga page has been downloaded. It is deliberately kept out of Isar: adding
/// a field to the [Download] collection would change its schema and force
/// Isar to wipe the whole database on the next open.
///
/// The values are mirrored into SharedPreferences so the golden second pass is
/// not lost when the app is backgrounded/restarted, and exposed through a
/// [ValueListenable] so the download queue can render it reactively.
@immutable
class ArchiveProgress {
  final int done;
  final int total;

  const ArchiveProgress({required this.done, required this.total});

  double get value => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {'done': done, 'total': total};

  static ArchiveProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final done = (json['done'] as num?)?.toInt();
    final total = (json['total'] as num?)?.toInt();
    if (done == null || total == null || total <= 0) return null;
    return ArchiveProgress(done: done, total: total);
  }
}

class ArchiveProgressStore {
  ArchiveProgressStore._();
  static final ArchiveProgressStore instance = ArchiveProgressStore._();

  static const _prefsKey = 'watchtower_archive_progress';

  final ValueNotifier<Map<int, ArchiveProgress>> progress =
      ValueNotifier<Map<int, ArchiveProgress>>(const {});

  final StreamController<Map<int, ArchiveProgress>> _changes =
      StreamController<Map<int, ArchiveProgress>>.broadcast();

  /// Broadcast stream of the current map, replayed to each new listener so the
  /// UI has a value immediately instead of waiting for the first update.
  Stream<Map<int, ArchiveProgress>> watch() async* {
    yield progress.value;
    yield* _changes.stream;
  }

  void _emit() {
    progress.value = _current;
    if (!_changes.isClosed) _changes.add(_current);
  }

  Map<int, ArchiveProgress> _current = const {};
  bool _loaded = false;

  /// Loads any progress persisted by a previous session. Values whose archive
  /// already exists are pruned the next time [set] is called for that chapter.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final restored = <int, ArchiveProgress>{};
      decoded.forEach((key, value) {
        final id = int.tryParse(key.toString());
        final parsed = ArchiveProgress.fromJson(value);
        if (id != null && parsed != null) restored[id] = parsed;
      });
      if (restored.isEmpty) return;
      _current = Map<int, ArchiveProgress>.unmodifiable(restored);
      _emit();
    } catch (_) {
      // Persisted progress is best-effort only.
    }
  }

  ArchiveProgress? of(int chapterId) => _current[chapterId];

  void set(int chapterId, {required int done, required int total}) {
    if (total <= 0) return;
    final next = Map<int, ArchiveProgress>.from(_current)
      ..[chapterId] = ArchiveProgress(done: done, total: total);
    _current = Map<int, ArchiveProgress>.unmodifiable(next);
    _emit();
    _persist();
  }

  void clear(int chapterId) {
    if (!_current.containsKey(chapterId)) return;
    final next = Map<int, ArchiveProgress>.from(_current)..remove(chapterId);
    _current = Map<int, ArchiveProgress>.unmodifiable(next);
    _emit();
    _persist();
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

/// Exposes the archive-packing progress to the UI. A plain [StreamProvider]
/// (not `@riverpod`) so it needs no code generation.
final archiveProgressProvider =
    StreamProvider<Map<int, ArchiveProgress>>((ref) async* {
  final store = ArchiveProgressStore.instance;
  unawaited(store.load());
  yield* store.watch();
}, name: 'archiveProgressProvider');
