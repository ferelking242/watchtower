import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor createDatabaseConnection() => WebDatabase('watchtower');