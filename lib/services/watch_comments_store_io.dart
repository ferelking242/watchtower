import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:watchtower/modules/watch/detail/watch_progress_key.dart';

/// Comments captured while an episode is downloaded, so the "Commentaires"
/// tab still works offline.
///
/// The player fetches comments through the extension runtime, which needs the
/// network. Downloading an episode therefore also stores its comments next to
/// the resume state, keyed like the resume file. One file per (title, chapter):
/// a downloaded series keeps the comments of every episode it downloaded.
String _commentsFileName(String title, int chapterId) =>
    'wt_comments_${stableWatchProgressKey(title)}_$chapterId.json';

Future<void> writeWatchComments(
  String title,
  int chapterId,
  List<dynamic> comments,
) async {
  if (comments.isEmpty) return;
  try {
    final dir = await getApplicationSupportDirectory();
    await File(
      '${dir.path}/${_commentsFileName(title, chapterId)}',
    ).writeAsString(
      json.encode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'comments': comments,
      }),
    );
  } catch (_) {}
}

/// Cached comments for [chapterId] of [title], or `null` when the episode was
/// downloaded without any (or never downloaded).
Future<List<dynamic>?> readWatchComments(String title, int chapterId) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/${_commentsFileName(title, chapterId)}');
    if (!await file.exists()) return null;
    final raw = json.decode(await file.readAsString());
    if (raw is! Map) return null;
    final comments = raw['comments'];
    return comments is List ? comments : null;
  } catch (_) {
    return null;
  }
}

Future<void> clearWatchComments(String title, int chapterId) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/${_commentsFileName(title, chapterId)}');
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
