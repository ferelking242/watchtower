import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/services/cache_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('watchtower-cache-manager-');
    CacheStorageManager.instance.resetForTesting();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> writeFile(String name, int bytes, {Duration? age}) async {
    final file = File(p.join(root.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    if (age != null) {
      final stamp = DateTime.now().subtract(age);
      await file.setLastModified(stamp);
    }
    return file;
  }

  test('the default ceiling scales with the device RAM tier', () {
    expect(
      CacheStorageManager.defaultLimitForTier('low'),
      lessThan(CacheStorageManager.defaultLimitForTier('mid')),
    );
    expect(
      CacheStorageManager.defaultLimitForTier('mid'),
      lessThan(CacheStorageManager.defaultLimitForTier('high')),
    );
    // The unknown tier falls back to the mid value rather than to zero.
    expect(
      CacheStorageManager.defaultLimitForTier('unknown'),
      CacheStorageManager.defaultLimitForTier('mid'),
    );
  });

  test('eviction deletes the oldest files until the ceiling is met', () async {
    final oldest = await writeFile(
      'old.img',
      400,
      age: const Duration(days: 3),
    );
    final middle = await writeFile(
      'mid.img',
      400,
      age: const Duration(days: 1),
    );
    final newest = await writeFile('new.img', 400);

    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [root],
      overrideLimitBytes: 400,
    );

    expect(await oldest.exists(), isFalse);
    expect(await middle.exists(), isFalse);
    expect(await newest.exists(), isTrue);
  });

  test('eviction reaches files nested in subdirectories', () async {
    // The scan runs on a background isolate, so it must walk the tree by hand
    // rather than rely on a single recursive listing.
    final nestedOld = await writeFile(
      'covers/old.img',
      400,
      age: const Duration(days: 3),
    );
    final nestedNew = await writeFile('covers/new.img', 400);

    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [root],
      overrideLimitBytes: 400,
    );

    expect(await nestedOld.exists(), isFalse);
    expect(await nestedNew.exists(), isTrue);
  });

  test('nothing is deleted while the caches fit under the ceiling', () async {
    final file = await writeFile('cover.img', 100);

    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [root],
      overrideLimitBytes: 10 * 1024 * 1024,
    );

    expect(await file.exists(), isTrue);
  });

  test('the ceiling is global across every location', () async {
    final covers = Directory(p.join(root.path, 'covers'));
    final icons = Directory(p.join(root.path, 'icons'));
    final oldCover = await writeFile(
      'covers/a.img',
      300,
      age: const Duration(days: 2),
    );
    final oldIcon = await writeFile(
      'icons/b.img',
      300,
      age: const Duration(days: 1),
    );
    final newCover = await writeFile('covers/c.img', 300);

    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [covers, icons],
      overrideLimitBytes: 300,
    );

    // Only the newest file survives: each directory is not allowed its own
    // copy of the ceiling.
    expect(await oldCover.exists(), isFalse);
    expect(await oldIcon.exists(), isFalse);
    expect(await newCover.exists(), isTrue);
  });

  test('the scan cooldown suppresses a second pass unless forced', () async {
    await writeFile('a.img', 400, age: const Duration(days: 2));

    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [root],
      overrideLimitBytes: 400,
    );

    // A new oversized file appears within the cooldown window. An unforced
    // scan must not walk the tree again, so the folder stays over budget.
    final extra = await writeFile('b.img', 400);
    await CacheStorageManager.instance.enforceLimit(
      overrideDirectories: [root],
      overrideLimitBytes: 400,
    );
    expect(await extra.exists(), isTrue);
    expect(await CacheStorageManager.instance.directorySize(root), 800);

    // Forcing the scan brings it back under the ceiling.
    await CacheStorageManager.instance.enforceLimit(
      force: true,
      overrideDirectories: [root],
      overrideLimitBytes: 400,
    );
    expect(
      await CacheStorageManager.instance.directorySize(root),
      lessThanOrEqualTo(400),
    );
  });

  test('clearDirectory empties the folder but keeps it in place', () async {
    await writeFile('nested/deep.img', 64);

    await CacheStorageManager.instance.clearDirectory(root);

    expect(await root.exists(), isTrue);
    expect(await root.list().isEmpty, isTrue);
  });
}
