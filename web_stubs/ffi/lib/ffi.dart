/// Web stub for package:ffi. All operations throw UnsupportedError at runtime.
  library ffi;

  abstract class Allocator {
    dynamic allocate<T>(int numBytes, {int? alignment});
    void free(dynamic pointer);
  }

  class _MallocAllocator implements Allocator {
    const _MallocAllocator();
    dynamic allocate<T>(int numBytes, {int? alignment}) =>
        throw UnsupportedError('malloc/calloc not available on web');
    void free(dynamic pointer) =>
        throw UnsupportedError('malloc/calloc not available on web');
  }

  const Allocator malloc = _MallocAllocator();
  const Allocator calloc = _MallocAllocator();

  class Arena implements Allocator {
    final Allocator _allocator;
    Arena([Allocator? allocator]) : _allocator = allocator ?? malloc;
    dynamic allocate<T>(int numBytes, {int? alignment}) =>
        _allocator.allocate<T>(numBytes, alignment: alignment);
    void free(dynamic pointer) => _allocator.free(pointer);
    void releaseAll({bool reuse = false}) {}
  }

  T using<T>(T Function(Arena) computation, [Allocator? allocator]) =>
      computation(Arena(allocator));

  extension StringUtf8Pointer on String {
    dynamic toNativeUtf8({Allocator? allocator}) =>
        throw UnsupportedError('toNativeUtf8 not available on web');
    int get utf8Length => length;
  }

  extension Utf8Pointer on dynamic {
    String toDartString({int? length}) => '';
    int get length => 0;
  }

  extension StringUtf16Pointer on String {
    dynamic toNativeUtf16({Allocator? allocator}) =>
        throw UnsupportedError('toNativeUtf16 not available on web');
  }

  extension Utf16Pointer on dynamic {
    String toDartString({int? length}) => '';
  }
  