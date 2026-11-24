import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';

/// Outcome of [IsarOpenGuard.prepareOpen].
enum IsarOpenRecovery {
  /// The database matches the schema and the previous launch finished opening.
  none,

  /// The on-disk database was built from a different schema, so it was moved
  /// aside before opening.
  schemaChanged,

  /// The previous launch died inside `Isar.open`, so the database was moved
  /// aside before opening.
  abortedOpen,

  /// The previous launch died inside `Isar.open` again right after a repair.
  /// The database is kept so a crash that is not database-related cannot wipe
  /// it on every launch.
  repeatedAbortedOpen,
}

/// Keeps the Isar open path from bricking the app.
///
/// `isar_community` copies the native property offsets into a buffer sized by
/// the *Dart* schema (`_getOffsets` in `open.dart`). When the on-disk schema no
/// longer matches the schema handed to `Isar.open` the native side can write
/// past that buffer; Scudo then reports a corrupted chunk header and the
/// process dies with SIGABRT at the next `free`. Dart cannot catch that, so a
/// single poisoned database means a crash loop on every launch.
///
/// The guard keeps three small files next to the database:
///  * `<name>.schema_fingerprint` — hash of the schema passed to `Isar.open`;
///  * `<name>.open_inflight` — present only while an open is running;
///  * `<name>.open_failures` — launches that died inside an open.
///
/// A database built from another schema, or one that killed the previous
/// launch, is moved to `<dir>/isar-quarantine/` instead of being opened, so the
/// app always boots. Files are renamed rather than deleted so a user can still
/// recover the data manually.
class IsarOpenGuard {
  IsarOpenGuard(this.directory, {this.name = 'watchtowerDb', String salt = ''})
    : _salt = salt;

  static const List<String> _dbSuffixes = ['.isar', '.isar.lock', '.isar.tmp'];
  static const String _quarantineDirName = 'isar-quarantine';

  /// Number of quarantined database sets kept on disk.
  static const int _maxQuarantined = 2;

  /// Name of the file that records the schema a database was opened with.
  static String fingerprintFileName(String databaseName) =>
      '$databaseName.schema_fingerprint';

  /// Directory that holds the database files.
  final Directory directory;

  /// Database name passed to `Isar.open`.
  final String name;

  /// Extra value folded into the fingerprint so a manual version bump still
  /// forces a fresh database.
  final String _salt;

  File get _fingerprintFile =>
      File('${directory.path}/${fingerprintFileName(name)}');
  File get _legacyVersionFile => File('${directory.path}/$name.schema_version');
  File get _inflightFile => File('${directory.path}/$name.open_inflight');
  File get _failuresFile => File('${directory.path}/$name.open_failures');

