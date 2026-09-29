import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/paginated.dart';

class MetadataPluginBrowseSectionsNotifier
    extends PaginatedAsyncNotifier<SpotubeBrowseSectionObject<Object>> {
  @override
  Future<SpotubePaginationResponseObject<SpotubeBrowseSectionObject<Object>>>
      fetch(
    int offset,
    int limit,
  ) async {
    return await (await metadataPlugin).browse.sections(
          limit: limit,
          offset: offset,
        );
  }

  @override
  build() async {
    // Watch both providers: metadataPluginAuthenticatedProvider alone is not
    // enough because it returns `false` in both "no plugin" and "plugin
    // without auth" states — so the value never changes and downstream
    // providers never re-evaluate after bundled plugins finish installing.
    ref.watch(metadataPluginAuthenticatedProvider);
    ref.watch(metadataPluginsProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginBrowseSectionsProvider = AsyncNotifierProvider<
    MetadataPluginBrowseSectionsNotifier,
    SpotubePaginationResponseObject<SpotubeBrowseSectionObject<Object>>>(
  () => MetadataPluginBrowseSectionsNotifier(),
);
