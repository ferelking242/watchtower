import 'dart:async';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audio_session/audio_session.dart';
// ignore: implementation_imports
import 'package:watchtower/modules/music/services/audio_player/playback_state.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

/// MediaKit [Player] by default doesn't have a state stream.
/// This class adds a state stream to the [Player] class.
class CustomPlayer extends Player {
  final StreamController<AudioPlaybackState> _playerStateStream;

  late final List<StreamSubscription> _subscriptions;

  int _androidAudioSessionId = 0;
  String _packageName = "";
  AndroidAudioManager? _androidAudioManager;

  CustomPlayer({super.configuration})
      : _playerStateStream = StreamController.broadcast() {
    nativePlayer.setProperty("network-timeout", "120");
    // YouTube CDN URLs are tagged c=ANDROID; send a matching UA so the CDN
    // accepts the connection when libmpv follows the 302 redirect from our
    // local proxy.  This mirrors the UA used by youtube_explode_dart's
    // Android client and prevents 403 IP/UA mismatch on googlevideo.com.
    nativePlayer.setProperty(
      "user-agent",
      "com.google.android.youtube/19.09.37 (Linux; U; Android 13) gzip",
    );
    // Allow libmpv to follow HTTP redirects from our local proxy (http) to
    // the YouTube CDN (https). Without this flag some builds of libmpv refuse
    // cross-scheme or cross-origin redirects originating from localhost.
    nativePlayer.setProperty("force-seekable", "yes");

    _subscriptions = [
      stream.buffering.listen((event) {
        _playerStateStream.add(AudioPlaybackState.buffering);
      }),
      stream.playing.listen((playing) {
        if (playing) {
          _playerStateStream.add(AudioPlaybackState.playing);
        } else {
          _playerStateStream.add(AudioPlaybackState.paused);
        }
      }),
      stream.completed.listen((isCompleted) async {
        if (!isCompleted) return;
        _playerStateStream.add(AudioPlaybackState.completed);
      }),
      stream.playlist.listen((event) {
        if (event.medias.isEmpty) {
          _playerStateStream.add(AudioPlaybackState.stopped);
        }
      }),
      stream.error.listen((event) {
        AppLogger.reportError('[MediaKitError] \n$event', StackTrace.current);
      }),
    ];
    PackageInfo.fromPlatform().then((packageInfo) {
      _packageName = packageInfo.packageName;
    });
    if (kIsAndroid) {
      _androidAudioManager = AndroidAudioManager();
      AudioSession.instance.then((s) async {
        _androidAudioSessionId =
            await _androidAudioManager!.generateAudioSessionId();
        notifyAudioSessionUpdate(true);

        await nativePlayer.setProperty(
          "audiotrack-session-id",
          _androidAudioSessionId.toString(),
        );
        await nativePlayer.setProperty("ao", "audiotrack,opensles,");
      });
    }
  }

  Future<void> notifyAudioSessionUpdate(bool active) async {
    if (kIsAndroid) {
      sendBroadcast(
        BroadcastMessage(
          name: active
              ? "android.media.action.OPEN_AUDIO_EFFECT_CONTROL_SESSION"
              : "android.media.action.CLOSE_AUDIO_EFFECT_CONTROL_SESSION",
          data: {
            "android.media.extra.AUDIO_SESSION": _androidAudioSessionId,
            "android.media.extra.PACKAGE_NAME": _packageName
          },
        ),
      );
    }
  }

  bool get shuffled => state.shuffle;

  Stream<AudioPlaybackState> get playerStateStream => _playerStateStream.stream;
  Stream<bool> get shuffleStream => stream.shuffle;
  Stream<int> get indexChangeStream {
    int oldIndex = state.playlist.index;
    return stream.playlist.map((event) => event.index).where((newIndex) {
      if (newIndex != oldIndex) {
        oldIndex = newIndex;
        return true;
      }
      return false;
    });
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    await super.setShuffle(shuffle);
  }

  @override
  Future<void> stop() async {
    await super.stop();

    _playerStateStream.add(AudioPlaybackState.stopped);
  }

  @override
  Future<void> dispose() async {
    for (var element in _subscriptions) {
      element.cancel();
    }
    await notifyAudioSessionUpdate(false);
    return super.dispose();
  }

  NativePlayer get nativePlayer => platform as NativePlayer;

  Future<void> insert(int index, Media media) async {
    final addedMediaCompleter = Completer<int>();
    final playlistStream = stream.playlist.listen(
      (event) {
        final mediaAddedIndex =
            event.medias.indexWhere((m) => m.uri == media.uri);
        if (mediaAddedIndex != -1 && !addedMediaCompleter.isCompleted) {
          addedMediaCompleter.complete(mediaAddedIndex);
        }
      },
    );
    try {
      await add(media);
      final mediaAddedIndex = await addedMediaCompleter.future;
      await move(mediaAddedIndex, index);
    } finally {
      playlistStream.cancel();
    }
  }

  Future<void> setAudioNormalization(bool normalize) async {
    if (normalize) {
      await nativePlayer.setProperty('af', 'dynaudnorm=g=5:f=250:r=0.9:p=0.5');
    } else {
      await nativePlayer.setProperty('af', '');
    }
  }

  Future<void> setDemuxerBufferSize(int sizeInBytes) async {
    await nativePlayer.setProperty('demuxer-max-bytes', sizeInBytes.toString());
    await nativePlayer.setProperty(
      'demuxer-max-back-bytes',
      sizeInBytes.toString(),
    );
  }
}
