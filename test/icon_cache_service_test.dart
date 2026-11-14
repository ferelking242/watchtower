import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/services/icon_cache_service.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'watchtower-icon-cache-test-',
    );
    IconCacheService.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDirectory.path;
          }
          throw MissingPluginException(
            'Unexpected path_provider call: ${call.method}',
          );
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  test('uses a deterministic cache key for an extension icon URL', () {
    const url = 'https://extensions.example/icon.png';

    expect(
      IconCacheService.cacheKeyFor(18, url),
      IconCacheService.cacheKeyFor(18, url),
    );
    expect(
      IconCacheService.cacheKeyFor(18, url),
      isNot(IconCacheService.cacheKeyFor(18, '$url?revision=2')),
    );
  });

  test('a version bump changes the cache key for the same icon URL', () {
    const url = 'https://extensions.example/icon.png';

    // An extension that ships new artwork usually keeps its icon URL, so the
    // installed version has to take part in the key or the old image would be
    // served forever.
    expect(
      IconCacheService.cacheKeyFor(18, url, '1.0.0'),
      isNot(IconCacheService.cacheKeyFor(18, url, '2.0.0')),
    );
    // An absent or blank version falls back to the URL-only key.
    expect(
      IconCacheService.cacheKeyFor(18, url),
      IconCacheService.cacheKeyFor(18, url, '   '),
    );
    // Different extensions never collide.
    expect(
      IconCacheService.cacheKeyFor(18, url, '1.0.0'),
      isNot(IconCacheService.cacheKeyFor(19, url, '1.0.0')),
    );
  });

  test(
    'reads persistent icons offline and migrates old cache filenames',
    () async {
      final cacheDirectory = Directory(
        p.join(documentsDirectory.path, 'icon_cache'),
      )..createSync(recursive: true);
      final service = IconCacheService.instance;
      const url = 'not-a-valid-http-uri';
      final savedBytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

      final stableKey = IconCacheService.cacheKeyFor(81, url);
      await File(p.join(cacheDirectory.path, '$stableKey.img')).writeAsBytes(
        savedBytes,
      );
      expect(await service.getIcon(81, url), savedBytes);

      final legacyBytes = Uint8List.fromList([255, 216, 255, 4, 5, 6]);
      await File(
        p.join(cacheDirectory.path, 'icon_82_123456.png'),
      ).writeAsBytes(legacyBytes);
      expect(await service.getIcon(82, url), legacyBytes);
      expect(
        await File(
          p.join(
            cacheDirectory.path,
            '${IconCacheService.cacheKeyFor(82, url)}.img',
          ),
        ).readAsBytes(),
        legacyBytes,
      );
    },
  );

  test('clearMemory drops the in-memory copy but keeps the disk one', () async {
    final cacheDirectory = Directory(
      p.join(documentsDirectory.path, 'icon_cache'),
    )..createSync(recursive: true);
    final service = IconCacheService.instance;
    const url = 'not-a-valid-http-uri';
    final savedBytes = Uint8List.fromList([137, 80, 78, 71, 9, 9, 9]);
    final stableFile = File(
      p.join(cacheDirectory.path, '${IconCacheService.cacheKeyFor(90, url)}.img'),
    );
    await stableFile.writeAsBytes(savedBytes);

    expect(await service.getIcon(90, url), savedBytes);

    service.clearMemory();

    // A second read still resolves the same bytes — from disk, not the network.
    expect(await service.getIcon(90, url), savedBytes);
    expect(await stableFile.exists(), isTrue);
  });
}
