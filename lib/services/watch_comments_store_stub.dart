/// Comments captured while an episode is downloaded, so the "Commentaires"
/// tab still works offline.
///
/// Web has no application-support directory to write into, and the browser
/// keeps its own HTTP cache for the extension runtime, so these are no-ops.
Future<void> writeWatchComments(
  String title,
  int chapterId,
  List<dynamic> comments,
) async {}

Future<List<dynamic>?> readWatchComments(String title, int chapterId) async =>
    null;

Future<void> clearWatchComments(String title, int chapterId) async {}
