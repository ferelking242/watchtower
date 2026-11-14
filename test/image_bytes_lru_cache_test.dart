import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/image_bytes_lru_cache.dart';

void main() {
  Uint8List bytes(int length) => Uint8List(length);

  test('evicts the least recently used entry once the byte budget is hit', () {
    final cache = ImageBytesLruCache<String, Uint8List>(
      maxSize: 30,
      sizeOf: (value) => value.length,
    );

    cache.put('a', bytes(10));
    cache.put('b', bytes(10));
    cache.put('c', bytes(10));
    expect(cache.currentSize, 30);

    // Reading 'a' makes 'b' the oldest, so the next insert must drop 'b'.
    expect(cache.get('a'), isNotNull);
    cache.put('d', bytes(10));

    expect(cache.get('b'), isNull);
    expect(cache.get('a'), isNotNull);
    expect(cache.get('c'), isNotNull);
    expect(cache.get('d'), isNotNull);
    expect(cache.currentSize, lessThanOrEqualTo(30));
  });

  test('replacing a key does not double-count its bytes', () {
    final cache = ImageBytesLruCache<String, Uint8List>(
      maxSize: 100,
      sizeOf: (value) => value.length,
    );

    cache.put('a', bytes(40));
    cache.put('a', bytes(10));

    expect(cache.length, 1);
    expect(cache.currentSize, 10);
  });

  test('remove and clear keep the running size in sync', () {
    final cache = ImageBytesLruCache<String, Uint8List>(
      maxSize: 100,
      sizeOf: (value) => value.length,
    );

    cache.put('a', bytes(20));
    cache.put('b', bytes(30));
    cache.remove('a');
    expect(cache.currentSize, 30);

    cache.clear();
    expect(cache.currentSize, 0);
    expect(cache.length, 0);
  });

  test('the icon memory cache is bounded to a few megabytes', () {
    final cache = createIconMemoryCache();
    expect(kIconMemoryCacheBytes, lessThanOrEqualTo(16 * 1024 * 1024));

    // 2 MB per icon: the fifth insert has to push the total back under 8 MB.
    for (var i = 0; i < 5; i++) {
      cache.put('icon$i', bytes(2 * 1024 * 1024));
    }

    expect(cache.currentSize, lessThanOrEqualTo(kIconMemoryCacheBytes));
    expect(cache.length, lessThan(5));
  });
}
