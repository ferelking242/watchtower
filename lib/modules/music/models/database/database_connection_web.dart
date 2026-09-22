import 'package:drift/drift.dart';

/// The web build intentionally does not ship sqlite3/WASM. Keep the generated
/// Drift database usable for compilation and let the web-specific providers
/// operate on empty results until a browser storage backend is supplied.
QueryExecutor createDatabaseConnection() => LazyDatabase(
      () async => _WebDatabaseExecutor(),
    );

class _WebDatabaseExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async =>
      <Map<String, Object?>>[];

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runCustom(
    String statement, [
    List<Object?>? args,
  ]) async {}

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  TransactionExecutor beginTransaction() => _WebTransactionExecutor();

  @override
  QueryExecutor beginExclusive() => this;
}

class _WebTransactionExecutor extends _WebDatabaseExecutor
    implements TransactionExecutor {
  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}
}