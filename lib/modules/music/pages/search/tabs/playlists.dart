import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_view.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_card.dart';
import 'package:watchtower/modules/music/modules/search/loading.dart';
import 'package:watchtower/modules/music/pages/search/search.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/playlists.dart';

class SearchPagePlaylistsTab extends HookConsumerWidget {
  const SearchPagePlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchPlaylistsSnapshot =
        ref.watch(metadataPluginSearchPlaylistsProvider(searchTerm));
    final searchPlaylistsNotifier =
        ref.read(metadataPluginSearchPlaylistsProvider(searchTerm).notifier);
    final searchPlaylists = searchPlaylistsSnapshot.isLoading
        ? [FakeData.playlistSimple]
        : (searchPlaylistsSnapshot.asData?.value.items ?? []);

    if (searchPlaylistsSnapshot.hasError) {
      return ErrorBox(
        error: searchPlaylistsSnapshot.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSearchPlaylistsProvider(searchTerm));
        },
      );
    }

    return SearchPlaceholder(
      snapshot: searchPlaylistsSnapshot,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            PlaybuttonView(
              controller: controller,
              itemCount: searchPlaylists.length,
              hasMore: searchPlaylistsSnapshot.asData?.value.hasMore == true,
              isLoading: searchPlaylistsSnapshot.isLoading,
              onRequestMore: searchPlaylistsNotifier.fetchMore,
              gridItemBuilder: (context, index) =>
                  PlaylistCard(searchPlaylists[index]),
              listItemBuilder: (context, index) =>
                  PlaylistCard.tile(searchPlaylists[index]),
            ),
          ],
        ),
      ),
    );
  }
}
