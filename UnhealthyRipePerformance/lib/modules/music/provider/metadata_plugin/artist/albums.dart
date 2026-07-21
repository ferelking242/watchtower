import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginArtistAlbumNotifier
    extends FamilyPaginatedAsyncNotifier<SpotubeSimpleAlbumObject, String> {
  @override
  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> fetch(
    int offset,
    int limit,
  ) async {
    return await (await metadataPlugin).artist.albums(
          arg,
          limit: limit,
          offset: offset,
        );
  }

  @override
  build() async {
    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginArtistAlbumsProvider = AsyncNotifierProvider.family<
    MetadataPluginArtistAlbumNotifier,
    SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>,
    String>(
  (a) => MetadataPluginArtistAlbumNotifier()..initFamily(a),
);
