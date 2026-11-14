import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/services/icon_cache_service.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'watchtower-low-memory-test-',
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

  test('onLowMemory empties the in-memory icon cache', () async {
    final cacheDirectory = Directory(
      p.join(documentsDirectory.path, 'icon_cache'),
    )..createSync(recursive: true);
    const url = 'not-a-valid-http-uri';
    await File(
      p.join(cacheDirectory.path, '${IconCacheService.cacheKeyFor(7, url)}.img'),
    ).writeAsBytes(Uint8List.fromList([137, 80, 78, 71, 1]));

    expect(await IconCacheService.instance.getIcon(7, url), isNotNull);
    expect(IconCacheService.instance.memoryEntryCount, 1);

    DeviceCapabilities.onLowMemory();

    expect(IconCacheService.instance.memoryEntryCount, 0);
  });

  test('onLowMemory is safe to call repeatedly and with nothing cached', () {
    expect(() {
      DeviceCapabilities.onLowMemory();
      DeviceCapabilities.onLowMemory();
    }, returnsNormally);
  });

}
