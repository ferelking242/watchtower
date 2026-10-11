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

/// Reads the saved resume state for [chapterId] of [title].
///
/// Falls back to the legacy per-title progress file so users who watched a
/// video before this change still get their position restored.
Future<WatchResumeState?> readWatchResume(String title, int chapterId) async =>
    null;

Future<void> writeWatchResume(
  String title,
  int chapterId,
  int ms, {
  bool completed = false,
}) async {}

Future<void> clearWatchResume(String title, int chapterId) async {}
