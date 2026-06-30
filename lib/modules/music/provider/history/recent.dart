import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/provider/database/database.dart';

class RecentlyPlayedItemNotifier extends AsyncNotifier<List<HistoryTableData>> {
  @override
  build() async {
    final database = ref.watch(databaseProvider);

    final query = database.customSelect(
      """
      WITH RankedHistory AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY created_at DESC) AS rn
        FROM history_table
        WHERE type in ('playlist', 'album')
      )
      SELECT *
      FROM RankedHistory
      WHERE rn = 1
      ORDER BY created_at DESC
      LIMIT 10
      """,
      readsFrom: {database.historyTable},
    ).map((row) {
      final type = row.read<String>('type');
      return HistoryTableData(
        id: row.read<int>('id'),
        itemId: row.read<String>('item_id'),
        type: HistoryEntryType.values.firstWhere((e) => e.name == type),
        createdAt: row.read<DateTime>('created_at'),
        data: jsonDecode(row.read<String>('data')) as Map<String, dynamic>,
      );
    });

    final subscription = query.watch().listen((event) {
      state = AsyncData(event);
    });

    ref.onDispose(() => subscription.cancel());

    return await query.get();
  }
}

final recentlyPlayedItems =
    AsyncNotifierProvider<RecentlyPlayedItemNotifier, List<HistoryTableData>>(
  () => RecentlyPlayedItemNotifier(),
);
