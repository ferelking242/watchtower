import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Automatic, uninstall-surviving snapshot of everything the app needs to
/// come back intact after a reinstall: the Isar database (library, settings,
/// extensions, history, downloads, categories, custom buttons), the Hive
/// preference boxes and SharedPreferences.
///
/// Layout: the snapshot lives in a hidden `.backup` folder at the root of the
/// canonical Watchtower storage folder — the same folder that already holds
/// `download/`, `logs/`, `local/`, `backup/`… On Android that root is
/// `/storage/emulated/0/watchtower/`, which is external storage and therefore
/// survives an app uninstall. Reinstalling and relaunching the app restores
/// the snapshot before the database is opened, so nothing is lost.
///
/// The folder is the single source of truth the user is told about in
/// Settings → Sauvegarde automatique.
class AutoBackupService {
  AutoBackupService._();

  /// Hidden cache folder holding the automatic snapshot, at the storage root.
  static const String backupDirName = '.backup';

  static const String _isarFileName = 'watchtowerDb.isar';
  static const String _schemaVersionFileName = 'watchtowerDb.schema_version';
  static const String _hiveSnapshotName = 'hive_boxes.json';
  static const String _prefsSnapshotName = 'shared_preferences.json';
  static const String _manifestName = 'manifest.json';

  static const String _enabledKey = 'watchtower_auto_backup_enabled';
  static const String _lastBackupKey = 'watchtower_auto_backup_last';

  /// Hive boxes the app opens; snapshotted by name so a restore recreates the
  /// exact preference state on a fresh install.
  static const List<String> _hiveBoxes = [
    'nav_display',
    'ui_prefs',
    'library_settings',
    'reader_prefs',
    'player_prefs',
    'advanced_settings',
    'tracker_library',
  ];

  static Timer? _periodicTimer;
  static bool _backupInFlight = false;

  /// Set by [restoreOnFreshInstall] when a snapshot was applied, so the Hive
  /// restore that runs later in the boot sequence only fires on a fresh
  /// install and never overwrites live preferences on a normal launch.
  static bool _freshInstallRestorePending = false;

  // ─── Public state ───────────────────────────────────────────────────────────

