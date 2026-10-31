import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path/path.dart' as path;

/// Canonical directories managed under Watchtower's app data root.
class WatchtowerStorageLayout {
  static const managedDirectories = [
    'download',
    'logs',
    'local',
    'mpv',
    'torrents',
    'tmp',
    'backup',
  ];

  /// Creates the standard app folders. The obsolete plural download folder is
  /// deliberately excluded; its contents are migrated to `download`.
  static Future<void> ensureManagedDirectories(Directory root) async {
    await root.create(recursive: true);
    for (final name in managedDirectories) {
      await Directory(path.join(root.path, name)).create(recursive: true);
    }
  }

  /// Moves existing files from the legacy `downloads` folder into the
  /// canonical `download` folder without overwriting files with matching names.
  static Future<void> consolidateLegacyDownloads(Directory root) async {
    final legacy = Directory(path.join(root.path, 'downloads'));
    if (!await legacy.exists()) return;

    final canonical = Directory(path.join(root.path, 'download'));
    await canonical.create(recursive: true);
    await for (final entry in legacy.list(followLinks: false)) {
      await _moveEntry(entry, canonical);
    }

    // Only remove the obsolete folder after every entry was moved successfully.
    if (await legacy.exists() &&
        await legacy.list(followLinks: false).isEmpty) {
      await legacy.delete();
    }
  }

  static Future<void> _moveEntry(
    FileSystemEntity entry,
    Directory destination,
  ) async {
    final name = path.basename(entry.path);
    var target = path.join(destination.path, name);
    var targetType = await FileSystemEntity.type(
      target,
      followLinks: false,
    );

    if (entry is Directory &&
        targetType == FileSystemEntityType.directory) {
      final targetDirectory = Directory(target);
      await for (final child in entry.list(followLinks: false)) {
        await _moveEntry(child, targetDirectory);
      }
      await entry.delete();
      return;
    }

    if (targetType != FileSystemEntityType.notFound) {
      final extension = entry is File ? path.extension(name) : '';
      final stem = entry is File ? path.basenameWithoutExtension(name) : name;
      var suffix = 1;
      do {
        target = path.join(
          destination.path,
          '$stem (migrated $suffix)$extension',
        );
        targetType = await FileSystemEntity.type(
          target,
          followLinks: false,
        );
        suffix++;
      } while (targetType != FileSystemEntityType.notFound);
    }

    await entry.rename(target);
  }
}
