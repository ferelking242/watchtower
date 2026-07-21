import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/modules/stats/common/track_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class StatsMinutesPage extends HookConsumerWidget {
  static const name = "stats_minutes";

  const StatsMinutesPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topTracks = ref.watch(
      historyTopTracksProvider(HistoryDuration.allTime),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(HistoryDuration.allTime).notifier);

    final tracksData = topTracks.asData?.value.items ?? [];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.minutes_listened),
          ),
        body: Skeletonizer(enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
          child: InfiniteList(
            separatorBuilder: (context, index) => SizedBox(height: 8),
            onFetchData: () async {
              await topTracksNotifier.fetchMore();
            },
            hasError: topTracks.hasError,
            isLoading: topTracks.isLoading && !topTracks.isLoadingNextPage,
            hasReachedMax: topTracks.asData?.value.hasMore ?? true,
            itemCount: tracksData.length,
            itemBuilder: (context, index) {
              final track = tracksData[index];
              return StatsTrackItem(
                track: track.track,
                info: Text(
                  context.l10n.count_mins(
                    compactNumberFormatter.format(
                      track.count *
                          Duration(milliseconds: track.track.durationMs)
                              .inMinutes,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
