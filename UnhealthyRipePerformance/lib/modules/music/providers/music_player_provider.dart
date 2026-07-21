import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:watchtower/modules/music/models/music_models.dart';

// ─── Singleton Player ─────────────────────────────────────────────────────────

final _player = Player();

Player get musicKitPlayer => _player;

// ─── Provider ────────────────────────────────────────────────────────────────

class MusicPlayerNotifier extends Notifier<MusicPlayerState> {
  late final List<StreamSubscription> _subs;

  @override
  MusicPlayerState build() {
    _subs = [
      _player.stream.playing.listen(
        (v) => state = state.copyWith(isPlaying: v),
      ),
      _player.stream.buffering.listen(
        (v) => state = state.copyWith(isBuffering: v),
      ),
      _player.stream.position.listen(
        (v) => state = state.copyWith(position: v),
      ),
      _player.stream.buffer.listen(
        (v) => state = state.copyWith(buffered: v),
      ),
      _player.stream.completed.listen((completed) {
        if (!completed) return;
        final s = state;
        switch (s.repeatMode) {
          case MusicRepeatMode.track:
            _player.seek(Duration.zero);
            _player.play();
            break;
          case MusicRepeatMode.playlist:
            skipToNext();
            break;
          case MusicRepeatMode.none:
            if (s.hasNext) skipToNext();
            break;
        }
      }),
    ];

    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
    });

    return const MusicPlayerState();
  }

  // ── Playback control ────────────────────────────────────────────────────

  Future<void> loadTrack(MusicTrack track) async {
    final url = track.sourceUrl ?? track.previewUrl;
    if (url == null) return;
    await _player.open(Media(url));
    state = state.copyWith(isBuffering: true);
  }

  Future<void> playQueue(List<MusicTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: tracks, currentIndex: startIndex);
    await loadTrack(tracks[startIndex]);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> playPause() => _player.playOrPause();

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double v) => _player.setVolume(v * 100);

  Future<void> skipToNext() async {
    final s = state;
    if (!s.hasNext) return;
    final nextIdx = s.currentIndex + 1;
    state = state.copyWith(currentIndex: nextIdx);
    await loadTrack(s.queue[nextIdx]);
  }

  Future<void> skipToPrevious() async {
    final s = state;
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (!s.hasPrevious) return;
    final prevIdx = s.currentIndex - 1;
    state = state.copyWith(currentIndex: prevIdx);
    await loadTrack(s.queue[prevIdx]);
  }

  Future<void> skipToIndex(int index) async {
    final s = state;
    if (index < 0 || index >= s.queue.length) return;
    state = state.copyWith(currentIndex: index);
    await loadTrack(s.queue[index]);
  }

  // ── Queue management ────────────────────────────────────────────────────

  void addToQueue(MusicTrack track) {
    final q = [...state.queue, track];
    state = state.copyWith(queue: q);
  }

  void addNextInQueue(MusicTrack track) {
    final q = [...state.queue];
    q.insert(state.currentIndex + 1, track);
    state = state.copyWith(queue: q);
  }

  void removeFromQueue(int index) {
    final q = [...state.queue]..removeAt(index);
    int newIdx = state.currentIndex;
    if (index < newIdx) newIdx--;
    state = state.copyWith(queue: q, currentIndex: newIdx.clamp(0, q.length - 1));
  }

  void clearQueue() {
    _player.stop();
    state = const MusicPlayerState();
  }

  // ── Modes ───────────────────────────────────────────────────────────────

  void toggleShuffle() {
    final shuffled = !state.isShuffled;
    if (shuffled) {
      final q = [...state.queue];
      final current = q.removeAt(state.currentIndex);
      q.shuffle();
      q.insert(0, current);
      state = state.copyWith(queue: q, currentIndex: 0, isShuffled: true);
    } else {
      state = state.copyWith(isShuffled: false);
    }
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      MusicRepeatMode.none => MusicRepeatMode.playlist,
      MusicRepeatMode.playlist => MusicRepeatMode.track,
      MusicRepeatMode.track => MusicRepeatMode.none,
    };
    state = state.copyWith(repeatMode: next);
  }

  // ── Like toggle ─────────────────────────────────────────────────────────

  void toggleLike(String trackId) {
    final q = state.queue.map((t) {
      if (t.id == trackId) return t.copyWith(isLiked: !t.isLiked);
      return t;
    }).toList();
    state = state.copyWith(queue: q);
    ref.read(musicLikedTracksProvider.notifier).toggle(trackId);
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerNotifier, MusicPlayerState>(
  MusicPlayerNotifier.new,
);

// ─── Liked Tracks (local store) ───────────────────────────────────────────────

class MusicLikedTracksNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  bool isLiked(String id) => state.contains(id);
}

final musicLikedTracksProvider =
    NotifierProvider<MusicLikedTracksNotifier, Set<String>>(
  MusicLikedTracksNotifier.new,
);

// ─── Volume ───────────────────────────────────────────────────────────────────

class MusicVolumeNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setVolume(double v) {
    state = v.clamp(0.0, 1.0);
    musicKitPlayer.setVolume(state * 100);
  }
}

final musicVolumeProvider =
    NotifierProvider<MusicVolumeNotifier, double>(MusicVolumeNotifier.new);
