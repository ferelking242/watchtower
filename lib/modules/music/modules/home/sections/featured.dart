import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

@Deprecated(
    "Later a featured playlists API will be added for metadata plugins.")
class HomeFeaturedSection extends HookConsumerWidget {
  const HomeFeaturedSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return const SizedBox.shrink();
    // final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    // final featuredPlaylistsNotifier =
    //     ref.watch(featuredPlaylistsProvider.notifier);

    // if (featuredPlaylists.hasError) {
    //   return Column(
    //     mainAxisSize: MainAxisSize.min,
    //     children: [
    //       Undraw(
    //         illustration: UndrawIllustration.fixingBugs,
    //         height: 200 * 1.0,
    //         color: Theme.of(context).colorScheme.primary,
    //       ),
    //       Text(context.l10n.something_went_wrong),
    //       SizedBox(height: 8),
    //     ],
    //   );
    // }

    // return Opacity(opacity: 1.0, 
    //   enabled: featuredPlaylists.isLoading,
    //   child: HorizontalPlaybuttonCardView<PlaylistSimple>(
    //     items: featuredPlaylists.asData?.value.items ?? [],
    //     title: Text(context.l10n.featured),
    //     isLoadingNextPage: featuredPlaylists.isLoadingNextPage,
    //     hasNextPage: featuredPlaylists.asData?.value.hasMore ?? false,
    //     onFetchMore: featuredPlaylistsNotifier.fetchMore,
    //   ),
    // );
  }
}
