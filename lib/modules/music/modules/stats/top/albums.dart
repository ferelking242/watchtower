import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/modules/stats/common/album_item.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/albums.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class TopAlbums extends HookConsumerWidget {
  const TopAlbums({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
    final topAlbums = ref.watch(historyTopAlbumsProvider(historyDuration));
    final topAlbumsNotifier =
        ref.watch(historyTopAlbumsProvider(historyDuration).notifier);

    final albumsData = topAlbums.asData?.value.items ?? [];

    return Skeletonizer.sliver(
      enabled: topAlbums.isLoading && !topAlbums.isLoadingNextPage,
      child: SliverInfiniteList(
        onFetchData: () async {
          await topAlbumsNotifier.fetchMore();
        },
        hasError: topAlbums.hasError,
        isLoading: topAlbums.isLoading && !topAlbums.isLoadingNextPage,
        hasReachedMax: topAlbums.asData?.value.hasMore ?? true,
        itemCount: albumsData.length,
        emptyBuilder: (context) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 50),
              Undraw(
                illustration: UndrawIllustration.happyMusic,
                color: Theme.of(context).colorScheme.primary,
                height: 200 * 1.0,
              ),
              Text(
                context.l10n.no_tracks_listened_yet,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        itemBuilder: (context, index) {
          final album = albumsData[index];
          return StatsAlbumItem(
            album: album.album,
            info: Text(
              context.l10n
                  .count_plays(compactNumberFormatter.format(album.count)),
            ),
          );
        },
      ),
    );
  }
}
