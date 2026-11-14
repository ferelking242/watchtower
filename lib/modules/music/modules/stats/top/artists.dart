import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/modules/stats/common/artist_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class TopArtists extends HookConsumerWidget {
  const TopArtists({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
    final topTracks = ref.watch(
      historyTopTracksProvider(historyDuration),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(historyDuration).notifier);

    final artistsData =
        useMemoized(() => topTracksNotifier.artists, [topTracks.asData?.value]);

    return ShimmerSkeleton.sliver(
      enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
      child: SliverInfiniteList(
        onFetchData: () async {
          await topTracksNotifier.fetchMore();
        },
        hasError: topTracks.hasError,
        isLoading: topTracks.isLoading && !topTracks.isLoadingNextPage,
        hasReachedMax: topTracks.asData?.value.hasMore ?? true,
        itemCount: artistsData.length,
        emptyBuilder: (context) => AppEmptyState(
          icon: Broken.chart,
          title: context.l10n.no_tracks_listened_yet,
          message: context.l10n.search_to_get_results,
        ),
        itemBuilder: (context, index) {
          final artist = artistsData[index];
          return StatsArtistItem(
            artist: artist.artist,
            info: Text(
              context.l10n
                  .count_plays(compactNumberFormatter.format(artist.count)),
            ),
          );
        },
      ),
    );
  }
}
