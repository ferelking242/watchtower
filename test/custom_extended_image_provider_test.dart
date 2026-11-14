import 'dart:io';

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

  test('rotating credentials do not change the cache key', () async {
    final withToken = CustomExtendedNetworkImageProvider(
      'https://images.example/cover.jpg',
      headers: const {
        'Referer': 'https://example.com',
        'Authorization': 'Bearer token-one',
        'Cookie': 'session=abc',
      },
    );
    final rotated = CustomExtendedNetworkImageProvider(
      'https://images.example/cover.jpg',
      headers: const {
        'Referer': 'https://example.com',
        'Authorization': 'Bearer token-two',
        'Cookie': 'session=def',
      },
    );

    // A rotating token used to make every cover miss its own entry and
    // re-download forever; the stable parts of the fingerprint are what
    // identify the image.
    expect(withToken.cacheKeyForTesting, rotated.cacheKeyForTesting);
  });

  test('a non-credential header still separates two cache entries', () async {
    final french = CustomExtendedNetworkImageProvider(
      'https://images.example/cover.jpg',
      headers: const {'Referer': 'https://example.com', 'X-Lang': 'fr'},
    );
    final english = CustomExtendedNetworkImageProvider(
      'https://images.example/cover.jpg',
      headers: const {'Referer': 'https://example.com', 'X-Lang': 'en'},
    );

    expect(french.cacheKeyForTesting, isNot(english.cacheKeyForTesting));
  });

  test('a rotating URL token does not change the cache key', () {
    final first = CustomExtendedNetworkImageProvider(
      'https://cdn.test/cover.jpg?token=one&expires=1700000000&w=400',
    );
    final rotated = CustomExtendedNetworkImageProvider(
      'https://cdn.test/cover.jpg?token=two&expires=1700009999&w=400',
    );

    // A signed CDN URL rotates its credentials and expiry on every request;
    // keying on the raw URL made every cover miss the entry it just wrote.
    expect(first.cacheKeyForTesting, rotated.cacheKeyForTesting);
  });

  test('a query parameter that selects the resource still splits the key', () {
    final small = CustomExtendedNetworkImageProvider(
      'https://cdn.test/cover.jpg?w=200',
    );
    final large = CustomExtendedNetworkImageProvider(
      'https://cdn.test/cover.jpg?w=800',
    );

    expect(small.cacheKeyForTesting, isNot(large.cacheKeyForTesting));
  });

  test(
    'an expired persistent cover renders from disk instead of a placeholder',
    () async {
      final provider = CustomExtendedNetworkImageProvider(
        'http://127.0.0.1:${imageServer.port}/cover.png',
        retries: 1,
        timeRetry: Duration.zero,
        // Everything written before "now" is immediately expired.
        cacheMaxAge: Duration.zero,
      );
      final imageBytes = Uint8List.fromList([11, 12, 13, 14]);
      final cacheFile = await _writeDiskCache(provider, imageBytes);

      // The stale entry is returned straight away; revalidation happens in the
      // background and, with the network blocked, leaves the file in place.
      expect(await provider.getNetworkImageData(), imageBytes);
      expect(await cacheFile.exists(), isTrue);
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

  test('an empty cache entry is discarded instead of rendered', () async {
    final provider = _newProvider();
    final cacheFile = await _writeDiskCache(provider, Uint8List(0));

    // TestWidgetsFlutterBinding blocks real HTTP requests. The empty cached
    // bytes must still be rejected, and the production code then retries.
    expect(await provider.getNetworkImageData(), isNull);
    expect(await cacheFile.exists(), isFalse);
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
