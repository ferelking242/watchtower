import 'database.dart';

Future<Database> openDatabase(
  String path, {
  int? version,
  dynamic onCreate,
  dynamic onUpgrade,
  dynamic onDowngrade,
  dynamic onOpen,
  bool? readOnly,
  bool? singleInstance,
}) async =>
    throw UnsupportedError('sqflite not available on Flutter Web');

Future<void> deleteDatabase(String path) async =>
    throw UnsupportedError('sqflite not available on Flutter Web');

Future<String> getDatabasesPath() async =>
    throw UnsupportedError('sqflite not available on Flutter Web');
