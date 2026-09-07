// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_indexer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// ignore_for_file: type=lint, type=warning

// ── localIndexerEngine (sync, no params) ─────────────────────────────────────

@ProviderFor(localIndexerEngine)
final localIndexerEngineProvider = LocalIndexerEngineProvider._();

final class LocalIndexerEngineProvider
    extends $FunctionalProvider<IndexerEngine, IndexerEngine, IndexerEngine>
    with $Provider<IndexerEngine> {
  LocalIndexerEngineProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localIndexerEngineProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localIndexerEngineHash();

  @$internal
  @override
  $ProviderElement<IndexerEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IndexerEngine create(Ref ref) {
    return localIndexerEngine(ref);
  }
}

String _$localIndexerEngineHash() => r'localIndexerEngine';

// ── indexerStatus (stream, no params) ────────────────────────────────────────

@ProviderFor(indexerStatus)
final indexerStatusProvider = IndexerStatusProvider._();

final class IndexerStatusProvider
    extends $FunctionalProvider<
        AsyncValue<IndexerStatus>,
        IndexerStatus,
        Stream<IndexerStatus>>
    with $FutureModifier<IndexerStatus>, $StreamProvider<IndexerStatus> {
  IndexerStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'indexerStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$indexerStatusHash();

  @$internal
  @override
  $StreamProviderElement<IndexerStatus> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<IndexerStatus> create(Ref ref) {
    return indexerStatus(ref);
  }
}

String _$indexerStatusHash() => r'indexerStatus';

// ── LocalIndexerScan (class notifier, no params) ────────────────────────────

@ProviderFor(LocalIndexerScan)
final localIndexerScanProvider = LocalIndexerScanProvider._();

final class LocalIndexerScanProvider
    extends $NotifierProvider<LocalIndexerScan, AsyncValue<IndexerStats?>> {
  LocalIndexerScanProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localIndexerScanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localIndexerScanHash();

  @$internal
  @override
  LocalIndexerScan create() => LocalIndexerScan();
}

String _$localIndexerScanHash() => r'localIndexerScan';

abstract class _$LocalIndexerScan extends $Notifier<AsyncValue<IndexerStats?>> {
  AsyncValue<IndexerStats?> build() => const AsyncValue.data(null);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<IndexerStats?>, AsyncValue<IndexerStats?>>;
    final element = ref.element
        as $ClassProviderElement<
            AnyNotifier<AsyncValue<IndexerStats?>, AsyncValue<IndexerStats?>>,
            AsyncValue<IndexerStats?>,
            Object?,
            Object?>;
    element.handleCreate(ref, build);
  }
}

// ── localSearch (family: String query) ──────────────────────────────────────

@ProviderFor(localSearch)
const localSearchProvider = LocalSearchFamily();

