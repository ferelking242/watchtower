import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/components/fallbacks/error_box.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_props.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_state.dart';
import 'package:watchtower/modules/music/components/track_presentation/use_track_tile_play_callback.dart';
import 'package:watchtower/modules/music/components/track_tile/track_tile.dart';
import 'package:watchtower/modules/music/components/track_presentation/use_is_user_playlist.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class PresentationListSection extends HookConsumerWidget {
  const PresentationListSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final options = TrackPresentationOptions.of(context);
    final playlist = ref.watch(audioPlayerProvider);
    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier =
        ref.read(presentationStateProvider(options.collection).notifier);
    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);

    final onTileTap = useTrackTilePlayCallback(ref);

    if (state.presentationTracks.isEmpty && !options.pagination.isLoading) {
      if (options.error != null) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ErrorBox(
                error: options.error!,
                onRetry: options.pagination.onRefresh,
              ),
            ),
          ),
        );
      }
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Undraw(
                illustration: UndrawIllustration.dreamer,
                color: Theme.of(context).colorScheme.primary,
                height: 200 * 1.0,
              ),
              Text(
                isUserPlaylist
                    ? context.l10n.no_tracks_added_yet
                    : context.l10n.no_tracks,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverInfiniteList(
      isLoading: options.pagination.isLoading,
      onFetchData: options.pagination.onFetchMore,
      itemCount: state.presentationTracks.length,
      hasReachedMax: !options.pagination.hasNextPage,
      loadingBuilder: (context) {
        return Skeletonizer(enabled: true,
          child: TrackTile(
            index: 0,
            playlist: playlist,
            track: FakeData.track,
          ),
        );
      },
      emptyBuilder: (context) => Skeletonizer(enabled: true,
        child: Column(
          children: List.generate(
            10,
            (index) => TrackTile(
              track: FakeData.track,
              index: index,
              playlist: playlist,
            ),
          ),
        ),
      ),
      itemBuilder: (context, index) => HookBuilder(builder: (context) {
        final track = state.presentationTracks[index];
        final isSelected = useMemoized(
          () => state.selectedTracks.any((e) => e.id == track.id),
          [track.id, state.selectedTracks],
        );
        return TrackTile(
          userPlaylist: isUserPlaylist,
          playlistId: options.collectionId,
          index: index,
          playlist: playlist,
          track: track,
          selected: isSelected,
          onTap: () => onTileTap(track, index),
          onChanged: state.selectedTracks.isEmpty
              ? null
              : (isSelected) {
                  if (isSelected == true) {
                    notifier.selectTrack(track);
                  } else {
                    notifier.deselectTrack(track);
                  }
                },
          onLongPress: () {
            notifier.selectTrack(track);
            HapticFeedback.selectionClick();
          },
        );
      }),
    );
  }
}
