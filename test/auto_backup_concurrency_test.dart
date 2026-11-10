import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/services/auto_backup_service.dart';
import 'package:watchtower/utils/mock_isar.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// Counts how many snapshots actually reach the database copy. A concurrent
/// second `backupNow` must never get this far: the two used to share one
/// staging file and the loser's rename failed with errno 2.
class _CountingIsar extends MockIsar {
  int copies = 0;

  @override
  Future<void> copyToFile(String targetPath) async {
    copies++;
    // Widen the window so the old, non-atomic guard would double-run here.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await File(targetPath).writeAsString('snapshot');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDirectory;
  late _CountingIsar countingIsar;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'watchtower-auto-backup-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDirectory.path;
          }
          throw MissingPluginException(
            'Unexpected path_provider call: ${call.method}',
          );
        });
    SharedPreferences.setMockInitialValues({});
    Hive.init(documentsDirectory.path);
    countingIsar = _CountingIsar();
    app.isar = countingIsar;
  });

  tearDown(() async {
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  test(
    'a concurrent second snapshot bails out instead of racing the first',
    () async {
      await Future.wait([
        AutoBackupService.backupNow(force: true),
        AutoBackupService.backupNow(force: true),
      ]);

      expect(countingIsar.copies, 1);
      expect(await AutoBackupService.hasBackup(), isTrue);
    },
  );

  test('a later snapshot runs once the previous one has finished', () async {
    await AutoBackupService.backupNow(force: true);
    await AutoBackupService.backupNow(force: true);

    expect(countingIsar.copies, 2);
  });
}
