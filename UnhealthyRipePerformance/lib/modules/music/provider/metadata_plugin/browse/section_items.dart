import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginBrowseSectionItemsNotifier
    extends FamilyPaginatedAsyncNotifier<Object, String> {
  @override
  Future<SpotubePaginationResponseObject<Object>> fetch(
    int offset,
    int limit,
  ) async {
    return await (await metadataPlugin).browse.sectionItems(
          arg,
          limit: limit,
          offset: offset,
        );
  }

  @override
  build() async {
    ref.watch(metadataPluginAuthenticatedProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginBrowseSectionItemsProvider = AsyncNotifierProvider.family<
    MetadataPluginBrowseSectionItemsNotifier,
    SpotubePaginationResponseObject<Object>,
    String>(
  (a) => MetadataPluginBrowseSectionItemsNotifier()..initFamily(a),
);
