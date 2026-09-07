import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/database/database.dart';
import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/family_paginated.dart';

typedef PlaybackHistoryPlaylist = ({
  int count,
  SpotubeSimplePlaylistObject playlist
});

class HistoryTopPlaylistsNotifier extends FamilyPaginatedAsyncNotifier<
    PlaybackHistoryPlaylist, HistoryDuration> {
  HistoryTopPlaylistsNotifier() : super();

  SimpleSelectStatement<$HistoryTableTable, HistoryTableData>
      createPlaylistsQuery() {
    final database = ref.read(databaseProvider);

    return database.select(database.historyTable)
      ..where(
        (tbl) =>
            tbl.type.equalsValue(HistoryEntryType.playlist) &
            tbl.createdAt.isBiggerOrEqualValue(
              DateTime.now().subtract(arg.duration),
            ),
      );
  }

  @override
  fetch(offset, limit) async {
    final playlistsQuery = createPlaylistsQuery()..limit(limit, offset: offset);

    final items = getPlaylistsWithCount(await playlistsQuery.get());

    return SpotubePaginationResponseObject(
      items: items,
      nextOffset: offset + limit,
      total: items.length,
      limit: limit,
      hasMore: items.length == limit,
    );
  }

  @override
  build() async {
    final subscription = createPlaylistsQuery().watch().listen((event) {
      if (state.asData == null) return;
      state = AsyncData(state.asData!.value.copyWith(
        items: getPlaylistsWithCount(event),
        hasMore: false,
      ));
    });

    ref.onDispose(() {
      subscription.cancel();
    });

    return await fetch(0, 20);
  }

  List<PlaybackHistoryPlaylist> getPlaylistsWithCount(
    List<HistoryTableData> playlists,
  ) {
    return groupBy(playlists, (playlist) => playlist.playlist!.id)
        .entries
        .map((entry) {
          return (
            count: entry.value.length,
            playlist: entry.value.first.playlist!,
          );
        })
        .sorted((a, b) => b.count.compareTo(a.count))
        .toList();
  }
}

final historyTopPlaylistsProvider = AsyncNotifierProvider.family<
    HistoryTopPlaylistsNotifier,
    SpotubePaginationResponseObject<PlaybackHistoryPlaylist>,
    HistoryDuration>(
  (a) => HistoryTopPlaylistsNotifier()..initFamily(a),
);
