import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/modules/stats/common/playlist_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class StatsPlaylistsPage extends HookConsumerWidget {
  static const name = "stats_playlists";
  const StatsPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topPlaylists =
        ref.watch(historyTopPlaylistsProvider(HistoryDuration.allTime));

    final topPlaylistsNotifier = ref
        .watch(historyTopPlaylistsProvider(HistoryDuration.allTime).notifier);

    final playlistsData = topPlaylists.asData?.value.items ?? [];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.playlists),
          ),
        body: Skeletonizer(enabled: topPlaylists.isLoading && !topPlaylists.isLoadingNextPage,
          child: InfiniteList(
            onFetchData: () async {
              await topPlaylistsNotifier.fetchMore();
            },
            hasError: topPlaylists.hasError,
            isLoading:
                topPlaylists.isLoading && !topPlaylists.isLoadingNextPage,
            hasReachedMax: topPlaylists.asData?.value.hasMore ?? true,
            itemCount: playlistsData.length,
            itemBuilder: (context, index) {
              final playlist = playlistsData[index];
              return StatsPlaylistItem(
                playlist: playlist.playlist,
                info: Text(
                  context.l10n.count_plays(
                      compactNumberFormatter.format(playlist.count)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
