abstract class Database {
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]);
  Future<List<Map<String, dynamic>>> query(String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
  Future<int> rawInsert(String sql, [List<dynamic>? args]);
  Future<int> rawUpdate(String sql, [List<dynamic>? args]);
  Future<int> rawDelete(String sql, [List<dynamic>? args]);
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, dynamic conflictAlgorithm});
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs, dynamic conflictAlgorithm});
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs});
  Future<void> execute(String sql, [List<dynamic>? args]);
  Future<void> close();
  Future<T> transaction<T>(Future<T> Function(dynamic txn) action, {bool? exclusive});
}
