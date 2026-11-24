import 'dart:io';

import 'package:path/path.dart' as p;

/// Enumerates the source trees of a paste before any byte is copied.
///
/// Runs in a background isolate (`compute`): the walk costs one `stat` per
/// file, and a folder with a few thousand media files blocked the UI long
/// enough to trip the system ANR watchdog when this ran inline. The result is
/// plain strings and ints so it can cross the isolate boundary.
///
/// Each entry describes one top-level clipboard item:
/// `{'path': String, 'kind': 'file'|'dir', 'size': int, 'entries': [...]}`
/// where each child entry is `{'rel': String, 'isDir': bool, 'size': int}`.
List<Map<String, dynamic>> buildPastePlan(List<String> sourcePaths) {
  final plan = <Map<String, dynamic>>[];

  for (final srcPath in sourcePaths) {
    FileSystemEntityType type;
    try {
      type = FileSystemEntity.typeSync(srcPath);
    } catch (_) {
      continue;
    }

    if (type == FileSystemEntityType.file) {
      var size = 0;
      try {
        size = File(srcPath).lengthSync();
      } catch (_) {}
      plan.add({
        'path': srcPath,
        'kind': 'file',
        'size': size,
        'entries': const <Map<String, dynamic>>[],
      });
    } else if (type == FileSystemEntityType.directory) {
      final entries = <Map<String, dynamic>>[];
      var total = 0;
      try {
        final entities = Directory(
          srcPath,
        ).listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          final rel = p.relative(entity.path, from: srcPath);
          if (entity is Directory) {
            entries.add({'rel': rel, 'isDir': true, 'size': 0});
          } else if (entity is File) {
            var size = 0;
            try {
              size = entity.lengthSync();
            } catch (_) {}
            total += size;
            entries.add({'rel': rel, 'isDir': false, 'size': size});
          }
        }
      } catch (_) {}
      plan.add({
        'path': srcPath,
        'kind': 'dir',
        'size': total,
        'entries': entries,
      });
    }
  }

  return plan;
}
