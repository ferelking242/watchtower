// Web build stub: dart:ffi not available on Flutter Web
  library sqlite3;

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
  