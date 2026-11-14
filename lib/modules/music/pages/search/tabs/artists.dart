import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/shimmers/music_shimmer.dart';
import 'package:watchtower/modules/music/components/waypoint.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/artist/artist_card.dart';
import 'package:watchtower/modules/music/modules/search/loading.dart';
import 'package:watchtower/modules/music/pages/search/search.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/search/artists.dart';

class SearchPageArtistsTab extends HookConsumerWidget {
  const SearchPageArtistsTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchArtistsSnapshot =
        ref.watch(metadataPluginSearchArtistsProvider(searchTerm));
    final searchArtistsNotifier =
        ref.read(metadataPluginSearchArtistsProvider(searchTerm).notifier);
    final searchArtists = searchArtistsSnapshot.asData?.value.items ?? [];

    if (searchArtistsSnapshot.hasError) {
      return ErrorBox(
        error: searchArtistsSnapshot.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSearchArtistsProvider(searchTerm));
        },
      );
    }

    return SearchPlaceholder(
      snapshot: searchArtistsSnapshot,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: LayoutBuilder(builder: (context, constrains) {
          if (searchArtistsSnapshot.hasValue && searchArtists.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  AppEmptyState(
                    icon: Broken.user_search,
                    title: context.l10n.nothing_found,
                    message: context.l10n.search_to_get_results,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: searchArtists.length + 1,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisExtent: constrains.smAndDown ? 225 : 250,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index >= searchArtists.length) {
                final placeholder = MusicCardShimmer(
                  height: constrains.smAndDown ? 225 : 250,
                );

                if (searchArtists.isEmpty) return placeholder;

                if (searchArtistsSnapshot.asData?.value.hasMore != true) {
                  return const SizedBox.shrink();
                }

                return Waypoint(
                  controller: controller,
                  isGrid: true,
                  onTouchEdge: searchArtistsNotifier.fetchMore,
                  child: placeholder,
                );
              }

              return ArtistCard(searchArtists[index]);
            },
          );
        }),
      ),
    );
  }
}
