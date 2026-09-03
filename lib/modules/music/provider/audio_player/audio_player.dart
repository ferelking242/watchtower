import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';

/// Maps the YouTube CDN `c=` client param to the matching user-agent.
/// Sending a mismatched UA makes the CDN answer 403 on the redirected stream.
const _kClientUas = {
  'ANDROID': 'com.google.android.youtube/19.09.37 (Linux; U; Android 13) gzip',
  'IOS':
      'com.google.ios.youtube/19.09.3 (iPhone14,3; U; CPU iOS 15_6_1 like Mac OS X)',
  'MWEB':
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0 Mobile Safari/537.36',
  'SAFARI':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15',
};

String? _userAgentForUrl(String url) {
  try {
    final c = Uri.parse(url).queryParameters['c']?.toUpperCase();
    if (c != null && _kClientUas.containsKey(c)) {
      return _kClientUas[c];
    }
  } catch (_) {}
  return null;
}
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:watchtower/modules/music/extensions/list.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/state.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';
import 'package:watchtower/modules/music/provider/database/database.dart';
import 'package:watchtower/modules/music/provider/discord_provider.dart';
import 'package:watchtower/modules/music/provider/server/sourced_track_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  BlackListNotifier get _blacklist => ref.read(blacklistProvider.notifier);

  void _assertAllowedTracks(Iterable<SpotubeTrackObject> tracks) {
    assert(
      tracks.every(
        (track) =>
            track is SpotubeFullTrackObject || track is SpotubeLocalTrackObject,
      ),
      'All tracks must be either SpotubeFullTrackObject or SpotubeLocalTrackObject',
    );
  }

  void _assertAllowedTrack(SpotubeTrackObject tracks) {
    assert(
      tracks is SpotubeFullTrackObject || tracks is SpotubeLocalTrackObject,
      'Track must be either SpotubeFullTrackObject or SpotubeLocalTrackObject',
    );
  }

  Future<void> _syncSavedState() async {
    final database = ref.read(databaseProvider);

    var playerState =
        await database.select(database.audioPlayerStateTable).getSingleOrNull();

    if (playerState == null) {
      await database.into(database.audioPlayerStateTable).insert(
            AudioPlayerStateTableCompanion.insert(
              playing: audioPlayer.isPlaying,
              loopMode: audioPlayer.loopMode,
              shuffled: audioPlayer.isShuffled,
              collections: <String>[],
              tracks: const Value(<SpotubeTrackObject>[]),
              currentIndex: const Value(0),
              id: const Value(0),
            ),
          );

      // Use getSingleOrNull — the insert above may fail (disk full, DB
      // locked) which would cause getSingle() to throw StateError.
      playerState =
          await database.select(database.audioPlayerStateTable).getSingleOrNull();
    } else {
      await audioPlayer.setLoopMode(playerState.loopMode);
      await audioPlayer.setShuffle(playerState.shuffled);
    }

    // If the DB is corrupted or the insert failed, playerState is still null.
    // Return early instead of crashing on playerState.tracks below.
    if (playerState == null) return;

    final tracks = playerState.tracks;
    final currentIndex = playerState.currentIndex;

    if (tracks.isEmpty && state.tracks.isNotEmpty) {
      await _updatePlayerState(
        AudioPlayerStateTableCompanion(
          tracks: Value(state.tracks),
          currentIndex: Value(currentIndex),
        ),
      );
    } else if (tracks.isNotEmpty) {
      state = state.copyWith(
        tracks: tracks,
        currentIndex: currentIndex,
      );
      await audioPlayer.openPlaylist(
        tracks.asMediaList(),
        initialIndex: currentIndex,
        autoPlay: false,
      );
    }

    if (playerState.collections.isNotEmpty) {
      state = state.copyWith(
        collections: playerState.collections,
      );
    }
  }

  Future<void> _updatePlayerState(
    AudioPlayerStateTableCompanion companion,
  ) async {
    final database = ref.read(databaseProvider);

    await (database.update(database.audioPlayerStateTable)
          ..where((tb) => tb.id.equals(0)))
        .write(companion);
  }

  @override
  build() {
    final subscriptions = [
      audioPlayer.playingStream.listen((playing) async {
        try {
          state = state.copyWith(playing: playing);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              playing: Value(playing),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.loopModeStream.listen((loopMode) async {
        try {
          state = state.copyWith(loopMode: loopMode);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              loopMode: Value(loopMode),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.shuffledStream.listen((shuffled) async {
        try {
          state = state.copyWith(shuffled: shuffled);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              shuffled: Value(shuffled),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.playlistStream.listen((playlist) async {
        try {
          final tracks =
              playlist.medias.map((e) => SpotubeMedia.media(e).track).toList();

          state = state.copyWith(
            tracks: tracks,
            currentIndex: playlist.index,
          );

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              currentIndex: Value(state.currentIndex),
              tracks: Value(state.tracks),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
    ];

    _syncSavedState();

    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });

    return AudioPlayerState(
      loopMode: audioPlayer.loopMode,
      playing: audioPlayer.isPlaying,
      shuffled: audioPlayer.isShuffled,
      tracks: [],
      collections: [],
    );
  }

  // Collection related methods
  Future<void> addCollections(List<String> collectionIds) async {
    state = state.copyWith(collections: [
      ...state.collections,
      ...collectionIds,
    ]);

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        collections: Value(state.collections),
      ),
    );
  }

  Future<void> addCollection(String collectionId) async {
    await addCollections([collectionId]);
  }

  Future<void> removeCollections(List<String> collectionIds) async {
    state = state.copyWith(
      collections: state.collections
          .where((element) => !collectionIds.contains(element))
          .toList(),
    );

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        collections: Value(state.collections),
      ),
    );
  }

  Future<void> removeCollection(String collectionId) async {
    await removeCollections([collectionId]);
  }

  Future<void> addTracksAtFirst(
    Iterable<SpotubeTrackObject> tracks, {
    bool allowDuplicates = false,
  }) async {
    _assertAllowedTracks(tracks);
    if (state.tracks.length == 1) {
      return addTracks(tracks);
    }

    final addableTracks = _blacklist
        .filter(tracks)
        .where(
          (track) =>
              allowDuplicates ||
              !state.tracks.any((element) => _compareTracks(element, track)),
        )
        .toList();

    state = state.copyWith(
      tracks: [...addableTracks, ...state.tracks],
    );

    for (int i = 0; i < addableTracks.length; i++) {
      final track = addableTracks.elementAt(i);

      await audioPlayer.addTrackAt(
        SpotubeMedia(track),
        max(state.currentIndex, 0) + i + 1,
      );
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> addTrack(SpotubeTrackObject track) async {
    _assertAllowedTrack(track);

    if (_blacklist.contains(track)) return;
    if (state.tracks.any((element) => _compareTracks(element, track))) return;

    state = state.copyWith(
      tracks: [...state.tracks, track],
    );

    await audioPlayer.addTrack(SpotubeMedia(track));

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> addTracks(Iterable<SpotubeTrackObject> tracks) async {
    _assertAllowedTracks(tracks);

    tracks = _blacklist.filter(tracks).toList();
    state = state.copyWith(
      tracks: [...state.tracks, ...tracks],
    );

    for (final track in tracks) {
      await audioPlayer.addTrack(SpotubeMedia(track));
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> removeTrack(String trackId) async {
    final index = state.tracks.indexWhere((element) => element.id == trackId);

    if (index == -1) return;

    state = state.copyWith(
      tracks: List.of(state.tracks)..removeAt(index),
    );

    await audioPlayer.removeTrack(index);

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> removeTracks(Iterable<String> trackIds) async {
    final trackIndexes = state.tracks
        .where((element) => trackIds.any((trackId) => trackId == element.id))
        .mapIndexed((index, element) => index);

    final tracks = state.tracks.where(
      (element) => !trackIds.contains(element.id),
    );

    state = state.copyWith(
      tracks: tracks.toList(),
    );

    for (final index in trackIndexes) {
      await audioPlayer.removeTrack(index);
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  bool _compareTracks(SpotubeTrackObject a, SpotubeTrackObject b) {
    if (a.runtimeType != b.runtimeType) {
      return false;
    }

    return a is SpotubeLocalTrackObject && b is SpotubeLocalTrackObject
        ? a.path == b.path
        : a.id == b.id;
  }

  Future<void> load(
    List<SpotubeTrackObject> tracks, {
    int initialIndex = 0,
    bool autoPlay = false,
  }) async {
    _assertAllowedTracks(tracks);

    final medias = _blacklist
        .filter(tracks)
        .toList()
        .asMediaList()
        .unique((a, b) => a.uri == b.uri);

    // Giving the initial track a boost so MediaKit won't skip
    // because of timeout
    final intendedActiveTrack = medias.elementAt(initialIndex);
    if (intendedActiveTrack.track is! SpotubeLocalTrackObject) {
      ref.read(
        sourcedTrackProvider(
          intendedActiveTrack.track as SpotubeFullTrackObject,
        ).future,
      );
    }

    if (medias.isEmpty) return;

    state = state.copyWith(
      // These are filtered tracks as well
      tracks: medias.map((media) => media.track).toList(),
      currentIndex: initialIndex,
      collections: [],
    );

    // Match libmpv's user-agent to the resolved stream URL while the playlist
    // opens. The local proxy answers /stream/<id> with a 302 to the YouTube
    // CDN, and mpv follows it using its own UA — if the URL's c= client doesn't
    // match, the CDN answers 403 and playback stays silent while state says
    // "playing". Best-effort, in parallel, never delays playback: on
    // timeout/error we keep the previous UA (Android client).
    if (intendedActiveTrack.track is SpotubeFullTrackObject) {
      unawaited(_matchUserAgentFor(intendedActiveTrack));
    }

    await audioPlayer.openPlaylist(
      medias,
      initialIndex: initialIndex,
      autoPlay: autoPlay,
    );

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> _matchUserAgentFor(SpotubeMedia media) async {
    if (media.track is! SpotubeFullTrackObject) return;
    try {
      final src = await ref
          .read(
            sourcedTrackProvider(
              media.track as SpotubeFullTrackObject,
            ).future,
          )
          .timeout(const Duration(seconds: 6));
      final url = src.url;
      if (url == null) return;
      final ua = _userAgentForUrl(url);
      if (ua != null) {
        await audioPlayer.setUserAgent(ua);
      }
    } catch (_) {
      // Resolution failed/timed out — playback proceeds with the previous UA.
    }
  }

  Future<void> swapActiveSource() async {
    if (state.tracks.isEmpty || state.activeTrack is! SpotubeFullTrackObject) {
      return;
    }

    final oldState = state;
    await audioPlayer.stop();

    await load(
      oldState.tracks,
      initialIndex: oldState.currentIndex,
      autoPlay: true,
    );
    state = state.copyWith(
      collections: oldState.collections,
      loopMode: oldState.loopMode,
      playing: oldState.playing,
      shuffled: false,
    );
    await audioPlayer.setLoopMode(oldState.loopMode);
    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(state.currentIndex),
        collections: Value(state.collections),
        loopMode: Value(state.loopMode),
        playing: Value(state.playing),
        shuffled: Value(state.shuffled),
      ),
    );
  }

  Future<void> jumpToTrack(SpotubeTrackObject track) async {
    final index =
        state.tracks.toList().indexWhere((element) => element.id == track.id);
    if (index == -1) return;
    await audioPlayer.jumpTo(index);
  }

  Future<void> moveTrack(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex ||
        newIndex < 0 ||
        oldIndex < 0 ||
        newIndex > state.tracks.length - 1 ||
        oldIndex > state.tracks.length - 1) {
      return;
    }

    await audioPlayer.moveTrack(oldIndex, newIndex);
  }

  Future<void> stop() async {
    state = state.copyWith(
      tracks: [],
      currentIndex: 0,
      collections: [],
      loopMode: PlaylistMode.none,
      playing: false,
      shuffled: false,
    );
    await audioPlayer.stop();
    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: const Value(0),
        collections: const Value(<String>[]),
        loopMode: const Value(PlaylistMode.none),
        playing: const Value(false),
        shuffled: const Value(false),
      ),
    );
    ref.read(discordProvider.notifier).clear();
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  () => AudioPlayerNotifier(),
);
