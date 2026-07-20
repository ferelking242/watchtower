library sqlite3_common;

import 'dart:convert';
import 'dart:typed_data';

// ── Core types ────────────────────────────────────────────────────────────────

/// Stub for sqlite3's CommonDatabase.
/// Drift's sqlite3/database.dart imports this — must exist so dart2js can
/// resolve the type, even though NativeDatabase is never called on web.
abstract class CommonDatabase {
  String? get filename => null;
  int get lastInsertRowId => 0;
  int get updatedRows => 0;
  void execute(String sql, [List<Object?> parameters = const []]);
  void dispose();
}

/// Concrete stub that extends CommonDatabase (for the Database.open() return type).
class Database extends CommonDatabase {
  @override
  void execute(String sql, [List<Object?> parameters = const []]) {}
  @override
  void dispose() {}
}

class Sqlite3 {
  String? tempDirectory;
  Database open(String filename, {bool uri = false}) => Database();
  Database openInMemory() => Database();
}

final sqlite3 = Sqlite3();

// ── Types used by drift/src/sqlite3/database.dart ────────────────────────────

/// Stub for sqlite3's CommonPreparedStatement.
abstract class CommonPreparedStatement {
  void dispose();
  void reset();
}

// ── Types used by drift/src/sqlite3/native_functions.dart ───────────────────

/// AllowedArgumentCount — must support const constructor so drift's
/// `const AllowedArgumentCount(2)` compiles.
class AllowedArgumentCount {
  final int lowerBound;
  final int upperBound;
  const AllowedArgumentCount(int count) : lowerBound = count, upperBound = count;
  const AllowedArgumentCount.between(this.lowerBound, this.upperBound);
  const AllowedArgumentCount.any() : lowerBound = 0, upperBound = -1;
}

// NOTE: DatabaseTracker intentionally omitted.
// Drift defines its own DatabaseTracker in drift/src/sqlite3/database_tracker.dart.
// Exporting it here causes a duplicate-symbol error.

// ── Exceptions & codecs ───────────────────────────────────────────────────────

class SqliteException implements Exception {
  final int extendedResultCode;
  final String message;
  final String? explanation;
  const SqliteException(this.extendedResultCode, this.message, [this.explanation]);
  @override
  String toString() => 'SqliteException($extendedResultCode): $message';
}

class _JsonbEncoder extends Converter<Object?, Uint8List> {
  const _JsonbEncoder();
  @override
  Uint8List convert(Object? input) => Uint8List(0);
}

class _JsonbDecoder extends Converter<Uint8List, Object?> {
  const _JsonbDecoder();
  @override
  Object? convert(Uint8List input) => null;
}

class _JsonbCodec extends Codec<Object?, Uint8List> {
  const _JsonbCodec();
  @override
  Converter<Object?, Uint8List> get encoder => const _JsonbEncoder();
  @override
  Converter<Uint8List, Object?> get decoder => const _JsonbDecoder();
}

const Codec<Object?, Uint8List> jsonb = _JsonbCodec();
