import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/atomic_snapshot_file.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('watchtower-snapshot-');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('replaces the old snapshot after the new copy is complete', () async {
    final destination = File('${directory.path}/watchtowerDb.isar');
    await destination.writeAsString('previous snapshot');

    await writeSnapshotAtomically(
      destinationPath: destination.path,
      writeSnapshot: (path) async {
        expect(await destination.readAsString(), 'previous snapshot');
        await File(path).writeAsString('new snapshot');
      },
    );

    expect(await destination.readAsString(), 'new snapshot');
    expect(await File('${destination.path}.pending').exists(), isFalse);
  });

  test(
    'keeps the previous snapshot when writing the replacement fails',
    () async {
      final destination = File('${directory.path}/watchtowerDb.isar');
      await destination.writeAsString('previous snapshot');

      await expectLater(
        writeSnapshotAtomically(
          destinationPath: destination.path,
          writeSnapshot: (path) async {
            await File(path).writeAsString('partial');
            throw StateError('copy failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(await destination.readAsString(), 'previous snapshot');
      expect(await File('${destination.path}.pending').exists(), isFalse);
    },
  );

  test(
    'rejects an empty replacement without losing the old snapshot',
    () async {
      final destination = File('${directory.path}/watchtowerDb.isar');
      await destination.writeAsString('previous snapshot');

      await expectLater(
        writeSnapshotAtomically(
          destinationPath: destination.path,
          writeSnapshot: (path) async {
            await File(path).create();
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(await destination.readAsString(), 'previous snapshot');
    },
  );
}
