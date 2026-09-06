import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/artist/artist_album_list.dart';
import 'package:watchtower/modules/music/pages/artist/section/footer.dart';
import 'package:watchtower/modules/music/pages/artist/section/header.dart';
import 'package:watchtower/modules/music/pages/artist/section/related_artists.dart';
import 'package:watchtower/modules/music/pages/artist/section/top_tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/albums.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/artist.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/related.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/artist/wikipedia.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/artists.dart';

class ArtistPage extends HookConsumerWidget {
  static const name = "artist";

  final String artistId;
  const ArtistPage(
    @PathParam("id") this.artistId, {
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        body: RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(metadataPluginArtistProvider(artistId));
            ref.invalidate(
                metadataPluginArtistRelatedArtistsProvider(artistId));
            ref.invalidate(metadataPluginArtistAlbumsProvider(artistId));
            ref.invalidate(metadataPluginIsSavedArtistProvider(artistId));
            ref.invalidate(metadataPluginArtistTopTracksProvider(artistId));
            if (artistQuery.hasValue) {
              ref.invalidate(
                artistWikipediaSummaryProvider(artistQuery.asData!.value),
              );
            }
          },
          child: Builder(builder: (context) {
            if (artistQuery.hasError && artistQuery.asData?.value == null) {
              return Center(
                child: Text(
                  artistQuery.error.toString(),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }
            return Skeletonizer(enabled: artistQuery.isLoading,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Floating transparent back button
                  SliverAppBar(
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                  ),
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: ArtistPageHeader(artistId: artistId),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ArtistPageTopTracks(artistId: artistId),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: ArtistAlbumList(artistId)),
                  SliverPadding(
                    padding: const EdgeInsets.all(8.0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        context.l10n.fans_also_like,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  ArtistPageRelatedArtists(artistId: artistId),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (artistQuery.asData?.value != null)
                    SliverToBoxAdapter(
                      child: ArtistPageFooter(
                          artist: artistQuery.asData!.value),
                    ),
                  const SliverSafeArea(
                    sliver: SliverToBoxAdapter(child: SizedBox(height: 10)),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
