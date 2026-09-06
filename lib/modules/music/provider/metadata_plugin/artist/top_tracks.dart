import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';

class MetadataPluginArtistTopTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeFullTrackObject,
        String> {
  MetadataPluginArtistTopTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).artist.topTracks(
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

final metadataPluginArtistTopTracksProvider =
    AsyncNotifierProvider.family<
        MetadataPluginArtistTopTracksNotifier,
        SpotubePaginationResponseObject<SpotubeFullTrackObject>,
        String>(
  (a) => MetadataPluginArtistTopTracksNotifier()..initFamily(a),
);
