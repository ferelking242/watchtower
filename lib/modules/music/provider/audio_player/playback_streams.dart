import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/audio_player/state.dart';
import 'package:watchtower/modules/music/provider/history/history.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/scrobble.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobble_policy.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobbler.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

/// Playback-derived side effects that belong to the single audio engine:
/// scrobbling (Last.fm + metadata plugin) and per-track history. Discord
/// presence and the media notification keep their own listeners inside
/// [discordProvider] / the media session, so they are not duplicated here.
class PlaybackStreamListeners {
  final Ref ref;
  PlaybackStreamListeners(this.ref) {
    final subscription = subscribeToScrobble();

    ref.onDispose(subscription.cancel);
  }

  AudioPlayerState get audioPlayerState => ref.read(audioPlayerProvider);
  ScrobblerNotifier get scrobbler => ref.read(scrobblerProvider.notifier);
  PlaybackHistoryActions get history =>
      ref.read(playbackHistoryActionsProvider);

  StreamSubscription subscribeToScrobble() {
    String? lastScrobbled;

    return audioPlayer.positionStream.listen((position) async {
      try {
        final track = audioPlayerState.activeTrack;
        final isLocal = track is SpotubeLocalTrackObject;

        final trackKey = scrobbleTrackKey(
          id: track?.id,
          isLocal: isLocal,
          path: isLocal ? track.path : null,
        );

        if (!shouldScrobble(
          trackKey: trackKey,
          lastScrobbledKey: lastScrobbled,
          position: position,
          duration: audioPlayer.duration,
        )) {
          return;
        }

        lastScrobbled = trackKey;

        scrobbler.scrobble(track!);
        ref.read(metadataPluginScrobbleProvider.notifier).scrobble(track);

        // Playlist-sourced tracks carry artist ids but no artwork, so the
        // listening-history row would render without avatars. Re-fetch the
        // artists (which do carry images) before persisting.
        var historyTrack = track;
        if (track.artists.any((a) => a.images == null)) {
          final metadataPlugin = await ref.read(metadataPluginProvider.future);
          if (metadataPlugin != null) {
            final artists = await Future.wait(
              track.artists.map(
                (artist) => metadataPlugin.artist.getArtist(artist.id),
              ),
            );
            historyTrack = track.copyWith(
              artists: artists
                  .map((e) => SpotubeSimpleArtistObject.fromJson(e.toJson()))
                  .toList(),
            );
          }
        }

        await history.addTrack(historyTrack);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }
}

final playbackStreamListenersProvider =
    Provider<PlaybackStreamListeners>(PlaybackStreamListeners.new);
