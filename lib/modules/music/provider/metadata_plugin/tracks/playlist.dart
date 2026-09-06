import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';

class MetadataPluginPlaylistTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeFullTrackObject,
        String> {
  MetadataPluginPlaylistTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).playlist.tracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  @override
  build() async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginPlaylistTracksProvider =
    AsyncNotifierProvider.family<MetadataPluginPlaylistTracksNotifier,
        SpotubePaginationResponseObject<SpotubeFullTrackObject>, String>(
  (a) => MetadataPluginPlaylistTracksNotifier()..initFamily(a),
);
