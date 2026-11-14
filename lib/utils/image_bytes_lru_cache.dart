import 'package:flutter/foundation.dart';

/// LRU cache for byte buffers, bounded by total byte size.
///
/// Two independent image caches need the same eviction policy: the network
/// provider's decoded-source buffer cache and the extension icon cache. Both
/// are measured in bytes rather than entry counts, because a single entry can
/// be anything from a few kilobytes to a few megabytes.
class ImageBytesLruCache<K, V> {
  final int _maxSize;
  final _cache = <K, V>{};
  int _currentSize = 0;
  final int Function(V)? _sizeOf;

  ImageBytesLruCache({required int maxSize, int Function(V)? sizeOf})
    : _maxSize = maxSize,
      _sizeOf = sizeOf;

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void put(K key, V value) {
    final previous = _cache.remove(key);
    if (previous != null && _sizeOf != null) {
      _currentSize -= _sizeOf(previous);
    }
    _cache[key] = value; // Add to end

    if (_sizeOf != null) {
      _currentSize += _sizeOf(value);
      while (_currentSize > _maxSize && _cache.isNotEmpty) {
        final oldest = _cache.entries.first;
        _currentSize -= _sizeOf(oldest.value);
        _cache.remove(oldest.key);
      }
    } else {
      while (_cache.length > _maxSize) {
        _cache.remove(_cache.keys.first);
      }
    }
  }

  void remove(K key) {
    final value = _cache.remove(key);
    if (value != null && _sizeOf != null) {
      _currentSize -= _sizeOf(value);
    }
  }

  void clear() {
    _cache.clear();
    _currentSize = 0;
  }

  int get length => _cache.length;
  int get currentSize => _currentSize;
}

/// Bound used by the extension icon memory cache.
const int kIconMemoryCacheBytes = 8 * 1024 * 1024;

/// A byte-bounded LRU for icon bytes, keyed by the icon cache key.
///
/// Extracted so the icon service and its tests share one implementation.
ImageBytesLruCache<String, Uint8List> createIconMemoryCache() =>
    ImageBytesLruCache<String, Uint8List>(
      maxSize: kIconMemoryCacheBytes,
      sizeOf: (bytes) => bytes.length,
    );
