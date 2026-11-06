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
  if (await stagingFile.exists()) {
    await stagingFile.delete();
  }

  try {
    await writeSnapshot(stagingFile.path);
    if (!await stagingFile.exists() || await stagingFile.length() == 0) {
      throw StateError('Snapshot writer did not produce a non-empty file');
    }
    await stagingFile.rename(destinationPath);
  } finally {
    if (await stagingFile.exists()) {
      try {
        await stagingFile.delete();
      } catch (_) {
        // Preserve the writer/rename error; a stale staging file is harmless.
      }
    }
  }
}
