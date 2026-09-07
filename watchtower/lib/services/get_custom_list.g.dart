// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_custom_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getCustomList)
final getCustomListProvider = GetCustomListFamily._();

final class GetCustomListProvider
    extends $FunctionalProvider<AsyncValue<MPages?>, MPages?, FutureOr<MPages?>>
    with $FutureModifier<MPages?>, $FutureProvider<MPages?> {
  GetCustomListProvider._({
    required GetCustomListFamily super.from,
    required ({Source source, String listId, int page}) super.argument,
  }) : super(
         retry: null,
         name: r'getCustomListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getCustomListHash();

  @override
  String toString() {
    return r'getCustomListProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<MPages?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MPages?> create(Ref ref) {
    final argument = this.argument as ({Source source, String listId, int page});
    return getCustomList(ref, source: argument.source, listId: argument.listId, page: argument.page);
  }

  @override
  bool operator ==(Object other) {
    return other is GetCustomListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getCustomListHash() => r'a3c2d1e4f5b6c7d8e9a0b1c2d3e4f5a6b7c8d9e0';

final class GetCustomListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<MPages?>,
          ({Source source, String listId, int page})
        > {
  GetCustomListFamily._()
    : super(
        retry: null,
        name: r'getCustomListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetCustomListProvider call({required Source source, required String listId, required int page}) =>
      GetCustomListProvider._(argument: (source: source, listId: listId, page: page), from: this);

  @override
  String toString() => r'getCustomListProvider';
}
