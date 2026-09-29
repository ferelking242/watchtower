import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/pages/search/search.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/all.dart';

class SearchArtistsSection extends HookConsumerWidget {
  const SearchArtistsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final search = ref.watch(metadataPluginSearchAllProvider(searchTerm));

    final artists = search.asData?.value.artists ?? [];

    return HorizontalPlaybuttonCardView(
      isLoadingNextPage: false,
      hasNextPage: false,
      items: artists,
      onFetchMore: () {},
      title: Text(context.l10n.artists),
    );
  }
}
