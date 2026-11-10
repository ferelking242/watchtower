import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/onboarding/migration/migration_apps.dart';

/// A backup file and/or download folder found on this device for one app.
class DetectedAppData {
  const DetectedAppData({this.backupPath, this.downloadFolder});

  final String? backupPath;
  final String? downloadFolder;

  bool get isEmpty => backupPath == null && downloadFolder == null;

  /// One line describing what was found, translated for [l10n].
  String summary(AppLocalizations l10n) {
    final parts = <String>[];
    if (backupPath != null) parts.add(l10n.migDetectedBackup);
    if (downloadFolder != null) parts.add(l10n.migDetectedDownloads);
    if (parts.isEmpty) return l10n.migNoDetectedApps;
    return parts.join('  ·  ');
  }
}

/// Looks for the leftovers of the other apps on this device.
///
/// Detection is best-effort and read-only: it walks a short list of well-known
/// folders and reports what exists, so the migration page can pre-select the
/// files it found instead of asking the user to browse for them. A miss costs
/// nothing — the user can always pick the file by hand.
class MigrationDetector {
  const MigrationDetector();

  /// Root folders worth walking, per platform.
  static const List<String> _androidRoots = ['/storage/emulated/0', '/sdcard'];

  /// Sub-paths (relative to a root) that hold another app's backups.
  static const Map<String, List<String>> _backupFolders = {
    'mihon': ['Mihon/backup', 'Mihon/automatic_backup'],
    'tachiyomisy': ['TachiyomiSY/backup', 'TachiyomiSY/automatic_backup'],
    'aniyomi': ['Aniyomi/backup', 'Aniyomi/automatic_backup'],
    'komikku': ['Komikku/backup', 'Komikku/automatic_backup'],
    'neko': ['Neko/backup'],
    'mangayomi': ['Mangayomi/backup'],
    'kotatsu': ['Kotatsu/backup'],
    'lnreader': ['LNReader/backup'],
    'tsundoku': ['Tsundoku/backup'],
    'kototoro': ['Kototoro/backup'],
  };

  /// Sub-paths (relative to a root) that hold downloaded chapters.
  static const Map<String, List<String>> _downloadFolders = {
    'mihon': ['Mihon/downloads', 'Mihon/local'],
    'tachiyomisy': ['TachiyomiSY/downloads'],
    'aniyomi': ['Aniyomi/downloads', 'Aniyomi/local'],
    'komikku': ['Komikku/downloads'],
    'neko': ['Neko/downloads'],
    'mangayomi': ['Mangayomi/downloads'],
    'lnreader': ['LNReader/downloads'],
    'tsundoku': ['Tsundoku/downloads'],
  };

  /// The extensions a Mihon-family backup may use.
  static const Set<String> _backupExtensions = {'.tachibk', '.proto.gz'};

  /// Returns the data found for each app, keyed by [MigrationApp.id].
  Future<Map<String, DetectedAppData>> detect() async {
    if (kIsWeb) return const {};
    final result = <String, DetectedAppData>{};

    final roots = await _candidateRoots();
    for (final app in migrationApps) {
      final backup = await _findBackup(app.id, roots);
      final downloads = await _findDownloadFolder(app.id, roots);
      if (backup == null && downloads == null) continue;
      result[app.id] = DetectedAppData(
        backupPath: backup,
        downloadFolder: downloads,
      );
    }
    return result;
  }

  /// The roots to walk: the fixed Android roots plus the app's own external
  /// directory, which is where a sibling app's files are actually reachable
  /// without a storage permission prompt.
  Future<List<String>> _candidateRoots() async {
    final roots = <String>[];
    if (Platform.isAndroid) roots.addAll(_androidRoots);
    // Desktop: the user's home directory is where these clients write.
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) roots.add(home);
    return roots.where((r) => r.isNotEmpty).toSet().toList();
  }

  Future<String?> _findBackup(String appId, List<String> roots) async {
    final folders = _backupFolders[appId];
    if (folders == null) return null;
    for (final root in roots) {
      for (final folder in folders) {
        final file = await _newestBackupIn(p.join(root, folder));
        if (file != null) return file;
      }
    }
    return null;
  }

  /// The most recently written backup in [folder], or null.
  Future<String?> _newestBackupIn(String folder) async {
    final dir = Directory(folder);
    if (!await dir.exists()) return null;
    String? newest;
    DateTime? newestAt;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        final matches = _backupExtensions.any((ext) => name.endsWith(ext));
        if (!matches) continue;
        final stat = await entity.stat();
        if (newestAt == null || stat.modified.isAfter(newestAt)) {
          newestAt = stat.modified;
          newest = entity.path;
        }
      }
    } catch (_) {}
    return newest;
  }

  Future<String?> _findDownloadFolder(String appId, List<String> roots) async {
    final folders = _downloadFolders[appId];
    if (folders == null) return null;
    for (final root in roots) {
      for (final folder in folders) {
        final path = p.join(root, folder);
        try {
          if (await Directory(path).exists()) return path;
        } catch (_) {}
      }
    }
    return null;
  }
}
