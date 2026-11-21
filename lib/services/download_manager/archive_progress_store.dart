import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';

/// Progress of the second pass that runs after a transfer has finished. Two
/// passes feed it: the archive-packing ("compression") pass that packs every
/// downloaded manga page, and the HLS fragment-assembly pass that concatenates
/// the video fragments and muxes them into the final MP4. It is deliberately
/// kept out of Isar: adding a field to the [Download] collection would change
/// its schema and force Isar to wipe the whole database on the next open.
///
/// The values are mirrored into SharedPreferences so the golden second pass is
/// not lost when the app is backgrounded/restarted, and exposed through a
/// [ValueListenable] so the download queue can render it reactively.
@immutable
class ArchiveProgress {
  final int done;
  final int total;

  /// True when the pass has no measurable unit left (the HLS mux has no cheap
  /// progress source), so the queue animates an indeterminate golden bar
  /// instead of freezing near 100% for the whole mux.
  final bool indeterminate;

  const ArchiveProgress({
    required this.done,
    required this.total,
    this.indeterminate = false,
  });

  /// Null means "no percentage": either indeterminate, or no usable total.
  double? get value =>
      indeterminate || total <= 0 ? null : (done / total).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'done': done,
    'total': total,
    'indeterminate': indeterminate,
  };

  static ArchiveProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final done = (json['done'] as num?)?.toInt();
    final total = (json['total'] as num?)?.toInt();
    if (done == null || total == null || total <= 0) return null;
    return ArchiveProgress(
      done: done,
      total: total,
      indeterminate: json['indeterminate'] == true,
    );
  }

  /// Value equality so a queue card can `select` its own chapter out of the
  /// map: without it every card rebuilds whenever any chapter's pass advances.
  @override
  bool operator ==(Object other) =>
      other is ArchiveProgress &&
      other.done == done &&
      other.total == total &&
      other.indeterminate == indeterminate;

  @override
  int get hashCode => Object.hash(done, total, indeterminate);
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

  /// Loads any progress persisted by a previous session.
  ///
  /// [isLive] tells which chapters have a worker in this process. Only those
  /// entries survive: a marker written by a session that was killed during the
  /// second pass has no pass left to report, and restoring it made the row show
  /// an indeterminate golden bar for the whole download after a cold start.
  /// Entries set during this session are never pruned, because [load] only runs
  /// once per process.
  Future<void> load({bool Function(int chapterId)? isLive}) async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final restored = <int, ArchiveProgress>{};
      var dropped = 0;
      decoded.forEach((key, value) {
        final id = int.tryParse(key.toString());
        final parsed = ArchiveProgress.fromJson(value);
        if (id == null || parsed == null) {
          dropped++;
          return;
        }
        // Keep whatever this process already reported: a pass that started
        // while the preferences were being read is newer than the snapshot.
        if (_current.containsKey(id)) return;
        if (isLive != null && !isLive(id)) {
          dropped++;
          return;
        }
        restored[id] = parsed;
      });
      if (restored.isNotEmpty) {
        _current = Map<int, ArchiveProgress>.unmodifiable({
          ...restored,
          ..._current,
        });
        _emit();
      }
      // Rewrite the snapshot so a stale marker is not re-read next launch.
      // Flushed synchronously: this is a one-shot repair, and delaying it would
      // let the next launch restore the very markers just dropped.
      if (dropped > 0) {
        _persistPending = true;
        await _flushPersist();
      }
    } catch (_) {
      // Persisted progress is best-effort only.
    }
  }

  ArchiveProgress? of(int chapterId) => _current[chapterId];

  /// Drops the in-memory state and re-arms [load] so a test can replay a cold
  /// start. Never called from app code.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _current = const {};
    // A debounce timer armed by a previous test would otherwise fire into the
    // next one, since the store is a process-wide singleton.
    _persistTimer?.cancel();
    _persistTimer = null;
    _persistPending = false;
  }

  void set(
    int chapterId, {
    required int done,
    required int total,
    bool indeterminate = false,
  }) {
    if (total <= 0) return;
    final next = Map<int, ArchiveProgress>.from(_current)
      ..[chapterId] = ArchiveProgress(
        done: done,
        total: total,
        indeterminate: indeterminate,
      );
    _current = Map<int, ArchiveProgress>.unmodifiable(next);
    _emit();
    _persist();
  }

  /// Marks the second pass as running with no measurable unit (the HLS mux):
  /// the queue shows the golden bar as indeterminate until [clear].
  void markIndeterminate(int chapterId) {
    final next = Map<int, ArchiveProgress>.from(_current)
      ..[chapterId] = const ArchiveProgress(
        done: 0,
        total: 1,
        indeterminate: true,
      );
    _current = Map<int, ArchiveProgress>.unmodifiable(next);
    _emit();
    _persist();
  }

  void clear(int chapterId) {
    if (!_current.containsKey(chapterId)) return;
    final next = Map<int, ArchiveProgress>.from(_current)..remove(chapterId);
    _current = Map<int, ArchiveProgress>.unmodifiable(next);
    _emit();
    // Flush instead of debouncing: this is the end of the pass, and a marker
    // left behind by a killed process is exactly what rendered a golden bar
    // over the whole download after a cold start.
    _persistTimer?.cancel();
    _persistTimer = null;
    _persistPending = true;
    unawaited(_flushPersist());
  }

  /// Coalesces the `SharedPreferences` writes.
  ///
  /// [set] is called once per packed page (and per muxed fragment), which for a
  /// 200-page chapter is hundreds of full-map JSON encodes and disk writes on
  /// the platform channel. Only the last snapshot matters, so a short timer
  /// batches them. [clear] flushes immediately: it is the end of the pass and
  /// the marker must not outlive it.
  static const _persistDebounce = Duration(milliseconds: 700);
  Timer? _persistTimer;
  bool _persistPending = false;

  void _persist() {
    _persistPending = true;
    if (_persistTimer?.isActive ?? false) return;
    _persistTimer = Timer(_persistDebounce, () => unawaited(_flushPersist()));
  }

  Future<void> _flushPersist() {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!_persistPending) return Future<void>.value();
    _persistPending = false;
    final payload = <String, dynamic>{
      for (final entry in _current.entries)
        entry.key.toString(): entry.value.toJson(),
    };
    return () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(payload));
      } catch (_) {
        // Best-effort persistence.
      }
    }();
  }

  /// Writes any debounced snapshot now, for tests that need to observe the
  /// persisted value.
  @visibleForTesting
  Future<void> flushForTest() => _flushPersist();
}

/// Exposes the archive-packing progress to the UI. A plain [StreamProvider]
/// (not `@riverpod`) so it needs no code generation.
final archiveProgressProvider =
    StreamProvider<Map<int, ArchiveProgress>>((ref) async* {
  final store = ArchiveProgressStore.instance;
  // A marker persisted by a process that was killed mid-pass must not be
  // restored: no worker is packing that chapter, so the row would render the
  // golden indeterminate bar for the whole download after a cold start.
  unawaited(store.load(isLive: ActiveDownloadRegistry.isActive));
  yield* store.watch();
}, name: 'archiveProgressProvider');
