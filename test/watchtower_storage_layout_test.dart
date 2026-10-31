import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/watchtower_storage_layout.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('watchtower-storage-layout-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'creates canonical app folders without the obsolete plural folder',
    () async {
      await WatchtowerStorageLayout.ensureManagedDirectories(root);

      for (final name in WatchtowerStorageLayout.managedDirectories) {
        expect(await Directory('${root.path}/$name').exists(), isTrue);
      }
      expect(await Directory('${root.path}/downloads').exists(), isFalse);
    },
  );

  test('recreates managed folders after they are deleted', () async {
    await WatchtowerStorageLayout.ensureManagedDirectories(root);
    await Directory('${root.path}/logs').delete(recursive: true);
    await Directory('${root.path}/local').delete(recursive: true);

    await WatchtowerStorageLayout.ensureManagedDirectories(root);

    expect(await Directory('${root.path}/logs').exists(), isTrue);
    expect(await Directory('${root.path}/local').exists(), isTrue);
  });

  test('migrates legacy downloads and preserves conflicting files', () async {
    final canonical = Directory('${root.path}/download')..createSync();
    final legacy = Directory('${root.path}/downloads')..createSync();
    await File('${canonical.path}/video.mp4').writeAsString('current');
    await File('${legacy.path}/video.mp4').writeAsString('legacy');
    await File('${legacy.path}/other.mp4').writeAsString('other');

    await WatchtowerStorageLayout.consolidateLegacyDownloads(root);

    expect(await legacy.exists(), isFalse);
    expect(
      await File('${canonical.path}/video.mp4').readAsString(),
      'current',
    );
    expect(
      await File('${canonical.path}/video (migrated 1).mp4').readAsString(),
      'legacy',
    );
    expect(await File('${canonical.path}/other.mp4').readAsString(), 'other');
  });
}
