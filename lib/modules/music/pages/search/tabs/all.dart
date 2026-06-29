import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/modules/search/loading.dart';
import 'package:watchtower/modules/music/pages/search/search.dart';
import 'package:watchtower/modules/music/modules/search/sections/albums.dart';
import 'package:watchtower/modules/music/modules/search/sections/artists.dart';
import 'package:watchtower/modules/music/modules/search/sections/playlists.dart';
import 'package:watchtower/modules/music/modules/search/sections/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/all.dart';

class SearchPageAllTab extends HookConsumerWidget {
  const SearchPageAllTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = ScrollController();
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchSnapshot =
        ref.watch(metadataPluginSearchAllProvider(searchTerm));

    if (searchSnapshot.hasError) {
      return ErrorBox(
        error: searchSnapshot.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSearchAllProvider(searchTerm));
        },
      );
    }

    return SearchPlaceholder(
      snapshot: searchSnapshot,
      child: InterScrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchTracksSection(),
                  SearchPlaylistsSection(),
                  SizedBox(height: 20),
                  SearchArtistsSection(),
                  SizedBox(height: 20),
                  SearchAlbumsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
