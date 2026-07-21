import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/history/recent.dart';
import 'package:watchtower/modules/music/models/database/database.dart';

class HomeRecentlyPlayedSection extends HookConsumerWidget {
  const HomeRecentlyPlayedSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(recentlyPlayedItems);

    // Still loading or empty → show nothing (no fake placeholder data)
    if (history.isLoading || history.asData?.value.isEmpty != false) {
      return const SizedBox();
    }

    final historyData = history.asData!.value;

    return HorizontalPlaybuttonCardView(
      title: Text(context.l10n.recently_played),
      items: [
        for (final item in historyData)
          if (item.playlist != null)
            item.playlist
          else if (item.album != null)
            item.album
      ],
      hasNextPage: false,
      isLoadingNextPage: false,
      onFetchMore: () {},
    );
  }
}
