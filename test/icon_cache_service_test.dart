import 'dart:io';
import 'dart:typed_data';

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
}
