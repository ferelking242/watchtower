import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/fallbacks/anonymous_fallback.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:watchtower/modules/music/modules/artist/artist_card.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/components/waypoint.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/artists.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';

class UserArtistsPage extends HookConsumerWidget {
  static const name = 'user_artists';
  const UserArtistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    final artistQuery = ref.watch(metadataPluginSavedArtistsProvider);
    final artistQueryNotifier =
        ref.watch(metadataPluginSavedArtistsProvider.notifier);
    final searchText = useState('');
    final controller = useScrollController();
    final theme = Theme.of(context);

    final filteredArtists = useMemoized(() {
      final artists = artistQuery.asData?.value.items ?? [];
      if (searchText.value.isEmpty) return artists.toList();
      return artists
          .map((e) => (weightedRatio(e.name, searchText.value), e))
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .where((e) => e.$1 > 50)
          .map((e) => e.$2)
          .toList();
    }, [artistQuery.asData?.value.items, searchText.value]);

    if (artistQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true) {
      return const AnonymousFallback();
    }

    if (artistQuery.hasError) {
      return ErrorBox(
        error: artistQuery.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSavedArtistsProvider);
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(metadataPluginSavedArtistsProvider);
        },
        child: InterScrollbar(
          controller: controller,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: theme.colorScheme.surface,
                  floating: true,
                  flexibleSpace: SizedBox(
                    height: 48,
                    child: TextField(
                      onChanged: (value) => searchText.value = value,
                      decoration: InputDecoration(
                        hintText: context.l10n.filter_artist,
                        prefixIcon: const Icon(SpotubeIcons.filter),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (filteredArtists.isNotEmpty || artistQuery.isLoading)
                  SliverLayoutBuilder(builder: (context, constrains) {
                    return SliverGrid.builder(
                      itemCount: filteredArtists.length + 1,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisExtent: constrains.smAndDown ? 225 : 250,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        if (filteredArtists.isNotEmpty &&
                            index == filteredArtists.length) {
                          if (artistQuery.asData?.value.hasMore != true) {
                            return const SizedBox.shrink();
                          }
                          return Waypoint(
                            controller: controller,
                            isGrid: true,
                            onTouchEdge: artistQueryNotifier.fetchMore,
                            child: Skeletonizer(enabled: true,
                              child: ArtistCard(FakeData.artist),
                            ),
                          );
                        }
                        return Skeletonizer(enabled: artistQuery.isLoading,
                          child: ArtistCard(
                            filteredArtists.elementAtOrNull(index) ??
                                FakeData.artist,
                          ),
                        );
                      },
                    );
                  })
                else if (filteredArtists.isEmpty &&
                    searchText.value.isEmpty &&
                    !artistQuery.isLoading)
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Undraw(
                          height: 200,
                          illustration: UndrawIllustration.followMeDrone,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.not_following_artists,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Undraw(
                          height: 200,
                          illustration: UndrawIllustration.taken,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.nothing_found,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SliverSafeArea(
                  sliver: SliverToBoxAdapter(child: SizedBox(height: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
