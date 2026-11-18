import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:watchtower/modules/watch/detail/watch_progress_key.dart';

/// Per-episode resume state for the watch player.
///
/// The old player only stored a single position per title, which meant the
/// History list could not tell whether an episode had actually been finished.
/// We persist one record per (title, chapter) pair so History can resume the
/// exact episode *and* the exact timestamp.
class WatchResumeState {
  final int ms;
  final bool completed;

  const WatchResumeState({this.ms = 0, this.completed = false});
}

String _resumeFileName(String title, int chapterId) =>
    'wt_resume_${stableWatchProgressKey(title)}_$chapterId.json';

/// Reads the saved resume state for [chapterId] of [title].
///
/// Falls back to the legacy per-title progress file so users who watched a
/// video before this change still get their position restored.
Future<WatchResumeState?> readWatchResume(String title, int chapterId) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/${_resumeFileName(title, chapterId)}');
    if (await file.exists()) {
      final raw = json.decode(await file.readAsString()) as Map;
      return WatchResumeState(
        ms: (raw['ms'] as num?)?.toInt() ?? 0,
        completed: raw['completed'] == true,
      );
    }
    // Legacy fallback (only meaningful for the first episode).
    final legacy = File(
      '${dir.path}/wt_progress_${stableWatchProgressKey(title)}.json',
    );
    if (await legacy.exists()) {
      final raw = json.decode(await legacy.readAsString()) as Map;
      final ms = (raw['ms'] as num?)?.toInt() ?? 0;
      if (ms > 0) return WatchResumeState(ms: ms);
    }
  } catch (_) {}
  return null;
}

Future<void> writeWatchResume(
  String title,
  int chapterId,
  int ms, {
  bool completed = false,
}) async {
  try {
    final dir = await getApplicationSupportDirectory();
    await File(
      '${dir.path}/${_resumeFileName(title, chapterId)}',
    ).writeAsString(
      json.encode({
        'ms': ms,
        'completed': completed,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  } catch (_) {}
}

Future<void> clearWatchResume(String title, int chapterId) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/${_resumeFileName(title, chapterId)}');
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// Most recent per-episode resume record for [title], across all its episodes.
///
/// Used when the detail page is opened from the Library (no explicit episode):
/// the player must resume the exact episode *and* timestamp the user left,
/// which the History page already carries but a plain Library tap does not.
/// Returns `null` when nothing was watched yet.
Future<({int chapterId, int ms})?> latestWatchResume(String title) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final prefix = 'wt_resume_${stableWatchProgressKey(title)}_';
    int? bestChapter;
    int bestMs = 0;
    int bestSavedAt = -1;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(prefix) || !name.endsWith('.json')) continue;
      final idPart = name.substring(prefix.length, name.length - 5);
      final chapterId = int.tryParse(idPart);
      if (chapterId == null) continue;
      try {
        final raw = json.decode(await entity.readAsString()) as Map;
        final ms = (raw['ms'] as num?)?.toInt() ?? 0;
        final savedAt = (raw['savedAt'] as num?)?.toInt() ?? 0;
        if (ms <= 0 || raw['completed'] == true) continue;
        if (savedAt >= bestSavedAt) {
          bestSavedAt = savedAt;
          bestChapter = chapterId;
          bestMs = ms;
        }
      } catch (_) {}
    }
    if (bestChapter == null) return null;
    return (chapterId: bestChapter, ms: bestMs);
  } catch (_) {}
  return null;
}
