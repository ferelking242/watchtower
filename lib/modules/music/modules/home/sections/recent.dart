import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/provider/history/recent.dart';

class HomeRecentlyPlayedSection extends HookConsumerWidget {
  const HomeRecentlyPlayedSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(recentlyPlayedItems);

    // No history yet → render nothing rather than inventing placeholder data.
    if (history.isLoading || history.asData?.value.isEmpty != false) {
      return const SizedBox.shrink();
    }

    final items = [
      for (final item in history.asData!.value)
        if (item.playlist != null)
          item.playlist
        else if (item.album != null)
          item.album,
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return HorizontalPlaybuttonCardView(
      title: context.l10n.recently_played,
      leadingIcon: Broken.clock_1,
      items: items,
      hasNextPage: false,
      isLoadingNextPage: false,
      onFetchMore: () {},
    );
  }
}
