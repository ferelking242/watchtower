import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/components/shimmers/music_shimmer.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/album/album_card.dart';
import 'package:watchtower/modules/music/modules/artist/artist_card.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_card.dart';

/// Horizontal shelf of music cards.
///
/// Uses the shared Watchtower design system ([AppSectionHeader] for the title
/// row and [AppUI] for every dimension) so a music shelf reads exactly like
/// the movie/series/manga shelves instead of carrying a second visual language.
class HorizontalPlaybuttonCardView<T> extends HookWidget {
  final String title;
  final List<T> items;
  final Widget? error;
  final VoidCallback onFetchMore;
  final bool isLoadingNextPage;
  final bool hasNextPage;
  final bool isLoading;
  final IconData? leadingIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  HorizontalPlaybuttonCardView({
    required this.title,
    required this.items,
    required this.hasNextPage,
    required this.onFetchMore,
    required this.isLoadingNextPage,
    this.isLoading = false,
    this.leadingIcon,
    this.actionLabel,
    this.onAction,
    this.error,
    super.key,
  }) : assert(
          items.every(
            (item) =>
                item is SpotubeSimpleAlbumObject ||
                item is SpotubeSimplePlaylistObject ||
                item is SpotubeFullArtistObject,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final isArtist = items.every((s) => s is SpotubeFullArtistObject);
    final cardWidth = AppUI.horizontalCardWidth(context);
    final railHeight = isArtist ? cardWidth * 1.6 : cardWidth * 1.5;
    final padding = AppUI.pagePadding(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          leadingIcon: leadingIcon,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: error,
          )
        else
          SizedBox(
            height: railHeight,
            child: NotificationListener(
              // This rail owns its own gesture stream — keep a single scrollbar.
              onNotification: (notification) => true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                ),
                child: items.isEmpty
                    ? isLoading
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            itemCount: 5,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(
                                right: AppUI.mediaGridCrossAxisSpacing,
                              ),
                              child: MusicCardShimmer(height: railHeight - 16),
                            ),
                          )
                        : const SizedBox.shrink()
                    : InfiniteList(
                        scrollController: scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: padding,
                          vertical: 8,
                        ),
                        itemCount: items.length,
                        onFetchData: onFetchMore,
                        loadingBuilder: (context) =>
                            MusicCardShimmer(height: railHeight - 16),
                        isLoading: isLoadingNextPage,
                        hasReachedMax: !hasNextPage,
                        separatorBuilder: (context, index) => const SizedBox(
                          width: AppUI.mediaGridCrossAxisSpacing,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SizedBox(
                            width: cardWidth,
                            child: switch (item) {
                              SpotubeSimplePlaylistObject() => PlaylistCard(
                                  item as SpotubeSimplePlaylistObject,
                                ),
                              SpotubeSimpleAlbumObject() =>
                                AlbumCard(item as SpotubeSimpleAlbumObject),
                              SpotubeFullArtistObject() =>
                                ArtistCard(item as SpotubeFullArtistObject),
                              _ => const SizedBox.shrink(),
                            },
                          );
                        }),
              ),
            ),
          ),
      ],
    );
  }
}
