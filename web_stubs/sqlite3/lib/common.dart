library sqlite3_common;
import 'dart:convert';
import 'dart:typed_data';

class Database {
  void execute(String sql, [List<Object?> parameters = const []]) {}
  void dispose() {}
}

class Sqlite3 {
  String? tempDirectory;
  Database open(String filename, {bool uri = false}) => Database();
  Database openInMemory() => Database();
}

class DatabaseTracker {
  final Sqlite3 _sqlite3;
  DatabaseTracker(this._sqlite3);
  void markOpened(String path, Database db) {}
  void markClosed(Database db) {}
  void closeExisting() {}
}

DatabaseTracker tracker(Sqlite3 s) => DatabaseTracker(s);
final sqlite3 = Sqlite3();

class SqliteException implements Exception {
  final int extendedResultCode;
  final String message;
  final String? explanation;
  SqliteException(this.extendedResultCode, this.message, [this.explanation]);
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