  /// Whether automatic backup is enabled (default: on).
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      if (value) {
        unawaited(backupNow());
      }
    } catch (error) {
      AppLogger.log(
        'AutoBackup: could not persist enabled flag',
        logLevel: LogLevel.warning,
        tag: LogTag.maintenance,
        error: error,
      );
    }
  }

  /// Timestamp of the most recent successful snapshot, or null.
  static Future<DateTime?> lastBackupTime() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_lastBackupKey);
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {
      return null;
    }
  }

  /// Absolute path of the snapshot folder, or null when unavailable.
  static Future<String?> backupDirectoryPath() async {
    final dir = await _backupDirectory(create: false);
    return dir?.path;
  }

  /// Whether a restorable snapshot exists on disk.
  static Future<bool> hasBackup() async {
    if (kIsWeb) return false;
    try {
      final dir = await _backupDirectory(create: false);
      if (dir == null) return false;
      return File(p.join(dir.path, _isarFileName)).existsSync();
    } catch (_) {
      return false;
    }
  }

  // ─── Directory resolution ───────────────────────────────────────────────────

  static Future<Directory?> _backupDirectory({required bool create}) async {
    if (kIsWeb) return null;
    try {
      final root = await StorageProvider().getDefaultDirectory();
      if (root == null) return null;
      final dir = Directory(p.join(root.path, backupDirName));
      if (create && !dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (error) {
      AppLogger.log(
        'AutoBackup: could not resolve backup directory',
        logLevel: LogLevel.warning,
        tag: LogTag.maintenance,
        error: error,
      );
      return null;
    }
  }

  // ─── Fresh-install restore ──────────────────────────────────────────────────

  /// Returns true when the Isar database file does not exist yet, i.e. the app
  /// was just (re)installed and has no live data to protect.
  static Future<bool> isFreshInstall() async {
    if (kIsWeb) return false;
    try {
      final dbDir = await StorageProvider().getDatabaseDirectory();
      if (dbDir == null) return false;
      return !File(p.join(dbDir.path, _isarFileName)).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Restores the snapshot into the live locations. Must be called *before*
  /// the Isar database is opened on a fresh install: the database file is put
  /// back on disk so `Isar.open` reads the restored data directly. Hive boxes
  /// cannot be restored yet (Hive is not initialised), so call
  /// [restoreHiveBoxes] after `Hive.initFlutter`.
  ///
  /// Returns true when a snapshot was found and applied.
  static Future<bool> restoreOnFreshInstall() async {
    if (kIsWeb) return false;
    if (!await isFreshInstall()) return false;
    final dir = await _backupDirectory(create: false);
    if (dir == null) return false;

    final isarBackup = File(p.join(dir.path, _isarFileName));
    if (!isarBackup.existsSync()) return false;

    try {
      // 1 — Isar database file.
      final dbDir = await StorageProvider().getDatabaseDirectory();
      if (dbDir == null) return false;
      await dbDir.create(recursive: true);
      await isarBackup.copy(p.join(dbDir.path, _isarFileName));

      final versionBackup = File(p.join(dir.path, _schemaVersionFileName));
      if (versionBackup.existsSync()) {
        await versionBackup.copy(p.join(dbDir.path, _schemaVersionFileName));
      }

      // 2 — SharedPreferences (safe to restore before the UI starts).
      await _restorePreferences(dir);

      _freshInstallRestorePending = true;

      AppLogger.log(
        'AutoBackup: restored database + preferences from ${dir.path}',
        logLevel: LogLevel.info,
        tag: LogTag.maintenance,
      );
      return true;
    } catch (error, stack) {
      AppLogger.log(
        'AutoBackup: restore on fresh install failed',
        logLevel: LogLevel.error,
        tag: LogTag.maintenance,
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Restores the Hive preference boxes. Call after `Hive.initFlutter` and
  /// after the boxes are opened. No-op unless a fresh-install restore was
  /// applied, so live preferences are never overwritten on a normal launch.
  static Future<void> restoreHiveBoxes() async {
    if (kIsWeb) return;
    if (!_freshInstallRestorePending) return;
    _freshInstallRestorePending = false;
    final dir = await _backupDirectory(create: false);
    if (dir == null) return;
    try {
      await _restoreHive(dir);
    } catch (error) {
      AppLogger.log(
        'AutoBackup: Hive restore failed',
        logLevel: LogLevel.warning,
        tag: LogTag.maintenance,
        error: error,
      );
    }
  }

  // ─── Snapshot ───────────────────────────────────────────────────────────────

  /// Writes a fresh snapshot of the database, Hive boxes and preferences.
  static Future<void> backupNow() async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    if (_backupInFlight) return;
    _backupInFlight = true;
    try {
      final dir = await _backupDirectory(create: true);
      if (dir == null) return;

      // 1 — Isar database file. copyToFile is safe while the DB is open.
      await isar.copyToFile(p.join(dir.path, _isarFileName));

      final dbDir = await StorageProvider().getDatabaseDirectory();
      if (dbDir != null) {
        final versionFile = File(p.join(dbDir.path, _schemaVersionFileName));
        if (versionFile.existsSync()) {
          await versionFile.copy(p.join(dir.path, _schemaVersionFileName));
        }
      }

      // 2 — Hive preference boxes.
      await _snapshotHive(dir);

      // 3 — SharedPreferences.
      await _snapshotPreferences(dir);

      // 4 — Manifest (timestamp + app version) for the settings screen.
      final manifest = File(p.join(dir.path, _manifestName));
      await manifest.writeAsString(
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': 1,
        }),
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}

      AppLogger.log(
        'AutoBackup: snapshot written to ${dir.path}',
        logLevel: LogLevel.debug,
        tag: LogTag.maintenance,
      );
    } catch (error, stack) {
      AppLogger.log(
        'AutoBackup: snapshot failed',
        logLevel: LogLevel.warning,
        tag: LogTag.maintenance,
        error: error,
        stackTrace: stack,
      );
    } finally {
      _backupInFlight = false;
    }
  }

  /// Manual restore of the snapshot over the live data. Used from the settings
  /// screen; the app must be restarted afterwards for the database to reload.
  static Future<bool> restoreNow() async {
    if (kIsWeb) return false;
    final dir = await _backupDirectory(create: false);
    if (dir == null) return false;
    if (!File(p.join(dir.path, _isarFileName)).existsSync()) return false;
    try {
      await _restoreHive(dir);
      await _restorePreferences(dir);
      return true;
    } catch (error) {
      AppLogger.log(
        'AutoBackup: manual restore failed',
        logLevel: LogLevel.error,
        tag: LogTag.maintenance,
        error: error,
      );
      return false;
    }
  }

  /// Starts the periodic snapshot and returns the initial one.
  static Future<void> startAutoBackup() async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(backupNow()),
    );
    unawaited(backupNow());
  }

  static void stopAutoBackup() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // ─── Hive snapshot / restore ────────────────────────────────────────────────

  static Future<void> _snapshotHive(Directory dir) async {
    final data = <String, Map<String, dynamic>>{};
    for (final name in _hiveBoxes) {
      try {
        final box = await Hive.openBox(name);
        final map = <String, dynamic>{};
        for (final key in box.keys) {
          final value = box.get(key);
          map['$key'] = _jsonSafe(value);
        }
        data[name] = map;
      } catch (error) {
        AppLogger.log(
          'AutoBackup: skipped Hive box "$name"',
          logLevel: LogLevel.debug,
          tag: LogTag.maintenance,
          error: error,
        );
      }
    }
    final file = File(p.join(dir.path, _hiveSnapshotName));
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> _restoreHive(Directory dir) async {
    final file = File(p.join(dir.path, _hiveSnapshotName));
    if (!file.existsSync()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      try {
        final box = await Hive.openBox('${entry.key}');
        final values = entry.value;
        if (values is Map) {
          await box.clear();
          for (final value in values.entries) {
            await box.put('${value.key}', value.value);
          }
        }
      } catch (error) {
        AppLogger.log(
          'AutoBackup: could not restore Hive box "${entry.key}"',
          logLevel: LogLevel.warning,
          tag: LogTag.maintenance,
          error: error,
        );
      }
    }
  }

  // ─── SharedPreferences snapshot / restore ───────────────────────────────────

  static Future<void> _snapshotPreferences(Directory dir) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key == _lastBackupKey) continue;
      data[key] = _jsonSafe(prefs.get(key));
    }
    final file = File(p.join(dir.path, _prefsSnapshotName));
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> _restorePreferences(Directory dir) async {
    final file = File(p.join(dir.path, _prefsSnapshotName));
    if (!file.existsSync()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in decoded.entries) {
      final key = '${entry.key}';
      if (key == _lastBackupKey) continue;
      final value = entry.value;
      try {
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.map((e) => '$e').toList());
        }
      } catch (error) {
        AppLogger.log(
          'AutoBackup: could not restore preference "$key"',
          logLevel: LogLevel.debug,
          tag: LogTag.maintenance,
          error: error,
        );
      }
    }
  }

  /// Coerces a stored value into something JSON can encode. Values that cannot
  /// be represented (custom objects) are dropped rather than failing the whole
  /// snapshot.
  static dynamic _jsonSafe(dynamic value) {
    if (value == null ||
        value is bool ||
        value is int ||
        value is double ||
        value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_jsonSafe).toList();
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final safe = _jsonSafe(entry.value);
        if (safe != null) result['${entry.key}'] = safe;
      }
      return result;
    }
    return value.toString();
  }
}
