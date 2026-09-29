import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';
import 'package:watchtower/modules/music/services/metadata/metadata.dart';

extension PaginationExtension<T> on AsyncValue<T> {
  bool get isLoadingNextPage => false;
}

mixin MetadataPluginMixin<K>
    on AsyncNotifier<SpotubePaginationResponseObject<K>> {
  Future<MetadataPlugin> get metadataPlugin async {
    final plugin = await ref.read(metadataPluginProvider.future);

    if (plugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    return plugin;
  }
}

extension CacheForExtension on Ref {
  void cacheFor([Duration duration = const Duration(minutes: 5)]) {
    final link = keepAlive();
    final timer = Timer(duration, () => link.close());
    onDispose(() => timer.cancel());
  }
}
