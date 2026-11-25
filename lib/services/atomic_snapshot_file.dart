import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

/// Writes a snapshot to a new sibling file, then replaces the previous file.
///
/// The writer must create a non-empty file at the supplied path. Keeping the
/// existing snapshot untouched until the new copy is complete prevents a
/// failed backup from destroying the last usable snapshot.
Future<void> writeSnapshotAtomically({
  required String destinationPath,
  required Future<void> Function(String path) writeSnapshot,
}) async {
  final stagingFile = File('$destinationPath.pending');
  _deleteQuietly(stagingFile);

  try {
    try {
      await writeSnapshot(stagingFile.path);
    } catch (error) {
      // MDBX refuses to copy onto an existing file. `exists()`/`delete()` are
      // unreliable on shared storage (`/storage/emulated/0/...` under scoped
      // storage): they can report the file as absent while MDBX still sees it,
      // which surfaced as `MdbxError (17): File exists` on the first snapshot
      // after a failed one left its staging file behind. Retry once after an
      // unconditional delete before giving up.
      if (!error.toString().contains('File exists')) rethrow;
      _deleteQuietly(stagingFile);
      await writeSnapshot(stagingFile.path);
    }
    if (!await stagingFile.exists() || await stagingFile.length() == 0) {
      throw StateError('Snapshot writer did not produce a non-empty file');
    }
    await stagingFile.rename(destinationPath);
  } finally {
    _deleteQuietly(stagingFile);
  }
}

void _deleteQuietly(File file) {
  try {
    if (file.existsSync()) file.deleteSync();
  } catch (_) {
    // Preserve the writer/rename error; a stale staging file is harmless.
  }
}
