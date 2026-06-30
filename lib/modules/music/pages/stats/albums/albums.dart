import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/modules/stats/common/album_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/albums.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class StatsAlbumsPage extends HookConsumerWidget {
  static const name = "stats_albums";
  const StatsAlbumsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final topAlbums =
        ref.watch(historyTopAlbumsProvider(HistoryDuration.allTime));
    final topAlbumsNotifier =
        ref.watch(historyTopAlbumsProvider(HistoryDuration.allTime).notifier);

    final albumsData = topAlbums.asData?.value.items ?? [];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.albums),
          ),
        body: Skeletonizer(enabled: topAlbums.isLoading && !topAlbums.isLoadingNextPage,
          child: InfiniteList(
            onFetchData: () async {
              await topAlbumsNotifier.fetchMore();
            },
            hasError: topAlbums.hasError,
            isLoading: topAlbums.isLoading && !topAlbums.isLoadingNextPage,
            hasReachedMax: topAlbums.asData?.value.hasMore ?? true,
            itemCount: albumsData.length,
            itemBuilder: (context, index) {
              final album = albumsData[index];
              return StatsAlbumItem(
                album: album.album,
                info: Text(context.l10n
                    .count_plays(compactNumberFormatter.format(album.count))),
              );
            },
          ),
        ),
      ),
    );
  }
}
