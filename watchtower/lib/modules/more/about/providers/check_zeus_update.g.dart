// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_zeus_update.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(zeusLatestRelease)
final zeusLatestReleaseProvider = ZeusLatestReleaseProvider._();

final class ZeusLatestReleaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ZeusRelease?>,
          ZeusRelease?,
          FutureOr<ZeusRelease?>
        >
    with $FutureModifier<ZeusRelease?>, $FutureProvider<ZeusRelease?> {
  ZeusLatestReleaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zeusLatestReleaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zeusLatestReleaseHash();

  @$internal
  @override
  $FutureProviderElement<ZeusRelease?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ZeusRelease?> create(Ref ref) {
    return zeusLatestRelease(ref);
  }
}

String _$zeusLatestReleaseHash() =>
    r'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
