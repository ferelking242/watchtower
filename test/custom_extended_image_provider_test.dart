import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

var _imageId = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheRoot;
  late Directory supportRoot;
  late HttpServer imageServer;
  late int networkRequests;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp(
      'watchtower-image-cache-test-',
    );
    supportRoot = await Directory.systemTemp.createTemp(
      'watchtower-image-support-test-',
    );
    networkRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          if (call.method == 'getApplicationCacheDirectory') {
            return cacheRoot.path;
          }
          if (call.method == 'getApplicationSupportDirectory') {
            return supportRoot.path;
          }
          throw MissingPluginException(
            'Unexpected path_provider call: ${call.method}',
          );
        });
    imageServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    imageServer.listen((request) async {
      networkRequests++;
      request.response
        ..statusCode = HttpStatus.ok
        ..add(Uint8List.fromList([9, 8, 7]));
      await request.response.close();
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    await imageServer.close(force: true);
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
    if (await supportRoot.exists()) await supportRoot.delete(recursive: true);
  });

  CustomExtendedNetworkImageProvider _newProvider({String? url}) {
    final imageUrl =
        url ??
        'http://127.0.0.1:${imageServer.port}/image-${_imageId++}.png';
    return CustomExtendedNetworkImageProvider(
      imageUrl,
      retries: 1,
      timeRetry: Duration.zero,
    );
  }

  Future<File> _writeDiskCache(
    CustomExtendedNetworkImageProvider provider,
    Uint8List bytes,
  ) async {
    final directory = Directory(p.join(supportRoot.path, 'cacheimagecover'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, provider.cacheKeyForTesting));
    await file.writeAsBytes(bytes);
    return file;
  }

  test(
    'providers for the same URL and headers share a stable cache key',
    () async {
      final first = CustomExtendedNetworkImageProvider(
        'https://images.example/cover.jpg',
        headers: const {'Referer': 'https://example.com', 'X-Lang': 'fr'},
      );
      final recreated = CustomExtendedNetworkImageProvider(
        'https://images.example/cover.jpg',
        headers: const {'X-Lang': 'fr', 'Referer': 'https://example.com'},
      );

      final firstKey = await first.obtainKey(ImageConfiguration.empty);
      final recreatedKey = await recreated.obtainKey(ImageConfiguration.empty);

      expect(firstKey, recreatedKey);
      expect(firstKey.hashCode, recreatedKey.hashCode);
      expect(first.cacheKeyForTesting, recreated.cacheKeyForTesting);
    },
  );

  test('disk cache bytes are used without an HTTP request', () async {
    final provider = _newProvider();
    final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
    final cacheFile = await _writeDiskCache(provider, imageBytes);

    expect(await provider.getNetworkImageData(), imageBytes);
    expect(networkRequests, 0);

    await cacheFile.delete();
  });

  test('legacy cover entries are copied out of the OS cache', () async {
    final provider = _newProvider();
    final imageBytes = Uint8List.fromList([3, 4, 5, 6]);
    final legacyDirectory = Directory(
      p.join(cacheRoot.path, 'cacheimagecover'),
    );
    await legacyDirectory.create(recursive: true);
    await File(
      p.join(legacyDirectory.path, provider.cacheKeyForTesting),
    ).writeAsBytes(imageBytes);

    expect(await provider.getNetworkImageData(), imageBytes);
    expect(networkRequests, 0);
    expect(
      await File(
        p.join(
          supportRoot.path,
          'cacheimagecover',
          provider.cacheKeyForTesting,
        ),
      ).exists(),
      isTrue,
    );
  });

  test('an empty cache entry is refetched instead of rendered', () async {
    final provider = _newProvider();
    await _writeDiskCache(provider, Uint8List(0));

    expect(
      await provider.getNetworkImageData(),
      Uint8List.fromList([9, 8, 7]),
    );
    expect(networkRequests, 1);
  });

  test('persistent covers remain available after the OS cache is removed', () async {
    final provider = _newProvider();
    final imageBytes = Uint8List.fromList([4, 5, 6, 7]);
    await _writeDiskCache(provider, imageBytes);
    await cacheRoot.delete(recursive: true);

    final recreated = _newProvider(url: provider.url);
    expect(await recreated.getNetworkImageData(), imageBytes);
    expect(networkRequests, 0);
  });

  test('a recreated provider gets the memory hit without another request', () async {
    final first = _newProvider();
    final imageBytes = Uint8List.fromList([5, 6, 7, 8]);
    final cacheFile = await _writeDiskCache(first, imageBytes);

    expect(await first.getNetworkImageData(), imageBytes);
    await cacheFile.delete();

    final recreated = _newProvider(url: first.url);
    expect(recreated, first);
    expect(await recreated.getNetworkImageData(), imageBytes);
    expect(networkRequests, 0);
  });

  test('replacing an LRU entry does not double-count memory bytes', () {
    final cache = ImageBytesLruCache<String, Uint8List>(
      maxSize: 5,
      sizeOf: (bytes) => bytes.length,
    );
    final replacement = Uint8List.fromList([1, 2, 3]);

    cache.put('cover', Uint8List.fromList([4, 5, 6, 7]));
    cache.put('cover', replacement);

    expect(cache.get('cover'), same(replacement));
    expect(cache.currentSize, replacement.length);
  });
}