import 'dart:async';
  import 'package:flutter/foundation.dart';
  import 'package:web/web.dart' as web;
  import 'dart:js_interop';

    class MediaKit {
      static void ensureInitialized() {}
    }

    class AudioDevice {
      final String name;
      final String description;
      const AudioDevice(this.name, this.description);
      static AudioDevice get auto => const AudioDevice('auto', 'Auto');
      @override
      bool operator ==(Object other) => other is AudioDevice && other.name == name;
      @override
      int get hashCode => name.hashCode;
    }

    enum MPVLogLevel { none, fatal, error, warn, info, status, v, debug, trace }

    class Media {
      final String uri;
      final Map<String, String>? httpHeaders;
      final Map<String, dynamic>? extras;
      const Media(this.uri, {this.httpHeaders, this.extras});
    }

    class Playlist {
      final List<Media> medias;
      final int index;
      const Playlist(this.medias, {this.index = 0});
    }

    class PlayerConfiguration {
      final bool ready;
      final String? title;
      final int bufferSize;
      final bool pitch;
      final String? vo;
      final bool protocolWhitelist;
      final MPVLogLevel? logLevel;
      final bool async;
      const PlayerConfiguration({
        this.ready = false,
        this.title,
        this.bufferSize = 32 * 1024 * 1024,
        this.pitch = true,
        this.protocolWhitelist = true,
        this.vo,
        this.logLevel,
        this.async = false,
      });
    }

    class PlayerState {
      final Playlist playlist;
      final bool playing;
      final Duration position;
      final Duration duration;
      final double volume;
      final double rate;
      final double pitch;
      final bool buffering;
      final Duration buffer;
      final String? error;
      final List<AudioTrack> audioTracks;
      final List<VideoTrack> videoTracks;
      final List<SubtitleTrack> subtitleTracks;
      final AudioTrack? track;
      final bool completed;
      final double width;
      final double height;
      final List<String> subtitle;
      final bool shuffle;
      final AudioDevice audioDevice;
      final List<AudioDevice> audioDevices;
      final PlaylistMode playlistMode;
      const PlayerState({
        this.playlist = const Playlist([]),
        this.playing = false,
        this.position = Duration.zero,
        this.duration = Duration.zero,
        this.volume = 100.0,
        this.rate = 1.0,
        this.pitch = 1.0,
        this.buffering = false,
        this.buffer = Duration.zero,
        this.error,
        this.audioTracks = const [],
        this.videoTracks = const [],
        this.subtitleTracks = const [],
        this.track,
        this.completed = false,
        this.width = 0,
        this.height = 0,
        this.subtitle = const [],
        this.shuffle = false,
        this.audioDevice = const AudioDevice('auto', 'Auto'),
        this.audioDevices = const [],
        this.playlistMode = PlaylistMode.none,
      });
    }

    class PlayerStream {
      final Stream<Playlist> playlist = const Stream.empty();
      final Stream<bool> playing = const Stream.empty();
      final Stream<Duration> position = const Stream.empty();
      final Stream<Duration> duration = const Stream.empty();
      final Stream<double> volume = const Stream.empty();
      final Stream<double> rate = const Stream.empty();
      final Stream<double> pitch = const Stream.empty();
      final Stream<bool> buffering = const Stream.empty();
      final Stream<Duration> buffer = const Stream.empty();
      final Stream<String> error = const Stream.empty();
      final Stream<List<AudioTrack>> audioTracks = const Stream.empty();
      final Stream<List<VideoTrack>> videoTracks = const Stream.empty();
      final Stream<List<SubtitleTrack>> subtitleTracks = const Stream.empty();
      final Stream<bool> completed = const Stream.empty();
      final Stream<double> width = const Stream.empty();
      final Stream<double> height = const Stream.empty();
      final Stream<List<int>> log = const Stream.empty();
      final Stream<List<String>> subtitle = const Stream.empty();
      final Stream<PlaylistMode> playlistMode = const Stream.empty();
      final Stream<bool> shuffle = const Stream.empty();
      final Stream<List<AudioDevice>> audioDevices = const Stream.empty();
      final Stream<AudioDevice> audioDevice = const Stream.empty();
    }

    typedef PlayerStreams = PlayerStream;

    class AudioTrack {
      final String id;
      final String? title;
      final String? language;
      const AudioTrack(this.id, {this.title, this.language});
      static AudioTrack get auto => const AudioTrack('auto');
      static AudioTrack get no => const AudioTrack('no');
    }

    class VideoTrack {
      final String id;
      final String? title;
      final String? language;
      const VideoTrack(this.id, {this.title, this.language});
      static VideoTrack get auto => const VideoTrack('auto');
      static VideoTrack get no => const VideoTrack('no');
    }

    class SubtitleTrack {
      final String? id;
      final String? title;
      final String? language;
      final String? uri;
      const SubtitleTrack(this.id, {this.title, this.language, this.uri});
      static SubtitleTrack get auto => const SubtitleTrack('auto');
      static SubtitleTrack get no => const SubtitleTrack('no');
      factory SubtitleTrack.uri(String uri, {String? title, String? language}) =>
          SubtitleTrack(null, title: title, language: language, uri: uri);
      factory SubtitleTrack.data(String data, {String? title, String? language}) =>
          SubtitleTrack(null, title: title, language: language);
    }

    enum PlaylistMode { none, single, loop }

    abstract class PlatformPlayer {
      Future<void> setProperty(String property, String value) async {}
      Future<void> command(List<String> cmd) async {}
    }

    class NativePlayer extends PlatformPlayer {}

    class Player {
      final PlayerConfiguration configuration;
      final PlayerState state = const PlayerState();
      final PlayerStream stream = PlayerStream();
      PlatformPlayer? get platform => NativePlayer();

      // Web video bridge — wired up by media_kit_video stub's VideoState
      static final StreamController<String> _webVideoUrlCtrl =
          StreamController<String>.broadcast();
      static Stream<String> get webVideoStream => _webVideoUrlCtrl.stream;
      static web.HTMLVideoElement? _webVideoEl;
      static void webRegister(web.HTMLVideoElement el) { _webVideoEl = el; }
      static void webUnregister() { _webVideoEl = null; }

      Player({this.configuration = const PlayerConfiguration()});

      Future<void> open(dynamic playable, {bool play = true}) async {
        if (playable is Media) _webVideoUrlCtrl.add(playable.uri);
      }

      Future<void> play() async {
        if (_webVideoEl != null) unawaited(_webVideoEl!.play().toDart);
      }

      Future<void> pause() async { _webVideoEl?.pause(); }

      Future<void> playOrPause() async {
        final el = _webVideoEl;
        if (el == null) return;
        if (el.paused) { unawaited(el.play().toDart); } else { el.pause(); }
      }

      Future<void> stop() async {
        _webVideoEl?.pause();
        if (_webVideoEl != null) _webVideoEl!.currentTime = 0;
      }

      Future<void> next() async {}
      Future<void> previous() async {}
      Future<void> jump(int index) async {}

      Future<void> seek(Duration duration) async {
        if (_webVideoEl != null) {
          _webVideoEl!.currentTime = duration.inMilliseconds / 1000.0;
        }
      }

      Future<void> setRate(double rate) async {
        if (_webVideoEl != null) _webVideoEl!.playbackRate = rate;
      }

      Future<void> setPitch(double pitch) async {}

      Future<void> setVolume(double volume) async {
        if (_webVideoEl != null) {
          _webVideoEl!.volume = (volume / 100.0).clamp(0.0, 1.0);
        }
      }

      Future<void> setAudioTrack(AudioTrack track) async {}
      Future<void> setVideoTrack(VideoTrack track) async {}
      Future<void> setSubtitleTrack(SubtitleTrack track) async {}
      Future<void> setLoopMode(PlaylistMode playlistMode) async {}
      Future<void> setPlaylistMode(PlaylistMode playlistMode) async {}
      Future<void> setShuffle(bool shuffle) async {}
      Future<void> setAudioDevice(AudioDevice device) async {}
      Future<void> add(Media media) async {}
      Future<void> remove(int index) async {}
      Future<void> move(int from, int to) async {}
      Future<void> dispose() async { Player.webUnregister(); }
    }
  