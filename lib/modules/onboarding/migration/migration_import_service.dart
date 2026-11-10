import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/main.dart';
import 'package:watchtower/modules/library/providers/file_scanner.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/mihon_backup.dart';
import 'package:watchtower/modules/more/data_and_storage/providers/restore.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/onboarding/migration/migration_apps.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/log/logger.dart';

/// What an import actually brought in.
class MigrationImportResult {
  const MigrationImportResult({
    this.libraryCount = 0,
    this.downloadCount = 0,
    this.error,
  });

  final int libraryCount;
  final int downloadCount;
  final String? error;

  bool get failed => error != null;
}

/// What a scan found, before anything is written.
class MigrationScanResult {
  const MigrationScanResult({this.libraryCount = 0, this.downloadCount = 0});

  final int libraryCount;
  final int downloadCount;

  bool get isEmpty => libraryCount == 0 && downloadCount == 0;
}

/// Moves a library from another app into Watchtower.
///
/// It deliberately reuses the two import paths the app already trusts instead
/// of inventing new parsers:
///
///  * the library itself goes through [restoreMihonBackupProvider], the reader
///    for the `.tachibk` / `.proto.gz` stream the Mihon family exports, which
///    also restores categories, history, per-manga flags and the settings the
///    backup carries;
///  * the downloaded chapters are copied or moved into Watchtower's `local`
///    library and registered by [scanLocalLibraryProvider], so they open with
///    the normal local reader.
///
/// [MigrationApp.importSupported] decides whether the library half can run, so
/// the page never offers an import it cannot honour.
class MigrationImportService {
  const MigrationImportService();

  /// Counts what [backupPath] and [downloadFolder] hold without writing.
  Future<MigrationScanResult> scan({
    required MigrationApp app,
    String? backupPath,
    String? downloadFolder,
  }) async {
    var libraryCount = 0;
    if (backupPath != null && app.importSupported) {
      libraryCount = await countBackupEntries(backupPath);
    }
    var downloadCount = 0;
    if (downloadFolder != null) {
      downloadCount = await countSeriesFolders(downloadFolder);
    }
    return MigrationScanResult(
      libraryCount: libraryCount,
      downloadCount: downloadCount,
    );
  }

  /// Number of manga entries inside a Mihon-family backup.
  Future<int> countBackupEntries(String path) async {
    if (kIsWeb) return 0;
    try {
      final bytes = await _readBackupBytes(path);
      if (bytes == null) return 0;
      return MihonBackup.parse(bytes).mangas.length;
    } catch (e, s) {
      AppLogger.log(
        'Migration scan failed',
        logLevel: LogLevel.error,
        tag: 'Migration',
        error: e,
        stackTrace: s,
      );
      return 0;
    }
  }

  /// Number of series folders (each holding one or more chapters).
  Future<int> countSeriesFolders(String folder) async {
    if (kIsWeb) return 0;
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) return 0;
      var count = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Runs the import and reports what landed.
  ///
  /// [importLibrary] drives the backup restore; the reader always writes
  /// library, categories, history and settings together, so [importHistory]
  /// and [importSettings] are honoured by trimming what the restore wrote:
  /// history is cleared when it is not wanted, and the pre-import settings are
  /// put back when the app preferences should be left alone.
  Future<MigrationImportResult> run({
    required WidgetRef ref,
    required MigrationApp app,
    required bool importLibrary,
    required bool importHistory,
    required bool importSettings,
    required bool importDownloads,
    required bool moveFiles,
    String? backupPath,
    String? downloadFolder,
  }) async {
    var libraryCount = 0;
    var downloadCount = 0;

    // ── Library ───────────────────────────────────────────────────────────
    if (importLibrary && backupPath != null && app.importSupported) {
      final previousSettings = importSettings
          ? null
          : isar.settings.getSync(kSettingsId);
      final before = await isar.mangas.count();
      ref.read(restoreMihonBackupProvider(backupPath));
      if (!importHistory) {
        isar.writeTxnSync(() => isar.historys.clearSync());
      }
      if (previousSettings != null) {
        isar.writeTxnSync(() => isar.settings.putSync(previousSettings));
      }
      // The restore merges into whatever the library already holds, so the
      // honest figure is the growth, not the new total.
      libraryCount = (await isar.mangas.count()) - before;
    }

    // ── Downloads ─────────────────────────────────────────────────────────
    if (importDownloads && downloadFolder != null) {
      downloadCount = await _importDownloads(
        ref: ref,
        downloadFolder: downloadFolder,
        moveFiles: moveFiles,
      );
    }

    return MigrationImportResult(
      libraryCount: libraryCount,
      downloadCount: downloadCount,
    );
  }

  /// Copies or moves every series folder into `local/`, then rescans so the
  /// entries become part of the library.
  Future<int> _importDownloads({
    required WidgetRef ref,
    required String downloadFolder,
    required bool moveFiles,
  }) async {
    if (kIsWeb) return 0;
    final source = Directory(downloadFolder);
    if (!await source.exists()) return 0;

    final local = await getLocalLibrary();
    if (local == null) return 0;
    await local.create(recursive: true);

    var imported = 0;
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      final destination = Directory(p.join(local.path, name));
      try {
        if (entity is Directory) {
          if (await _hasContent(entity)) {
            await _transferDirectory(entity, destination, moveFiles);
            imported++;
          }
        } else if (entity is File) {
          // A loose archive (`<series>.cbz`) is one series of one chapter.
          final stem = p.basenameWithoutExtension(name);
          final seriesDir = Directory(p.join(local.path, stem));
          await seriesDir.create(recursive: true);
          await _transferFile(
            entity,
            File(p.join(seriesDir.path, name)),
            moveFiles,
          );
          imported++;
        }
      } catch (e, s) {
        AppLogger.log(
          'Migration download transfer failed for $name',
          logLevel: LogLevel.error,
          tag: 'Migration',
          error: e,
          stackTrace: s,
        );
      }
    }

    if (imported > 0) {
      await ref.read(scanLocalLibraryProvider.future);
    }
    return imported;
  }

  Future<bool> _hasContent(Directory dir) async {
    try {
      await for (final _ in dir.list(followLinks: false)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _transferDirectory(
    Directory source,
    Directory destination,
    bool move,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final target = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _transferDirectory(entity, Directory(target), move);
      } else if (entity is File) {
        await _transferFile(entity, File(target), move);
      }
    }
    if (move) {
      // Only remove the source once every entry moved out of it.
      try {
        await source.delete();
      } catch (_) {}
    }
  }

  Future<void> _transferFile(File source, File destination, bool move) async {
    if (move) {
      try {
        await source.rename(destination.path);
        return;
      } catch (_) {
        // Cross-device moves cannot rename; fall through to copy + delete.
      }
    }
    await source.copy(destination.path);
    if (move) {
      try {
        await source.delete();
      } catch (_) {}
    }
  }

  /// Reads a backup and returns its gunzipped protobuf bytes, or null.
  Future<Uint8List?> _readBackupBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final raw = await file.readAsBytes();
    if (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b) {
      return Uint8List.fromList(GZipDecoder().decodeBytes(raw));
    }
    return raw;
  }
}