final class LocalSearchFamily extends $Family
    with $FunctionalFamilyOverride<List<LocalSearchResult>, String> {
  LocalSearchFamily._()
      : super(
          retry: null,
          name: r'localSearchProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  LocalSearchProvider call(String query) =>
      LocalSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'localSearchProvider';
}

final class LocalSearchProvider
    extends $FunctionalProvider<List<LocalSearchResult>,
        List<LocalSearchResult>, List<LocalSearchResult>>
    with $Provider<List<LocalSearchResult>> {
  LocalSearchProvider._({
    required LocalSearchFamily super.from,
    required String super.argument,
  }) : super(
          retry: null,
          name: r'localSearchProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localSearchHash();

  @override
  String toString() => r'localSearchProvider($argument)';

  @$internal
  @override
  $ProviderElement<List<LocalSearchResult>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<LocalSearchResult> create(Ref ref) {
    final argument = this.argument as String;
    return localSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode => argument.hashCode;
}

String _$localSearchHash() => r'localSearch';

// ── localItemsByKind (family: LocalMediaKind kind) ──────────────────────────

@ProviderFor(localItemsByKind)
const localItemsByKindProvider = LocalItemsByKindFamily();

final class LocalItemsByKindFamily extends $Family
    with $FunctionalFamilyOverride<List<LocalIndexedItem>, LocalMediaKind> {
  LocalItemsByKindFamily._()
      : super(
          retry: null,
          name: r'localItemsByKindProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  LocalItemsByKindProvider call(LocalMediaKind kind) =>
      LocalItemsByKindProvider._(argument: kind, from: this);

  @override
  String toString() => r'localItemsByKindProvider';
}

final class LocalItemsByKindProvider
    extends $FunctionalProvider<List<LocalIndexedItem>,
        List<LocalIndexedItem>, List<LocalIndexedItem>>
    with $Provider<List<LocalIndexedItem>> {
  LocalItemsByKindProvider._({
    required LocalItemsByKindFamily super.from,
    required LocalMediaKind super.argument,
  }) : super(
          retry: null,
          name: r'localItemsByKindProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localItemsByKindHash();

  @override
  String toString() => r'localItemsByKindProvider($argument)';

  @$internal
  @override
  $ProviderElement<List<LocalIndexedItem>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<LocalIndexedItem> create(Ref ref) {
    final argument = this.argument as LocalMediaKind;
    return localItemsByKind(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemsByKindProvider && other.argument == argument;
  }

  @override
  int get hashCode => argument.hashCode;
}

String _$localItemsByKindHash() => r'localItemsByKind';

// ── localItemVariants (family: String canonicalKey) ─────────────────────────

@ProviderFor(localItemVariants)
const localItemVariantsProvider = LocalItemVariantsFamily();

final class LocalItemVariantsFamily extends $Family
    with $FunctionalFamilyOverride<List<LocalIndexedItem>, String> {
  LocalItemVariantsFamily._()
      : super(
          retry: null,
          name: r'localItemVariantsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  LocalItemVariantsProvider call(String canonicalKey) =>
      LocalItemVariantsProvider._(argument: canonicalKey, from: this);

  @override
  String toString() => r'localItemVariantsProvider';
}

final class LocalItemVariantsProvider
    extends $FunctionalProvider<List<LocalIndexedItem>,
        List<LocalIndexedItem>, List<LocalIndexedItem>>
    with $Provider<List<LocalIndexedItem>> {
  LocalItemVariantsProvider._({
    required LocalItemVariantsFamily super.from,
    required String super.argument,
  }) : super(
          retry: null,
          name: r'localItemVariantsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localItemVariantsHash();

  @override
  String toString() => r'localItemVariantsProvider($argument)';

  @$internal
  @override
  $ProviderElement<List<LocalIndexedItem>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<LocalIndexedItem> create(Ref ref) {
    final argument = this.argument as String;
    return localItemVariants(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemVariantsProvider && other.argument == argument;
  }

  @override
  int get hashCode => argument.hashCode;
}

String _$localItemVariantsHash() => r'localItemVariants';

// ── localIndexedCount (Future, no params) ───────────────────────────────────

@ProviderFor(localIndexedCount)
final localIndexedCountProvider = LocalIndexedCountProvider._();

final class LocalIndexedCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  LocalIndexedCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localIndexedCountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localIndexedCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return localIndexedCount(ref);
  }
}

String _$localIndexedCountHash() => r'localIndexedCount';

// ── localIndexedCountByKind (Future, no params) ─────────────────────────────

@ProviderFor(localIndexedCountByKind)
final localIndexedCountByKindProvider = LocalIndexedCountByKindProvider._();

final class LocalIndexedCountByKindProvider
    extends $FunctionalProvider<AsyncValue<Map<LocalMediaKind, int>>,
        Map<LocalMediaKind, int>, FutureOr<Map<LocalMediaKind, int>>>
    with $FutureModifier<Map<LocalMediaKind, int>>, $FutureProvider<Map<LocalMediaKind, int>> {
  LocalIndexedCountByKindProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localIndexedCountByKindProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localIndexedCountByKindHash();

  @$internal
  @override
  $FutureProviderElement<Map<LocalMediaKind, int>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Map<LocalMediaKind, int>> create(Ref ref) {
    return localIndexedCountByKind(ref);
  }
}

String _$localIndexedCountByKindHash() => r'localIndexedCountByKind';

// ── recentlyIndexed (Future, no params) ─────────────────────────────────────

@ProviderFor(recentlyIndexed)
final recentlyIndexedProvider = RecentlyIndexedProvider._();

final class RecentlyIndexedProvider
    extends $FunctionalProvider<AsyncValue<List<LocalIndexedItem>>,
        List<LocalIndexedItem>, FutureOr<List<LocalIndexedItem>>>
    with
        $FutureModifier<List<LocalIndexedItem>>,
        $FutureProvider<List<LocalIndexedItem>> {
  RecentlyIndexedProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recentlyIndexedProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recentlyIndexedHash();

  @$internal
  @override
  $FutureProviderElement<List<LocalIndexedItem>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocalIndexedItem>> create(Ref ref) {
    return recentlyIndexed(ref);
  }
}

String _$recentlyIndexedHash() => r'recentlyIndexed';

// ── localItemByPath (family: String path) ───────────────────────────────────

@ProviderFor(localItemByPath)
const localItemByPathProvider = LocalItemByPathFamily();

final class LocalItemByPathFamily extends $Family
    with $FunctionalFamilyOverride<LocalIndexedItem?, String> {
  LocalItemByPathFamily._()
      : super(
          retry: null,
          name: r'localItemByPathProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  LocalItemByPathProvider call(String path) =>
      LocalItemByPathProvider._(argument: path, from: this);

  @override
  String toString() => r'localItemByPathProvider';
}

final class LocalItemByPathProvider
    extends $FunctionalProvider<AsyncValue<LocalIndexedItem?>,
        LocalIndexedItem?, FutureOr<LocalIndexedItem?>>
    with $FutureModifier<LocalIndexedItem?>, $FutureProvider<LocalIndexedItem?> {
  LocalItemByPathProvider._({
    required LocalItemByPathFamily super.from,
    required String super.argument,
  }) : super(
          retry: null,
          name: r'localItemByPathProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localItemByPathHash();

  @override
  String toString() => r'localItemByPathProvider($argument)';

  @$internal
  @override
  $FutureProviderElement<LocalIndexedItem?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LocalIndexedItem?> create(Ref ref) {
    final argument = this.argument as String;
    return localItemByPath(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalItemByPathProvider && other.argument == argument;
  }

  @override
  int get hashCode => argument.hashCode;
}

String _$localItemByPathHash() => r'localItemByPath';
