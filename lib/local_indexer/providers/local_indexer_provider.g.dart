// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_indexer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// ignore_for_file: type=lint, type=warning

@ProviderFor(localIndexerEngine)
final localIndexerEngineProvider =
    AutoDisposeProvider<IndexerEngine>.internal(
  localIndexerEngine,
  name: r'localIndexerEngineProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LocalIndexerEngineRef = AutoDisposeProviderRef<IndexerEngine>;

@ProviderFor(indexerStatus)
final indexerStatusProvider =
    AutoDisposeStreamProvider<IndexerStatus>.internal(
  indexerStatus,
  name: r'indexerStatusProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IndexerStatusRef = AutoDisposeStreamProviderRef<IndexerStatus>;

@ProviderFor(LocalIndexerScan)
final localIndexerScanProvider =
    AutoDisposeNotifierProvider<LocalIndexerScan, AsyncValue<IndexerStats?>>.internal(
  LocalIndexerScan.new,
  name: r'localIndexerScanProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocalIndexerScan
    = AutoDisposeNotifier<AsyncValue<IndexerStats?>>;

@ProviderFor(localSearch)
const localSearchProvider = LocalSearchFamily();

final class LocalSearchFamily extends Family {
  const LocalSearchFamily();

  LocalSearchProvider call(String query) {
    return LocalSearchProvider(query);
  }

  @override
  LocalSearchProvider getProviderOverride(
      covariant LocalSearchProvider provider) {
    return call(provider.argument as String);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localSearchProvider';
}

final class LocalSearchProvider
    extends AutoDisposeProvider<List<LocalSearchResult>> {
  const LocalSearchProvider(String query)
      : this._internal(
          (ref) => localSearch(ref as LocalSearchRef, query),
          from: localSearchProvider,
          name: r'localSearchProvider',
          debugGetCreateSourceHash: null,
          dependencies: LocalSearchFamily._dependencies,
          allTransitiveDependencies:
              LocalSearchFamily._allTransitiveDependencies,
          argument: query,
        );

  LocalSearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required super.argument,
  }) : super.internal();

  @override
  AutoDisposeProvider<List<LocalSearchResult>> copyWithCreate(
    Create<List<LocalSearchResult>, AutoDisposeProviderRef<List<LocalSearchResult>>>
        create,
  ) {
    return LocalSearchProvider._internal(
      create,
      name: name,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      from: from,
      argument: argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocalSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, argument.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef LocalSearchRef
    = AutoDisposeProviderRef<List<LocalSearchResult>>;

@ProviderFor(localItemsByKind)
const localItemsByKindProvider = LocalItemsByKindFamily();

final class LocalItemsByKindFamily extends Family {
  const LocalItemsByKindFamily();

  LocalItemsByKindProvider call(LocalMediaKind kind) {
    return LocalItemsByKindProvider(kind);
  }

  @override
  LocalItemsByKindProvider getProviderOverride(
      covariant LocalItemsByKindProvider provider) {
    return call(provider.argument as LocalMediaKind);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localItemsByKindProvider';
}

final class LocalItemsByKindProvider
    extends AutoDisposeProvider<List<LocalIndexedItem>> {
  const LocalItemsByKindProvider(LocalMediaKind kind)
      : this._internal(
          (ref) => localItemsByKind(ref as LocalItemsByKindRef, kind),
          from: localItemsByKindProvider,
          name: r'localItemsByKindProvider',
          debugGetCreateSourceHash: null,
          dependencies: LocalItemsByKindFamily._dependencies,
          allTransitiveDependencies:
              LocalItemsByKindFamily._allTransitiveDependencies,
          argument: kind,
        );

  LocalItemsByKindProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required super.argument,
  }) : super.internal();

  @override
  AutoDisposeProvider<List<LocalIndexedItem>> copyWithCreate(
    Create<List<LocalIndexedItem>,
            AutoDisposeProviderRef<List<LocalIndexedItem>>>
        create,
  ) {
    return LocalItemsByKindProvider._internal(
      create,
      name: name,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      from: from,
      argument: argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemsByKindProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, argument.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef LocalItemsByKindRef = AutoDisposeProviderRef<List<LocalIndexedItem>>;

@ProviderFor(localItemVariants)
const localItemVariantsProvider = LocalItemVariantsFamily();

final class LocalItemVariantsFamily extends Family {
  const LocalItemVariantsFamily();

  LocalItemVariantsProvider call(String canonicalKey) {
    return LocalItemVariantsProvider(canonicalKey);
  }

  @override
  LocalItemVariantsProvider getProviderOverride(
      covariant LocalItemVariantsProvider provider) {
    return call(provider.argument as String);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localItemVariantsProvider';
}

final class LocalItemVariantsProvider
    extends AutoDisposeProvider<List<LocalIndexedItem>> {
  const LocalItemVariantsProvider(String canonicalKey)
      : this._internal(
          (ref) => localItemVariants(ref as LocalItemVariantsRef, canonicalKey),
          from: localItemVariantsProvider,
          name: r'localItemVariantsProvider',
          debugGetCreateSourceHash: null,
          dependencies: LocalItemVariantsFamily._dependencies,
          allTransitiveDependencies:
              LocalItemVariantsFamily._allTransitiveDependencies,
          argument: canonicalKey,
        );

  LocalItemVariantsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required super.argument,
  }) : super.internal();

  @override
  AutoDisposeProvider<List<LocalIndexedItem>> copyWithCreate(
    Create<List<LocalIndexedItem>,
            AutoDisposeProviderRef<List<LocalIndexedItem>>>
        create,
  ) {
    return LocalItemVariantsProvider._internal(
      create,
      name: name,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      from: from,
      argument: argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemVariantsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, argument.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef LocalItemVariantsRef = AutoDisposeProviderRef<List<LocalIndexedItem>>;

@ProviderFor(localIndexedCount)
final localIndexedCountProvider = AutoDisposeFutureProvider<int>.internal(
  localIndexedCount,
  name: r'localIndexedCountProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LocalIndexedCountRef = AutoDisposeFutureProviderRef<int>;

@ProviderFor(localIndexedCountByKind)
final localIndexedCountByKindProvider =
    AutoDisposeFutureProvider<Map<LocalMediaKind, int>>.internal(
  localIndexedCountByKind,
  name: r'localIndexedCountByKindProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LocalIndexedCountByKindRef
    = AutoDisposeFutureProviderRef<Map<LocalMediaKind, int>>;

@ProviderFor(recentlyIndexed)
final recentlyIndexedProvider =
    AutoDisposeFutureProvider<List<LocalIndexedItem>>.internal(
  recentlyIndexed,
  name: r'recentlyIndexedProvider',
  debugGetCreateSourceHash: null,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecentlyIndexedRef
    = AutoDisposeFutureProviderRef<List<LocalIndexedItem>>;

@ProviderFor(localItemByPath)
const localItemByPathProvider = LocalItemByPathFamily();

final class LocalItemByPathFamily extends Family {
  const LocalItemByPathFamily();

  LocalItemByPathProvider call(String path) {
    return LocalItemByPathProvider(path);
  }

  @override
  LocalItemByPathProvider getProviderOverride(
      covariant LocalItemByPathProvider provider) {
    return call(provider.argument as String);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localItemByPathProvider';
}

final class LocalItemByPathProvider
    extends AutoDisposeFutureProvider<LocalIndexedItem?> {
  const LocalItemByPathProvider(String path)
      : this._internal(
          (ref) => localItemByPath(ref as LocalItemByPathRef, path),
          from: localItemByPathProvider,
          name: r'localItemByPathProvider',
          debugGetCreateSourceHash: null,
          dependencies: LocalItemByPathFamily._dependencies,
          allTransitiveDependencies:
              LocalItemByPathFamily._allTransitiveDependencies,
          argument: path,
        );

  LocalItemByPathProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required super.argument,
  }) : super.internal();

  @override
  AutoDisposeFutureProvider<LocalIndexedItem?> copyWithCreate(
    Create<Future<LocalIndexedItem?>,
            AutoDisposeFutureProviderRef<LocalIndexedItem?>>
        create,
  ) {
    return LocalItemByPathProvider._internal(
      create,
      name: name,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      from: from,
      argument: argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemByPathProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, argument.hashCode);
    return _SystemHash.finish(hash);
  }
}

typedef LocalItemByPathRef = AutoDisposeFutureProviderRef<LocalIndexedItem?>;

// ignore: unused_element
mixin _$LocalIndexerScan on AutoDisposeNotifier<AsyncValue<IndexerStats?>> {
  @override
  AsyncValue<IndexerStats?> build() {
    throw UnimplementedError();
  }
}

class _SystemHash {
  _SystemHash._();
  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
