import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/modules/stats/common/artist_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class StatsArtistsPage extends HookConsumerWidget {
  static const name = "stats_artists";
  const StatsArtistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topTracks = ref.watch(
      historyTopTracksProvider(HistoryDuration.allTime),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(HistoryDuration.allTime).notifier);

    final artistsData = useMemoized(
      () => topTracksNotifier.artists,
      [topTracks.asData?.value],
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.artists),
          ),
        body: Skeletonizer(enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
          child: InfiniteList(
            onFetchData: () async {
              await topTracksNotifier.fetchMore();
            },
            hasError: topTracks.hasError,
            isLoading: topTracks.isLoading && !topTracks.isLoadingNextPage,
            hasReachedMax: topTracks.asData?.value.hasMore ?? true,
            itemCount: artistsData.length,
            itemBuilder: (context, index) {
              final artist = artistsData[index];
              return StatsArtistItem(
                artist: artist.artist,
                info: Text(context.l10n
                    .count_plays(compactNumberFormatter.format(artist.count))),
              );
            },
          ),
        ),
      ),
    );
  }
}
