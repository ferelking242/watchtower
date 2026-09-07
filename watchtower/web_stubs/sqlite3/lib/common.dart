library sqlite3_common;

import 'dart:convert';
import 'dart:typed_data';

// ── Typedefs ──────────────────────────────────────────────────────────────────

typedef ScalarFunction = Object? Function(List<Object?> arguments);
typedef AggregateFunction<V> = AggregateContext<V> Function();

class AggregateContext<V> {
  V? value;
  AggregateContext();
}

// ── ResultSet ─────────────────────────────────────────────────────────────────

// Row is a Map<String, dynamic> alias so ResultSet.toList() returns
// List<Map<String, dynamic>> as drift expects.
typedef Row = Map<String, dynamic>;

class ResultSet extends Iterable<Map<String, dynamic>> {
  final List<String> columnNames;
  final List<Map<String, dynamic>> rows;
  ResultSet(this.columnNames, this.rows);

  @override
  Iterator<Map<String, dynamic>> get iterator => rows.iterator;
}

// ── Core types ────────────────────────────────────────────────────────────────

/// Stub for sqlite3's CommonDatabase.
/// Drift imports this — must exist so dart2js can resolve the type, even though
/// NativeDatabase is never called on web.
abstract class CommonDatabase {
  String? get filename => null;
  int get lastInsertRowId => 0;
  int get updatedRows => 0;

  int get userVersion;
  set userVersion(int value);

  void execute(String sql, [List<Object?> parameters = const []]);

  CommonPreparedStatement prepare(
    String sql, {
    bool persistent = false,
    bool vtab = true,
    bool checkNoTail = false,
  });

  void createFunction({
    required String functionName,
    required ScalarFunction function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  });

  void createCollation({
    required String name,
    required int Function(String, String) function,
  }) {}

  void createAggregateFunction<V>({
    required String functionName,
    required AggregateFunction<V> function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) {}

  void close();
  void dispose();
}

/// Concrete stub that extends CommonDatabase.
class Database extends CommonDatabase {
  int _userVersion = 0;

  @override
  int get userVersion => _userVersion;

  @override
  set userVersion(int value) {
    _userVersion = value;
  }

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {}

  @override
  CommonPreparedStatement prepare(
    String sql, {
    bool persistent = false,
    bool vtab = true,
    bool checkNoTail = false,
  }) =>
      _PreparedStatement();

  @override
  void createFunction({
    required String functionName,
    required ScalarFunction function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) {}

  @override
  void close() {}

  @override
  void dispose() {}
}

class Sqlite3 {
  String? tempDirectory;
  Database open(String filename, {bool uri = false}) => Database();
  Database openInMemory() => Database();
}

final sqlite3 = Sqlite3();

// ── CommonPreparedStatement ───────────────────────────────────────────────────

abstract class CommonPreparedStatement {
  bool get isExplain => false;
  bool get isExplainQueryPlan => false;
  int get parameterCount => 0;
  List<String?> get parameterNames => [];

  ResultSet select([List<Object?> parameters = const []]);
  void execute([List<Object?> parameters = const []]);
  int executeReturningRowId([List<Object?> parameters = const []]) => 0;
  void reset();
  void close();
  void dispose();
}

class _PreparedStatement extends CommonPreparedStatement {
  @override
  ResultSet select([List<Object?> parameters = const []]) =>
      ResultSet([], <Map<String, dynamic>>[]);

  @override
  void execute([List<Object?> parameters = const []]) {}

  @override
  int executeReturningRowId([List<Object?> parameters = const []]) => 0;

  @override
  void reset() {}

  @override
  void close() {}

  @override
  void dispose() {}
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