  /// Stable hash of everything `Isar.open` receives: collection names and ids,
  /// property names, types and targets, indexes and links. Sorted, so a
  /// regenerated file with a different declaration order is not a schema
  /// change.
  static String fingerprint(
    List<CollectionSchema<dynamic>> schemas, {
    String salt = '',
  }) {
    final collections = <String>[];
    for (final schema in schemas) {
      final properties =
          schema.properties.values
              .map((p) => '${p.name}:${p.type.schemaName}:${p.target ?? ''}')
              .toList()
            ..sort();
      final indexes = schema.indexes.values.map((index) {
        final indexProperties =
            index.properties
                .map((p) => '${p.name}:${p.type.name}:${p.caseSensitive}')
                .toList()
              ..sort();
        return '${index.name}:${index.unique}:${index.replace}:'
            '${indexProperties.join(',')}';
      }).toList()..sort();
      final links =
          schema.links.values
              .map(
                (l) => '${l.name}:${l.target}:${l.single}:${l.linkName ?? ''}',
              )
              .toList()
            ..sort();
      final embedded =
          schema.embeddedSchemas.values.map((e) => '${e.name}:${e.id}').toList()
            ..sort();
      collections.add(
        '${schema.name}#${schema.id}'
        '{p[${properties.join(';')}]'
        'i[${indexes.join(';')}]'
        'l[${links.join(';')}]'
        'e[${embedded.join(';')}]}',
      );
    }
    collections.sort();
    final payload = '$salt|${collections.join('|')}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Repairs whatever a previous launch left behind. Call once before the first
  /// `Isar.open`.
  Future<IsarOpenRecovery> prepareOpen(
    List<CollectionSchema<dynamic>> schemas,
  ) async {
    final current = fingerprint(schemas, salt: _salt);
    try {
      var failures = _readCount(await _read(_failuresFile));
      if (await _inflightFile.exists()) {
        // The previous process died between markOpening() and openSucceeded().
        failures += 1;
        await _delete(_inflightFile);
        await _write(_failuresFile, '$failures');
      }

      if (failures > 1) {
        return IsarOpenRecovery.repeatedAbortedOpen;
      }
      if (failures == 1 && await _quarantine('aborted-open') != null) {
        await _write(_fingerprintFile, current);
        return IsarOpenRecovery.abortedOpen;
      }

      // Snapshots taken before the fingerprint existed still carry the manual
      // version string; honour it so a restore cannot bring back a database
      // from another schema.
      if (_salt.isNotEmpty) {
        final storedVersion = await _read(_legacyVersionFile);
        if (storedVersion != null && storedVersion != _salt) {
          final moved = await _quarantine('schema-version');
          await _write(_legacyVersionFile, _salt);
          await _write(_fingerprintFile, current);
          if (moved != null) return IsarOpenRecovery.schemaChanged;
        }
      }

      final stored = await _read(_fingerprintFile);
      if (stored == null) {
        // First launch of a build that has this guard: adopt the schema on
        // disk instead of wiping a database that the manual version gate
        // already validated.
        await _write(_fingerprintFile, current);
      } else if (stored != current) {
        final moved = await _quarantine('schema-change');
        await _write(_fingerprintFile, current);
        if (moved != null) return IsarOpenRecovery.schemaChanged;
      }
      return IsarOpenRecovery.none;
    } catch (_) {
      // A guard failure must never block the app from opening its database.
      return IsarOpenRecovery.none;
    }
  }

  /// Records that an open is running. Left behind if the process dies.
  Future<void> markOpening() async {
    try {
      await _write(_inflightFile, DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  /// Clears the in-flight marker and the crash counter after a successful open.
  Future<void> openSucceeded() async {
    try {
      await _delete(_inflightFile);
      await _delete(_failuresFile);
    } catch (_) {}
  }

  /// Clears the in-flight marker after an open that failed with a Dart error.
  /// Such a failure is handled by the caller and must not count as a crash.
  Future<void> openFailed() async {
    try {
      await _delete(_inflightFile);
    } catch (_) {}
  }

  /// Moves the database files into a timestamped quarantine directory.
  /// Returns the directory used, or null when there was nothing to move.
  Future<String?> _quarantine(String reason) async {
    final root = Directory('${directory.path}/$_quarantineDirName');
    await root.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp('[^0-9]'),
      '',
    );
    final target = Directory('${root.path}/${stamp}_$reason');
    await target.create(recursive: true);

    var moved = 0;
    for (final suffix in _dbSuffixes) {
      final file = File('${directory.path}/$name$suffix');
      if (!await file.exists()) continue;
      await file.rename('${target.path}/$name$suffix');
      moved++;
    }

    if (moved == 0) {
      await _deleteDirectory(target);
      return null;
    }
    await _pruneQuarantine(root);
    return target.path;
  }

  Future<void> _pruneQuarantine(Directory root) async {
    try {
      final entries = await root.list().where((e) => e is Directory).toList();
      entries.sort((a, b) => b.path.compareTo(a.path));
      for (final entry in entries.skip(_maxQuarantined)) {
        await _deleteDirectory(entry);
      }
    } catch (_) {}
  }

  Future<void> _deleteDirectory(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } catch (_) {}
  }

  Future<String?> _read(File file) async {
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _write(File file, String value) async {
    await file.writeAsString(value, flush: true);
  }

  Future<void> _delete(File file) async {
    if (await file.exists()) await file.delete();
  }

  static int _readCount(String? value) => int.tryParse(value ?? '') ?? 0;
}
