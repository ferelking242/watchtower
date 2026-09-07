import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_view.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_create_dialog.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/components/fallbacks/anonymous_fallback.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_card.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/user.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

class UserPlaylistsPage extends HookConsumerWidget {
  static const name = 'user_playlists';
  const UserPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchText = useState('');

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    final me = ref.watch(metadataPluginUserProvider);
    final playlistsQuery = ref.watch(metadataPluginSavedPlaylistsProvider);
    final playlistsQueryNotifier =
        ref.watch(metadataPluginSavedPlaylistsProvider.notifier);

    final likedTracksPlaylist = useMemoized(
      () => me.asData?.value == null
          ? null
          : SpotubeSimplePlaylistObject(
              id: "user-liked-tracks",
              name: context.l10n.liked_tracks,
              description: context.l10n.liked_tracks_description,
              externalUri: "",
              owner: me.asData!.value!,
              images: [
                SpotubeImageObject(
                  url: Assets.images.likedTracks.path,
                  width: 300,
                  height: 300,
                )
              ]),
      [context.l10n, me.asData?.value],
    );

    final playlists = useMemoized(
      () {
        if (searchText.value.isEmpty) {
          return [
            if (likedTracksPlaylist != null) likedTracksPlaylist,
            ...?playlistsQuery.asData?.value.items,
          ];
        }
        return [
          if (likedTracksPlaylist != null) likedTracksPlaylist,
          ...?playlistsQuery.asData?.value.items,
        ]
            .map((e) => (weightedRatio(e.name, searchText.value), e))
            .sorted((a, b) => b.$1.compareTo(a.$1))
            .where((e) => e.$1 > 50)
            .map((e) => e.$2)
            .toList();
      },
      [playlistsQuery, searchText.value],
    );

    final controller = useScrollController();

    if (playlistsQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true) {
      return const AnonymousFallback();
    }

    if (playlistsQuery.hasError) {
      return ErrorBox(
        error: playlistsQuery.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSavedPlaylistsProvider);
        },
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(metadataPluginSavedPlaylistsProvider);
      },
      child: SafeArea(
        bottom: false,
        child: InterScrollbar(
          controller: controller,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                floating: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      onChanged: (value) => searchText.value = value,
                      decoration: InputDecoration(
                        hintText: context.l10n.filter_playlists,
                        prefixIcon: const Icon(SpotubeIcons.filter),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: PlaybuttonView(
                  leading: const Expanded(
                    child: Row(
                      children: [
                        PlaylistCreateDialogButton(),
                      ],
                    ),
                  ),
                  controller: controller,
                  hasMore: playlistsQuery.asData?.value.hasMore == true,
                  isLoading: playlistsQuery.isLoading,
                  onRequestMore: playlistsQueryNotifier.fetchMore,
                  itemCount: playlists.length,
                  gridItemBuilder: (context, index) {
                    return PlaylistCard(playlists[index]);
                  },
                  listItemBuilder: (context, index) {
                    return PlaylistCard.tile(playlists[index]);
                  },
                ),
              ),
              const SliverSafeArea(
                sliver: SliverToBoxAdapter(child: SizedBox(height: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
