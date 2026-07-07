import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/stubs/js_ffi_exports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riv;
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/custom_button.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/video.dart' as vid;
import 'package:watchtower/modules/anime/providers/anime_player_controller_provider.dart';
import 'package:watchtower/modules/anime/widgets/aniskip_countdown_btn.dart';
import 'package:watchtower/modules/anime/widgets/desktop.dart';
import 'package:watchtower/modules/anime/widgets/play_or_pause_button.dart';
import 'package:watchtower/modules/library/providers/local_archive.dart';
import 'package:watchtower/modules/manga/reader/widgets/btn_chapter_list_dialog.dart';
import 'package:watchtower/modules/anime/widgets/mobile.dart';
import 'package:watchtower/modules/anime/widgets/subtitle_view.dart';
import 'package:watchtower/modules/anime/widgets/subtitle_setting_widget.dart';
import 'package:watchtower/modules/manga/reader/providers/push_router.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_audio_state_provider.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_decoder_state_provider.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_state_provider.dart';
import 'package:watchtower/modules/widgets/custom_draggable_tabbar.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/aniskip.dart';
import 'package:watchtower/services/fetch_subtitles.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/torrent_server.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import 'widgets/search_subtitles.dart';
import 'widgets/player_feedback_page.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/widgets/error_box.dart';

bool _isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

class AnimePlayerView extends riv.ConsumerStatefulWidget {
  final int episodeId;
  const AnimePlayerView({super.key, required this.episodeId});

  @override
  riv.ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends riv.ConsumerState<AnimePlayerView> {
  late final Chapter episode = isar.chapters.getSync(widget.episodeId)!;
  List<String> _infoHashList = [];
  bool desktopFullScreenPlayer = false;
  @override
  void dispose() {
    // Log watch session end
    try {
      AppLogger.log(
        'WATCH fin · ep="${episode.name}"',
        tag: LogTag.watch,
        logLevel: LogLevel.info,
      );
    } catch (_) {}
    if (_isDesktop) {
      setFullScreen(value: desktopFullScreenPlayer);
    }
    for (var infoHash in _infoHashList) {
      MTorrentServer().removeTorrent(infoHash);
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultSubtitleLang = ref.watch(defaultSubtitleLangStateProvider);
    final serversData = ref.watch(getVideoListProvider(episode: episode));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    return serversData.when(
      data: (data) {
        final (videos, isLocal, infoHashList, mpvDirectory) = data;
        _infoHashList = infoHashList;
        if (videos.isEmpty && !(episode.manga.value!.isLocalArchive ?? false)) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: _EmptyEpisodeView(
              onRetry: () => ref.invalidate(getVideoListProvider(episode: episode)),
              onBack: () => Navigator.pop(context),
            ),
          );
        }

        return AnimeStreamPage(
          defaultSubtitle: completeLanguageNameEnglish(
            defaultSubtitleLang.toLanguageTag(),
          ),
          episode: episode,
          videos: videos,
          isLocal: isLocal,
          isTorrent: infoHashList.isNotEmpty,
          desktopFullScreenPlayer: (value) {
            desktopFullScreenPlayer = value;
          },
          mpvDirectory: mpvDirectory,
        );
      },
      error: (error, stackTrace) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(''),
          leading: BackButton(
            onPressed: () {
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
              Navigator.pop(context);
            },
          ),
        ),
        body: ErrorBox(
          error: error,
          stackTrace: stackTrace,
          title: 'Failed to load video',
        ),
      ),
      loading: () {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              const Center(child: ProgressCenter()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () {
                          SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.manual,
                            overlays: SystemUiOverlay.values,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimeStreamPage extends riv.ConsumerStatefulWidget {
  final List<vid.Video> videos;
  final Chapter episode;
  final String defaultSubtitle;
  final bool isLocal;
  final bool isTorrent;
  final Directory? mpvDirectory;
  final void Function(bool) desktopFullScreenPlayer;
  const AnimeStreamPage({
    super.key,
    required this.defaultSubtitle,
    required this.isLocal,
    required this.videos,
    required this.episode,
    required this.isTorrent,
    required this.desktopFullScreenPlayer,
    required this.mpvDirectory,
  });

  @override
  riv.ConsumerState<AnimeStreamPage> createState() => _AnimeStreamPageState();
}

enum _AniSkipPhase { none, opening, ending }

/// When the user first opens a video (on Desktop).
/// Only used for fullscreen/windowed behavior.
bool _firstTime = true;

class _AnimeStreamPageState extends riv.ConsumerState<AnimeStreamPage>
    with
        _AlwaysOnTopStateMixin,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  late final GlobalKey<VideoState> _key = GlobalKey<VideoState>();
  late final useLibass = ref.read(useLibassStateProvider);
  late final useMpvConfig = ref.read(useMpvConfigStateProvider);
  late final useGpuNext = ref.read(useGpuNextStateProvider);
  late final debandingType = ref.read(debandingStateProvider);
  late final useYUV420P = ref.read(useYUV420PStateProvider);
  late final audioPreferredLang = ref.read(audioPreferredLangStateProvider);
  late final enableAudioPitchCorrection = ref.read(
    enableAudioPitchCorrectionStateProvider,
  );
  late final audioChannel = ref.read(audioChannelStateProvider);
  late final volumeBoostCap = ref.read(volumeBoostCapStateProvider);
  late final Player _player = Player(
    configuration: PlayerConfiguration(
      libass: useLibass,
      config: true,
      configDir: useMpvConfig ? widget.mpvDirectory?.path ?? "" : "",
      options: {
        if (debandingType == DebandingType.cpu) "vf": "gradfun=radius=12",
        if (debandingType == DebandingType.gpu) "deband": "yes",
        if (useYUV420P) "vf": "format=yuv420p",
        if (audioPreferredLang.isNotEmpty) "alang": audioPreferredLang,
        if (enableAudioPitchCorrection) "audio-pitch-correction": "yes",
        "volume-max": "${volumeBoostCap + 100}",
        // ── Buffering / network optimisation ─────────────────────────────
        // Buffer 30 s ahead so stalls only appear on very slow connections.
        "demuxer-readahead-secs": "30",
        // Allow up to 150 MiB of in-memory demuxer cache (streams + HLS).
        "demuxer-max-bytes": "157286400",
        // Keep 50 MiB of already-played content so seeks backward are instant.
        "demuxer-max-back-bytes": "52428800",
        // Abort a stalled HTTP connection faster (default is no timeout).
        "network-timeout": "15",
        if (audioChannel != AudioChannel.reverseStereo)
          "audio-channels": audioChannel.mpvName,
        if (audioChannel == AudioChannel.reverseStereo)
          "af": audioChannel.mpvName,
      },
      observeProperties: {
        "user-data/aniyomi/show_text": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/toggle_ui": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/show_panel": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/software_keyboard":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/set_button_title":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/reset_button_title":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/toggle_button": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/switch_episode":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/pause": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/seek_by": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/seek_to": generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/seek_by_with_text":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/seek_to_with_text":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/aniyomi/launch_int_picker":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/watchtower/chapter_titles":
            generated.mpv_format.MPV_FORMAT_NODE,
        "user-data/watchtower/current_chapter":
            generated.mpv_format.MPV_FORMAT_INT64,
        "user-data/watchtower/selected_shader":
            generated.mpv_format.MPV_FORMAT_NODE,
      },
      eventHandler: _handleMpvEvents,
    ),
  );
  late final hwdecMode = ref.read(hwdecModeStateProvider());
  late final enableHardwareAccel = ref.read(enableHardwareAccelStateProvider);
  late final VideoController _controller;
  late final _streamController = ref.read(
    animeStreamControllerProvider(episode: widget.episode).notifier,
  );
  final Stopwatch _watchStopwatch = Stopwatch();
  late final _firstVid = widget.videos.first;
  late final ValueNotifier<VideoPrefs?> _video = ValueNotifier(
    VideoPrefs(
      videoTrack: VideoTrack(
        _firstVid.originalUrl,
        _firstVid.quality,
        _firstVid.quality,
      ),
      headers: _firstVid.headers,
    ),
  );
  final ValueNotifier<double> _playbackSpeed = ValueNotifier(1.0);
  final ValueNotifier<bool> _isDoubleSpeed = ValueNotifier(false);
  late final ValueNotifier<Duration> _currentPosition = ValueNotifier(
    _streamController.geTCurrentPosition(),
  );
  final ValueNotifier<Duration?> _currentTotalDuration = ValueNotifier(null);
  final ValueNotifier<bool> _showFitLabel = ValueNotifier(false);
  final ValueNotifier<bool> _isCompleted = ValueNotifier(false);
  // OPlayer-style side panel (settings + episodes, 60 % width, right edge)
  bool _sidePanelOpen = false;
  int _sidePanelTab = 0; // 0 = Settings, 1 = Épisodes
  final ValueNotifier<Duration?> _tempPosition = ValueNotifier(null);
  final ValueNotifier<BoxFit> _fit = ValueNotifier(BoxFit.contain);
  final ValueNotifier<List<(String, int)>> _chapterMarks = ValueNotifier([]);
  final ValueNotifier<int?> _currentChapterMark = ValueNotifier(null);
  final ValueNotifier<String> _selectedShader = ValueNotifier("");
  final ValueNotifier<ActiveCustomButton?> _customButton = ValueNotifier(null);
  final ValueNotifier<List<CustomButton>?> _customButtons = ValueNotifier(null);
  bool _locked = false;
  bool _isMuted = false;
  double _savedVolume = 1.0;
  late final ValueNotifier<_AniSkipPhase> _skipPhase = ValueNotifier(
    _AniSkipPhase.none,
  );
  Results? _openingResult;
  Results? _endingResult;
  bool _hasOpeningSkip = false;
  bool _hasEndingSkip = false;
  bool _initSubtitleAndAudio = true;
  bool _includeSubtitles = false;
  int _subDelay = 0;
  final _subDelayController = TextEditingController(text: "0");
  double _subSpeed = 1;
  final _subSpeedController = TextEditingController(text: "1");
  int lastRpcTimestampUpdate = DateTime.now().millisecondsSinceEpoch;

  late final StreamSubscription<Duration> _currentPositionSub;

  late final StreamSubscription<Duration> _currentTotalDurationSub = _player
      .stream
      .duration
      .listen((duration) {
        _currentTotalDuration.value = duration;
        discordRpc?.updateChapterTimestamp(_currentPosition.value, duration);
      });

  bool get hasNextEpisode => _streamController.getEpisodeIndex().$1 != 0;

  bool get hasPrevEpisode =>
      _streamController.getEpisodeIndex().$1 + 1 !=
      _streamController.getEpisodesLength(
        _streamController.getEpisodeIndex().$2,
      );

  late final StreamSubscription<bool> _completed = _player.stream.completed
      .listen((val) {
        if (hasNextEpisode && val) {
          if (mounted) {
            pushToNewEpisode(context, _streamController.getNextEpisode());
          }
        }
        // If the last episode of an Anime has ended, exit fullscreen mode
        final isFullScreen = ref.read(fullscreenProvider);
        if (!hasNextEpisode && val && _isDesktop && isFullScreen) {
          setFullScreen(value: false);
          ref.read(fullscreenProvider.notifier).state = false;
          widget.desktopFullScreenPlayer.call(false);
        }
      });

  Future<void> _handleMpvEvents(Pointer<generated.mpv_event> event) async {
    try {
      if (event.ref.event_id ==
          generated.mpv_event_id.MPV_EVENT_PROPERTY_CHANGE) {
        final prop = event.ref.data.cast<generated.mpv_event_property>();
        final propName = prop.ref.name.cast<Utf8>().toDartString();
        if (kDebugMode) {
          if (propName.startsWith("user-data/")) {
            if (kDebugMode) print("DEBUG 00: $propName - ${prop.ref.format}");
          }
        }
        if (propName.startsWith("user-data/") &&
            prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
          final value = prop.ref.data.cast<generated.mpv_node>();
          _handleMpvNodeEvents(propName, value);
        } else if (propName.startsWith("user-data/") &&
            prop.ref.format == generated.mpv_format.MPV_FORMAT_INT64) {
          final value = prop.ref.data.cast<Int64>().value;
          _handleMpvNumberEvents(propName, value);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(e.toString());
      }
    }
  }

  Future<void> _handleMpvNodeEvents(
    String propName,
    Pointer<generated.mpv_node> value,
  ) async {
    final nativePlayer = _player.platform as NativePlayer;
    switch (propName.substring(10)) {
      case "aniyomi/show_text":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          botToast(
            text,
            alignY: -0.99,
            second: 2,
            dismissDirections: const [
              DismissDirection.vertical,
              DismissDirection.horizontal,
            ],
            showIcon: false,
          );
          nativePlayer.setProperty("user-data/aniyomi/show_text", "");
        }
        break;
      case "aniyomi/toggle_ui":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          switch (text) {
            // WIP
            case "show":
              break;
            case "hide":
              break;
            case "toggle":
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/toggle_ui", "");
        }
        break;
      case "aniyomi/show_panel":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          switch (text) {
            // WIP
            case "subtitle_settings":
              break;
            case "subtitle_delay":
              break;
            case "audio_delay":
              break;
            case "video_filters":
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/show_panel", "");
        }
        break;
      case "aniyomi/software_keyboard":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          switch (text) {
            // WIP
            case "show":
              break;
            case "hide":
              break;
            case "toggle":
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/software_keyboard", "");
        }
        break;
      case "aniyomi/set_button_title":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final temp = _customButton.value;
          if (temp == null) break;
          _customButton.value = temp..currentTitle = text;
          nativePlayer.setProperty("user-data/aniyomi/set_button_title", "");
        }
        break;
      case "aniyomi/reset_button_title":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final temp = _customButton.value;
          if (temp == null) break;
          _customButton.value = temp..currentTitle = temp.button.title ?? "";
          nativePlayer.setProperty("user-data/aniyomi/reset_button_title", "");
        }
        break;
      case "aniyomi/toggle_button":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final temp = _customButton.value;
          if (temp == null) break;
          switch (text) {
            case "show":
              _customButton.value = temp..visible = true;
              break;
            case "hide":
              _customButton.value = temp..visible = false;
              break;
            case "toggle":
              _customButton.value = temp..visible = !temp.visible;
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/toggle_button", "");
        }
        break;
      case "aniyomi/switch_episode":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          switch (text) {
            case "n":
              pushToNewEpisode(context, _streamController.getNextEpisode());
              break;
            case "p":
              pushToNewEpisode(context, _streamController.getPrevEpisode());
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/switch_episode", "");
        }
        break;
      case "aniyomi/pause":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          switch (text) {
            case "pause":
              await _player.pause();
              break;
            case "unpause":
              await _player.play();
              break;
            case "pauseunpause":
              await _player.playOrPause();
              break;
          }
          nativePlayer.setProperty("user-data/aniyomi/pause", "");
        }
        break;
      case "aniyomi/seek_by":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final data = int.parse(text.replaceAll("\"", ""));
          final pos = _currentPosition.value.inSeconds + data;
          _tempPosition.value = Duration(seconds: pos);
          await _player.seek(Duration(seconds: pos));
          _tempPosition.value = null;
          nativePlayer.setProperty("user-data/aniyomi/seek_by", "");
        }
        break;
      case "aniyomi/seek_to":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final data = int.parse(text.replaceAll("\"", ""));
          _tempPosition.value = Duration(seconds: data);
          await _player.seek(Duration(seconds: data));
          _tempPosition.value = null;
          nativePlayer.setProperty("user-data/aniyomi/seek_to", "");
        }
        break;
      case "aniyomi/seek_by_with_text":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final data = text.split("|");
          final pos =
              _currentPosition.value.inSeconds +
              int.parse(data[0].replaceAll("\"", ""));
          _tempPosition.value = Duration(seconds: pos);
          await _player.seek(Duration(seconds: pos));
          _tempPosition.value = null;
          (_player.platform as NativePlayer).command(["show-text", data[1]]);
          nativePlayer.setProperty("user-data/aniyomi/seek_by_with_text", "");
        }
        break;
      case "aniyomi/seek_to_with_text":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final data = text.split("|");
          final pos = int.parse(data[0].replaceAll("\"", ""));
          _tempPosition.value = Duration(seconds: pos);
          await _player.seek(Duration(seconds: pos));
          _tempPosition.value = null;
          (_player.platform as NativePlayer).command(["show-text", data[1]]);
          nativePlayer.setProperty("user-data/aniyomi/seek_to_with_text", "");
        }
        break;
      case "aniyomi/launch_int_picker":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          if (text.isEmpty) break;
          final data = text.split("|");
          final start = int.parse(data[2]);
          final stop = int.parse(data[3]);
          final step = int.parse(data[4]);
          int currentValue = start;
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(data[0]),
                content: StatefulBuilder(
                  builder: (context, setState) => SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NumberPicker(
                          value: currentValue,
                          minValue: start,
                          maxValue: stop,
                          step: step,
                          haptics: true,
                          textMapper: (numberText) =>
                              data[1].replaceAll("%d", numberText),
                          onChanged: (value) =>
                              setState(() => currentValue = value),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        child: Text(
                          context.l10n.cancel,
                          style: TextStyle(color: context.primaryColor),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final namePtr = data[5].toNativeUtf8();
                          final valuePtr = calloc<Int64>(1)
                            ..value = currentValue;
                          nativePlayer.mpv.mpv_set_property(
                            nativePlayer.ctx,
                            namePtr.cast(),
                            generated.mpv_format.MPV_FORMAT_INT64,
                            valuePtr.cast(),
                          );
                          malloc.free(namePtr);
                          malloc.free(valuePtr);
                          Navigator.pop(context);
                        },
                        child: Text(
                          context.l10n.ok,
                          style: TextStyle(color: context.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
          nativePlayer.setProperty("user-data/aniyomi/launch_int_picker", "");
        }
        break;
      case "watchtower/chapter_titles":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          final data = jsonDecode(text) as List<dynamic>;
          _chapterMarks.value = data
              .map(
                (e) => (
                  e["title"] as String,
                  e["timestamp"] is double
                      ? (e["timestamp"] as double).toInt() * 1000
                      : (e["timestamp"] as int) * 1000,
                ),
              )
              .toList();
        }
        break;
      case "watchtower/selected_shader":
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          _selectedShader.value = text;
        }
        break;
    }
  }

  Future<void> _handleMpvNumberEvents(String propName, int value) async {
    switch (propName.substring(10)) {
      case "watchtower/current_chapter":
        _currentChapterMark.value = max(value, 0);
        break;
    }
  }

  Future<void> _initCustomButton() async {
    if (!useMpvConfig) return;
    final customButtons = isar.customButtons
        .filter()
        .idIsNotNull()
        .sortByPos()
        .findAllSync();
    if (customButtons.isEmpty) return;
    final primaryButton =
        customButtons.firstWhereOrNull((e) => e.isFavourite ?? false) ??
        customButtons.first;
    final provider = StorageProvider();
    if (!(await provider.requestPermission())) {
      return;
    }
    final dir = await provider.getMpvDirectory();
    String scriptsDir = path.join(dir!.path, 'scripts');
    await Directory(scriptsDir).create(recursive: true);
    final mpvFile = File('$scriptsDir/init_custom_buttons.lua');
    final content = StringBuffer();
    content.writeln("""local lua_modules = mp.find_config_file('scripts')
if lua_modules then
  package.path = package.path .. ';' .. lua_modules .. '/?.lua;' .. lua_modules .. '/?/init.lua;' .. '\${scriptsDir()!!.filePath}' .. '/?.lua'
end
local aniyomi = require 'init_aniyomi_functions'""");
    for (final button in customButtons) {
      content.writeln(
        """
${button.getButtonStartup(primaryButton.id!).trim()}
function button${button.id}()
  ${button.getButtonPress(primaryButton.id!).trim()}
end
mp.register_script_message('call_button_${button.id}', button${button.id})
function button${button.id}long()
  ${button.getButtonLongPress(primaryButton.id!).trim()}
end
mp.register_script_message('call_button_${button.id}_long', button${button.id}long)""",
      );
    }
    await mpvFile.writeAsString(content.toString());
    await (_player.platform as NativePlayer).command([
      "load-script",
      mpvFile.path,
    ]);
    _customButton.value = ActiveCustomButton(
      currentTitle: primaryButton.title!,
      visible: true,
      button: primaryButton,
      onPress: () => (_player.platform as NativePlayer).command([
        "script-message",
        "call_button_${primaryButton.id}",
      ]),
      onLongPress: () => (_player.platform as NativePlayer).command([
        "script-message",
        "call_button_${primaryButton.id}_long",
      ]),
    );
    _customButtons.value = customButtons;
  }

  void pushToNewEpisode(BuildContext context, Chapter episode) {
    widget.desktopFullScreenPlayer.call(ref.read(fullscreenProvider));
    if (context.mounted) {
      pushReplacementMangaReaderView(context: context, chapter: episode);
    }
  }

  void _unifiedPositionHandler(Duration position) {
    final currentSecs = position.inSeconds;
    _setCurrentAudSub(position, currentSecs);
    _setSkipPhase(currentSecs);
  }

  void _setCurrentAudSub(Duration position, int secs) {
    final totalSecs = _player.state.duration.inSeconds;
    _isCompleted.value = (totalSecs - secs) <= 10;
    _currentPosition.value = position;
    if (_initSubtitleAndAudio) {
      _initSubtitleAndAudio = false;
      if (_firstVid.subtitles?.isNotEmpty ?? false) {
        try {
          final defaultTrack = _firstVid.subtitles!.firstWhere(
            (sub) => sub.label == widget.defaultSubtitle,
            orElse: () => _firstVid.subtitles!.first,
          );
          final file = defaultTrack.file ?? "";
          final label = defaultTrack.label;
          final track = (file.startsWith("http") || file.startsWith("file"))
              ? SubtitleTrack.uri(file, title: label, language: label)
              : SubtitleTrack.data(file, title: label, language: label);
          _player.setSubtitleTrack(track);
        } catch (_) {}
        if (_firstVid.audios?.isNotEmpty ?? false) {
          try {
            final at = _firstVid.audios!.first;
            _player.setAudioTrack(
              AudioTrack.uri(
                at.file ?? "",
                title: at.label,
                language: at.label,
              ),
            );
          } catch (_) {}
        }
      }
    }
  }

  void _setSkipPhase(int secs) {
    _AniSkipPhase newPhase;
    if (_hasOpeningSkip &&
        secs >= _openingResult!.interval!.startTime!.ceil() &&
        secs < _openingResult!.interval!.endTime!.toInt()) {
      newPhase = _AniSkipPhase.opening;
    } else if (_hasEndingSkip &&
        secs >= _endingResult!.interval!.startTime!.ceil() &&
        secs < _endingResult!.interval!.endTime!.toInt()) {
      newPhase = _AniSkipPhase.ending;
    } else {
      newPhase = _AniSkipPhase.none;
    }
    if (_skipPhase.value != newPhase) _skipPhase.value = newPhase;
  }

  void _updateRpcTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastRpcTimestampUpdate + 5000 < now) {
      if (_currentTotalDuration.value != null) {
        discordRpc?.updateChapterTimestamp(
          _currentPosition.value,
          _currentTotalDuration.value!,
        );
      }
      lastRpcTimestampUpdate = now;
    }
  }

  void _onSubDelayChanged() {
    final nativePlayer = (_player.platform as NativePlayer);
    final delayMs = int.tryParse(_subDelayController.text);
    if (delayMs != null) {
      final namePtr = "sub-delay".toNativeUtf8();
      final valuePtr = calloc<Double>(1)..value = delayMs / 1000;
      nativePlayer.mpv.mpv_set_property(
        nativePlayer.ctx,
        namePtr.cast(),
        generated.mpv_format.MPV_FORMAT_DOUBLE,
        valuePtr.cast(),
      );
      malloc.free(namePtr);
      malloc.free(valuePtr);
      _subDelay = delayMs;
    }
  }

  void _onSubSpeedChanged() {
    final nativePlayer = (_player.platform as NativePlayer);
    final speed = double.tryParse(_subSpeedController.text);
    if (speed != null) {
      final namePtr = "sub-speed".toNativeUtf8();
      final valuePtr = calloc<Double>(1)
        ..value = speed < 0.1
            ? 0.1
            : speed > 10
            ? 10
            : speed;
      nativePlayer.mpv.mpv_set_property(
        nativePlayer.ctx,
        namePtr.cast(),
        generated.mpv_format.MPV_FORMAT_DOUBLE,
        valuePtr.cast(),
      );
      malloc.free(namePtr);
      malloc.free(valuePtr);
      _subSpeed = speed;
    }
  }

  @override
  void initState() {
    super.initState();
    _watchStopwatch.start();
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        hwdec: hwdecMode,
        enableHardwareAcceleration: enableHardwareAccel,
        vo: Platform.isAndroid
            ? useGpuNext
                  ? "gpu-next"
                  : "gpu"
            : "libmpv",
      ),
    );
    // If player is being launched the first time,
    // use global "Use Fullscreen" setting.
    // Else (if user already watches an episode and just changes it),
    // stay in the same mode, the user left it in.
    try {
      final defaultSkipIntroLength = ref.read(
        defaultSkipIntroLengthStateProvider,
      );
      (_player.platform as NativePlayer).setProperty(
        "user-data/current-anime/intro-length",
        "$defaultSkipIntroLength",
      );
    } catch (_) {}
    if (_isDesktop && _firstTime) {
      final globalFullscreen = ref.read(fullScreenPlayerStateProvider);
      // Delay fullscreen until after the first frame so the window is ready.
      // On Windows, calling setFullScreen before the widget tree is built
      // can silently fail, leaving the title bar visible.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setFullScreen(value: globalFullscreen);
        ref.read(fullscreenProvider.notifier).state = globalFullscreen;
        widget.desktopFullScreenPlayer.call(globalFullscreen);
      });
      _firstTime = false;
    }
    if (!_isDesktop) {
      final forceLandscape = ref.read(forceLandscapePlayerStateProvider);
      if (forceLandscape) {
        _setLandscapeMode(true);
      }
    }
    _currentPositionSub = _player.stream.position.listen(
      _unifiedPositionHandler,
    );
    _completed;
    _currentTotalDurationSub;
    _loadAndroidFont().then((_) {
      _openMedia(_video.value!, _streamController.geTCurrentPosition());
      if (widget.isTorrent) {
        Future.delayed(const Duration(seconds: 10)).then((_) {
          if (mounted) {
            _openMedia(_video.value!, _streamController.geTCurrentPosition());
          }
        });
      }
      _setPlaybackSpeed(ref.read(defaultPlayBackSpeedStateProvider));
      if (ref.read(enableAniSkipStateProvider)) _initAniSkip();
    });
    _initCustomButton().catchError((_) {});
    discordRpc?.showChapterDetails(ref, widget.episode);
    _currentPosition.addListener(_updateRpcTimestamp);
    _subDelayController.addListener(_onSubDelayChanged);
    _subSpeedController.addListener(_onSubSpeedChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _watchStopwatch.stop();
      _setCurrentPosition(true);
    } else if (state == AppLifecycleState.resumed) {
      _watchStopwatch.start();
    }
  }

  Future<void> _openMedia(VideoPrefs prefs, [Duration? position]) {
    final url = prefs.videoTrack!.id;
    final ext = widget.episode.manga.value?.source ?? '?';
    final title = widget.episode.name ?? '?';
    final isHls = url.contains('.m3u8') || url.contains('m3u8');
    AppLogger.log(
      'WATCH open · ext=$ext · ep="$title" · ${isHls ? 'HLS' : 'direct'} · '
      'start=${(position ?? _currentPosition.value).inSeconds}s',
      tag: LogTag.watch,
      logLevel: LogLevel.info,
    );
    AppLogger.log('WATCH url=$url', tag: LogTag.watch, logLevel: LogLevel.debug);
    _armBufferingWatchdog();
    return _player.open(
      Media(
        url,
        httpHeaders: prefs.headers,
        start: position ?? _currentPosition.value,
      ),
    );
  }

  // ── Buffering watchdog ───────────────────────────────────────────────────
  // The user reported videos stuck "loading" for ~20 minutes with no error.
  // We listen to the player's buffering stream: each time it flips to true,
  // arm a 60-second timer. If buffering is still true when the timer fires,
  // we log an error and bubble it through the existing error sink so the UI
  // stops pretending everything's fine.
  StreamSubscription<bool>? _bufferingSub;
  Timer? _bufferingWatchdog;
  DateTime? _bufferingStartedAt;

  void _armBufferingWatchdog() {
    _bufferingSub ??= _player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _bufferingStartedAt = DateTime.now();
        _bufferingWatchdog?.cancel();
        AppLogger.log(
          'WATCH buffering: started',
          tag: LogTag.watch,
          logLevel: LogLevel.debug,
        );
        _bufferingWatchdog = Timer(const Duration(seconds: 60), () {
          if (!mounted) return;
          // Still buffering after 60 s with no progress at all → call it.
          final secs = _bufferingStartedAt == null
              ? 60
              : DateTime.now().difference(_bufferingStartedAt!).inSeconds;
          AppLogger.log(
            'WATCH buffering: bloqué depuis ${secs}s sans progression → '
            'arrêt forcé du chargement.',
            tag: LogTag.watch,
            logLevel: LogLevel.error,
          );
          try {
            _player.stop();
          } catch (_) {}
          if (mounted) {
            try {
              botToast(
                'Lecture bloquée — la source ne répond pas (${secs}s sans données). '
                'Essaie une autre source.',
                second: 6,
              );
            } catch (_) {}
          }
        });
      } else {
        if (_bufferingWatchdog != null && _bufferingStartedAt != null) {
          final secs =
              DateTime.now().difference(_bufferingStartedAt!).inSeconds;
          AppLogger.log(
            'WATCH buffering: terminé après ${secs}s',
            tag: LogTag.watch,
            logLevel: LogLevel.debug,
          );
        }
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = null;
        _bufferingStartedAt = null;
      }
    });
  }

  Future<void> _loadAndroidFont() async {
    if (Platform.isAndroid && useLibass) {
      try {
        final subDir = await getApplicationDocumentsDirectory();
        final fontPath = path.join(subDir.path, 'subfont.ttf');
        final fontFile = File(fontPath);

        // Utilise le cache local si la police est déjà présente
        if (!await fontFile.exists() || await fontFile.length() < 1024) {
          const fontUrl =
              'https://raw.githubusercontent.com/ferelking242/watchtower/main/assets/fonts/subfont.ttf';
          final res = await http.get(Uri.parse(fontUrl));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            await fontFile.create(recursive: true);
            await fontFile.writeAsBytes(res.bodyBytes);
          }
        }

        if (await fontFile.exists() && await fontFile.length() > 1024) {
          await (_player.platform as NativePlayer).setProperty(
            'sub-fonts-dir',
            subDir.path,
          );
          await (_player.platform as NativePlayer).setProperty(
            'sub-font',
            'Droid Sans Fallback',
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _initAniSkip() async {
    await _player.stream.buffer.first;
    _streamController.getAniSkipResults((result) {
      final openingRes = result
          .where((element) => element.skipType == "op")
          .toList();
      _hasOpeningSkip = openingRes.isNotEmpty;
      if (_hasOpeningSkip) _openingResult = openingRes.first;
      final endingRes = result
          .where((element) => element.skipType == "ed")
          .toList();
      _hasEndingSkip = endingRes.isNotEmpty;
      if (_hasEndingSkip) _endingResult = endingRes.first;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _watchStopwatch.stop();
    _currentPosition.removeListener(_updateRpcTimestamp);
    _subDelayController.removeListener(_onSubDelayChanged);
    _subSpeedController.removeListener(_onSubSpeedChanged);
    WidgetsBinding.instance.removeObserver(this);
    _setCurrentPosition(true, saveWatchTime: true);
    _player.stop();
    _completed.cancel();
    _bufferingSub?.cancel();
    _bufferingWatchdog?.cancel();
    _currentPositionSub.cancel();
    _currentTotalDurationSub.cancel();
    _currentPosition.dispose();
    _currentTotalDuration.dispose();
    _video.dispose();
    _playbackSpeed.dispose();
    _isDoubleSpeed.dispose();
    _showFitLabel.dispose();
    _isCompleted.dispose();
    _tempPosition.dispose();
    _fit.dispose();
    _skipPhase.dispose();
    _subDelayController.dispose();
    _subSpeedController.dispose();
    if (!_isDesktop) _setLandscapeMode(false);
    discordRpc?.showIdleText();
    discordRpc?.showOriginalTimestamp();
    _streamController.close();
    _player.dispose();
    super.dispose();
  }

  void _setCurrentPosition(bool save, {bool saveWatchTime = false}) {
    _streamController.setCurrentPosition(
      _currentPosition.value,
      _currentTotalDuration.value,
      save: save,
    );
    _streamController.setAnimeHistoryUpdate(
      watchTimeSeconds: saveWatchTime ? _watchStopwatch.elapsed.inSeconds : 0,
    );
  }

  void _setLandscapeMode(bool state) {
    if (state) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Widget textWidget(String text, bool selected) => Row(
    children: [
      Flexible(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).padding.top,
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontSize: 16,
              fontStyle: selected ? FontStyle.italic : null,
              color: selected ? context.primaryColor : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
  );

  Widget _videoQualityWidget(BuildContext context) {
    List<VideoPrefs> videoQuality = _player.state.tracks.video
        .where(
          (element) => element.w != null && element.h != null && widget.isLocal,
        )
        .toList()
        .map((e) => VideoPrefs(videoTrack: e, isLocal: true))
        .toList();

    if (widget.videos.isNotEmpty && !widget.isLocal) {
      for (var video in widget.videos) {
        videoQuality.add(
          VideoPrefs(
            videoTrack: VideoTrack(video.url, video.quality, video.quality),
            headers: video.headers,
            isLocal: false,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      child: Column(
        children: videoQuality.map((quality) {
          final selected =
              _video.value!.videoTrack!.title == quality.videoTrack!.title ||
              widget.isLocal;
          return GestureDetector(
            child: textWidget(
              widget.isLocal ? _firstVid.quality : quality.videoTrack!.title!,
              selected,
            ),
            onTap: () async {
              if (_video.value?.videoTrack?.id == quality.videoTrack?.id) {
                Navigator.pop(context);
                return;
              }
              _video.value = quality;
              _player.stop();
              if (quality.isLocal) {
                if (widget.isLocal) {
                  _player.setVideoTrack(quality.videoTrack!);
                } else {
                  _openMedia(quality);
                }
              } else {
                _openMedia(quality);
              }
              _initSubtitleAndAudio = true;
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _videoSettingDraggableMenu(BuildContext context) async {
    final l10n = l10nLocalizations(context)!;
    bool hasSubtitleTrack = false;
    _player.pause();
    await customDraggableTabBar(
      tabs: [
        Tab(text: l10n.video_quality),
        Tab(text: l10n.video_subtitle),
        Tab(text: l10n.video_audio),
      ],
      children: [
        _videoQualityWidget(context),
        _videoSubtitle(context, (value) => hasSubtitleTrack = value),
        _videoAudios(context),
      ],
      context: context,
      vsync: this,
      fullWidth: true,
      moreWidget: IconButton(
        onPressed: () async {
          if (useLibass) {
            botToast(context.l10n.libass_not_disable_message, second: 2);
          } else {
            await customDraggableTabBar(
              tabs: [
                Tab(text: l10n.font),
                Tab(text: l10n.color),
              ],
              children: [
                FontSettingWidget(hasSubtitleTrack: hasSubtitleTrack),
                ColorSettingWidget(hasSubtitleTrack: hasSubtitleTrack),
              ],
              context: context,
              vsync: this,
              fullWidth: true,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        icon: const Icon(Icons.settings_outlined),
      ),
    );
    setState(() {});
    _player.play();
  }

  Widget _videoSubtitle(BuildContext context, Function(bool) hasSubtitleTrack) {
    List<VideoPrefs> videoSubtitle = _player.state.tracks.subtitle
        .toList()
        .map((e) => VideoPrefs(isLocal: true, subtitle: e))
        .toList();

    List<String> subs = [];
    if (widget.videos.isNotEmpty) {
      for (var video in widget.videos) {
        for (var sub in video.subtitles ?? []) {
          if (sub.file == null || sub.file!.isEmpty) continue;
          if (!subs.contains(sub.file)) {
            final file = sub.file!;
            final label = sub.label;
            videoSubtitle.add(
              VideoPrefs(
                isLocal: widget.isLocal,
                subtitle: (file.startsWith("http") || file.startsWith("file"))
                    ? SubtitleTrack.uri(file, title: label, language: label)
                    : SubtitleTrack.data(file, title: label, language: label),
              ),
            );
            subs.add(sub.file!);
          }
        }
      }
    }
    final subtitle = _player.state.track.subtitle;
    videoSubtitle = videoSubtitle
        .map((e) {
          VideoPrefs vid = e;
          vid.title =
              vid.subtitle?.title ??
              vid.subtitle?.language ??
              vid.subtitle?.channels ??
              "";
          return vid;
        })
        .toList()
        .where((element) => (element.title ?? '').isNotEmpty)
        .toList();
    videoSubtitle.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
    hasSubtitleTrack.call(videoSubtitle.isNotEmpty);
    videoSubtitle.insert(
      0,
      VideoPrefs(isLocal: false, subtitle: SubtitleTrack.no()),
    );
    List<VideoPrefs> videoSubtitleLast = [];
    for (var element in videoSubtitle) {
      final contains = videoSubtitleLast.any((sub) {
        return (sub.title ??
                sub.subtitle?.title ??
                sub.subtitle?.language ??
                sub.subtitle?.channels ??
                "None") ==
            (element.title ??
                element.subtitle?.title ??
                element.subtitle?.language ??
                element.subtitle?.channels ??
                "None");
      });
      if (!contains) {
        videoSubtitleLast.add(element);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(context.l10n.subtitle_delay_text),
              IconButton(
                onPressed: () {
                  _subDelay = 0;
                  _subDelayController.value = TextEditingValue(
                    text: "$_subDelay",
                  );
                  _subSpeed = 1;
                  _subSpeedController.value = TextEditingValue(
                    text: _subSpeed.toStringAsFixed(2),
                  );
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _subDelay -= 50;
                  _subDelayController.value = TextEditingValue(
                    text: "$_subDelay",
                  );
                },
                icon: const Icon(Icons.remove_circle),
              ),
              Expanded(
                child: TextFormField(
                  controller: _subDelayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    label: Text(context.l10n.subtitle_delay),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _subDelay += 50;
                  _subDelayController.value = TextEditingValue(
                    text: "$_subDelay",
                  );
                },
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _subSpeed -= 0.01;
                  _subSpeedController.value = TextEditingValue(
                    text: _subSpeed.toStringAsFixed(2),
                  );
                },
                icon: const Icon(Icons.remove_circle),
              ),
              Expanded(
                child: TextFormField(
                  controller: _subSpeedController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    label: Text(context.l10n.subtitle_speed),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _subSpeed += 0.01;
                  _subSpeedController.value = TextEditingValue(
                    text: _subSpeed.toStringAsFixed(2),
                  );
                },
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ...videoSubtitleLast.toSet().toList().map((sub) {
            final rawTitle =
                sub.title ??
                sub.subtitle?.title ??
                sub.subtitle?.language ??
                sub.subtitle?.channels ??
                "None";
            final title = rawTitle == "None" ? "None" : _normTrackLabel(rawTitle);

            final selected =
                (title ==
                    (subtitle.title ??
                        subtitle.language ??
                        subtitle.channels ??
                        "None")) ||
                (subtitle.id == "no" && title == "None");
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                try {
                  _player.setSubtitleTrack(sub.subtitle!);
                } catch (_) {}
              },
              child: textWidget(title, selected),
            );
          }),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () async {
              try {
                FilePickerResult? result = await FilePicker.pickFiles(
                  allowMultiple: false,
                );

                if (result != null && context.mounted) {
                  _player.setSubtitleTrack(
                    SubtitleTrack.uri(result.files.first.path!),
                  );
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                botToast("Error: $e");
                Navigator.pop(context);
              }
            },
            child: textWidget(context.l10n.load_own_subtitles, false),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () async {
              try {
                final subtitle =
                    await subtitlesSearchraggableMenu(
                          context,
                          chapter: widget.episode,
                          isLocal: widget.isLocal,
                        )
                        as ImdbSubtitle?;
                if (subtitle != null && context.mounted) {
                  _player.setSubtitleTrack(
                    SubtitleTrack.uri(
                      subtitle.url!,
                      title: subtitle.language,
                      language: subtitle.language,
                    ),
                  );
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (_) {
                botToast("Error");
                Navigator.pop(context);
              }
            },
            child: textWidget(context.l10n.search_subtitles, false),
          ),
        ],
      ),
    );
  }

  Widget _videoAudios(BuildContext context) {
    List<VideoPrefs> videoAudio = _player.state.tracks.audio
        .toList()
        .map((e) => VideoPrefs(isLocal: true, audio: e))
        .toList();

    List<String> audios = [];
    if (widget.videos.isNotEmpty && !widget.isLocal) {
      for (var video in widget.videos) {
        for (var audio in video.audios ?? []) {
          if (!audios.contains(audio.file)) {
            videoAudio.add(
              VideoPrefs(
                isLocal: false,
                audio: AudioTrack.uri(
                  audio.file!,
                  title: audio.label,
                  language: audio.label,
                ),
              ),
            );
            audios.add(audio.file!);
          }
        }
      }
    }
    final audio = _player.state.track.audio;
    videoAudio = videoAudio
        .map((e) {
          VideoPrefs vid = e;
          vid.title =
              vid.audio?.title ??
              vid.audio?.language ??
              vid.audio?.channels ??
              "";
          return vid;
        })
        .toList()
        .where((element) => element.title!.isNotEmpty)
        .toList();
    videoAudio.sort((a, b) => a.title!.compareTo(b.title!));
    videoAudio.insert(0, VideoPrefs(isLocal: false, audio: AudioTrack.no()));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      child: Column(
        children: videoAudio.toSet().toList().map((aud) {
          final rawTitle =
              aud.title ??
              aud.audio?.title ??
              aud.audio?.language ??
              aud.audio?.channels ??
              "None";
          final title = rawTitle == "None" ? "None" : _normTrackLabel(rawTitle);
          final selected =
              (aud.audio == audio) || (audio.id == "no" && rawTitle == "None");
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              try {
                _player.setAudioTrack(aud.audio!);
              } catch (_) {}
            },
            child: textWidget(title, selected),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
    _playbackSpeed.value = speed;
  }

  Future<void> _changeFitLabel(WidgetRef ref) async {
    List<BoxFit> fitList = [
      BoxFit.contain,
      BoxFit.cover,
      BoxFit.fill,
      BoxFit.fitHeight,
      BoxFit.fitWidth,
      BoxFit.scaleDown,
      BoxFit.none,
    ];
    _showFitLabel.value = true;
    BoxFit? fit;
    if (fitList.indexOf(_fit.value) < fitList.length - 1) {
      fit = fitList[fitList.indexOf(_fit.value) + 1];
    } else {
      fit = fitList[0];
    }
    _fit.value = fit;
    _key.currentState?.update(fit: fit);
    botToast(fit.name.toUpperCase(), second: 1);
  }

  Widget _seekToWidget() {
    final defaultSkipIntroLength = ref.watch(
      defaultSkipIntroLengthStateProvider,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: 35,
        child: ValueListenableBuilder(
          valueListenable: _customButton,
          builder: (context, value, child) => (value?.visible ?? true)
              ? ElevatedButton(
                  onPressed:
                      value?.onPress ??
                      () async {
                        _tempPosition.value = Duration(
                          seconds:
                              defaultSkipIntroLength +
                              _currentPosition.value.inSeconds,
                        );
                        await _player.seek(
                          Duration(
                            seconds:
                                _currentPosition.value.inSeconds +
                                defaultSkipIntroLength,
                          ),
                        );
                        _tempPosition.value = null;
                      },
                  onLongPress: value?.onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      value != null
                          ? value.currentTitle
                          : "+$defaultSkipIntroLength",
                      style: const TextStyle(fontWeight: FontWeight.w100),
                    ),
                  ),
                )
              : Container(),
        ),
      ),
    );
  }

  Widget _chapterMarkWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: SizedBox(
        height: 35,
        child: ValueListenableBuilder(
          valueListenable: _currentChapterMark,
          builder: (context, value, child) => value != null
              ? ArrowPopupMenuButton<int>(
                  tooltip: '',
                  itemBuilder: (context) => _chapterMarks.value
                      .map(
                        (mark) => PopupMenuItem<int>(
                          value: mark.$2,
                          child: Text(
                            "${mark.$1} - ${Duration(milliseconds: mark.$2).label()}",
                          ),
                          onTap: () =>
                              _player.seek(Duration(milliseconds: mark.$2)),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${_chapterMarks.value[value].$1} - ${Duration(milliseconds: _chapterMarks.value[value].$2).label()}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Container(),
        ),
      ),
    );
  }

  Widget _mobileBottomButtonBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (hasPrevEpisode)
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () async {
                      pushToNewEpisode(
                        context,
                        _streamController.getPrevEpisode(),
                      );
                    },
                  ),
                CustomPlayOrPauseButton(
                  controller: _controller,
                  isDesktop: false,
                ),
                if (hasNextEpisode)
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () async {
                      pushToNewEpisode(
                        context,
                        _streamController.getNextEpisode(),
                      );
                    },
                  ),
                _seekToWidget(),
                Expanded(
                  child: Text(
                    widget.episode.name ??
                        widget.episode.manga.value!.name!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                _chapterMarkWidget(),
                _buildSettingsButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBottomButtonBar(BuildContext context) {
    bool hasPrevEpisode =
        _streamController.getEpisodeIndex().$1 + 1 !=
        _streamController.getEpisodesLength(
          _streamController.getEpisodeIndex().$2,
        );
    final skipDuration = ref.watch(defaultDoubleTapToSkipLengthStateProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (hasPrevEpisode)
                  IconButton(
                    onPressed: () {
                      pushToNewEpisode(
                        context,
                        _streamController.getPrevEpisode(),
                      );
                    },
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                  ),
                CustomPlayOrPauseButton(
                  controller: _controller,
                  isDesktop: _isDesktop,
                ),
                if (hasNextEpisode)
                  IconButton(
                    onPressed: () async {
                      pushToNewEpisode(
                        context,
                        _streamController.getNextEpisode(),
                      );
                    },
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                  ),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: IconButton(
                    onPressed: () async {
                      _tempPosition.value = Duration(
                        seconds:
                            skipDuration - _currentPosition.value.inSeconds,
                      );
                      await _player.seek(
                        Duration(
                          seconds:
                              _currentPosition.value.inSeconds - skipDuration,
                        ),
                      );
                      _tempPosition.value = null;
                    },
                    icon: Stack(
                      children: [
                        const Positioned.fill(
                          child: Icon(
                            Icons.rotate_left_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                skipDuration.toString(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: IconButton(
                    onPressed: () async {
                      _tempPosition.value = Duration(
                        seconds:
                            skipDuration + _currentPosition.value.inSeconds,
                      );
                      await _player.seek(
                        Duration(
                          seconds:
                              _currentPosition.value.inSeconds + skipDuration,
                        ),
                      );
                      _tempPosition.value = null;
                    },
                    icon: Stack(
                      children: [
                        const Positioned.fill(
                          child: Icon(
                            Icons.rotate_right_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                skipDuration.toString(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CustomMaterialDesktopVolumeButton(controller: _controller),
                ValueListenableBuilder(
                  valueListenable: _tempPosition,
                  builder: (context, value, child) =>
                      CustomMaterialDesktopPositionIndicator(
                        delta: value,
                        controller: _controller,
                      ),
                ),
                _chapterMarkWidget(),
              ],
            ),
            _buildSettingsButtons(context),
          ],
        ),
      ],
    );
  }

  // ── OPlayer-style side panel (right edge, 60 % width, 100 % height) ──────────

  void _showSettingsPanel(BuildContext context) {
    setState(() {
      _sidePanelOpen = !_sidePanelOpen;
      _sidePanelTab = 0;
    });
  }

  Widget _buildSidePanelOverlay(BuildContext context) {
    if (!_sidePanelOpen) return const SizedBox.shrink();
    final panelWidth = MediaQuery.of(context).size.width * 0.60;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _sidePanelOpen = false),
        child: Stack(
          children: [
            // Dim backdrop
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _sidePanelOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 240),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            // Panel itself — slides from the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb taps inside the panel
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xEE0D0D1A),
                        border: Border(
                          left: BorderSide(
                            color: Colors.white.withValues(alpha: 0.09),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Tab bar ───────────────────────────────────────
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                              child: Row(
                                children: [
                                  _PanelTab(
                                    label: 'Paramètres',
                                    selected: _sidePanelTab == 0,
                                    onTap: () => setState(
                                        () => _sidePanelTab = 0),
                                  ),
                                  const SizedBox(width: 8),
                                  _PanelTab(
                                    label: 'Épisodes',
                                    selected: _sidePanelTab == 1,
                                    onTap: () => setState(
                                        () => _sidePanelTab = 1),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white54, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    onPressed: () => setState(
                                        () => _sidePanelOpen = false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 0.5,
                            margin: const EdgeInsets.only(top: 10),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          // ── Content ───────────────────────────────────────
                          Expanded(
                            child: IndexedStack(
                              index: _sidePanelTab,
                              children: [
                                // Tab 0 – Settings
                                _buildPanelSettings(context),
                                // Tab 1 – Episodes
                                _buildPanelEpisodes(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _PlayerSettingsDialog(
        inline: true,
        player: _player,
        fit: _fit.value,
        doubleTapSkip: ref.read(defaultDoubleTapToSkipLengthStateProvider),
        introSkip: ref.read(defaultSkipIntroLengthStateProvider),
        playbackSpeed: ref.read(defaultPlayBackSpeedStateProvider),
        useLibassVal: useLibass,
        enableHwAccel: enableHardwareAccel,
        hwdecModeVal: hwdecMode,
        forceLandscape: ref.read(forceLandscapePlayerStateProvider),
        useMpvConfigVal: useMpvConfig,
        useGpuNextVal: useGpuNext,
        audioPreferredLangVal: audioPreferredLang,
        enableAniSkipVal: ref.read(enableAniSkipStateProvider),
        enableAutoSkipVal: ref.read(enableAutoSkipStateProvider),
        onDoubleTapSkipChange: (v) =>
            ref.read(defaultDoubleTapToSkipLengthStateProvider.notifier).set(v),
        onIntroSkipChange: (v) =>
            ref.read(defaultSkipIntroLengthStateProvider.notifier).set(v),
        onSpeedChange: (v) => _setPlaybackSpeed(v),
        onForceLandscapeChange: (v) {
          ref.read(forceLandscapePlayerStateProvider.notifier).set(v);
          _setLandscapeMode(v);
        },
        onEnableAniSkipChange: (v) =>
            ref.read(enableAniSkipStateProvider.notifier).set(v),
        onEnableAutoSkipChange: (v) =>
            ref.read(enableAutoSkipStateProvider.notifier).set(v),
      ),
    );
  }

  Widget _buildPanelEpisodes(BuildContext context) {
    final manga = widget.episode.manga.value;
    final episodes = manga?.chapters.toList().reversed.toList() ?? <dynamic>[];
    final currentId = widget.episode.id;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final ep = episodes[index] as Chapter;
        final isCurrent = ep.id == currentId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isCurrent) return;
              setState(() => _sidePanelOpen = false);
              pushToNewEpisode(context, ep);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: isCurrent
                  ? BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    )
                  : null,
              child: Text(
                ep.name ?? 'Épisode ${index + 1}',
                style: TextStyle(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMpvSettingsButton(BuildContext context) {
    return [
      ArrowPopupMenuButton<String>(
        tooltip: 'Shaders',
        icon: const Icon(Icons.high_quality, color: Colors.white),
        itemBuilder: (context) =>
            [
                  ("Anime4K: Mode A (Fast)", "set_anime_a"),
                  ("Anime4K: Mode B (Fast)", "set_anime_b"),
                  ("Anime4K: Mode C (Fast)", "set_anime_c"),
                  ("Anime4K: Mode A+A (Fast)", "set_anime_aa"),
                  ("Anime4K: Mode B+B (Fast)", "set_anime_bb"),
                  ("Anime4K: Mode C+A (Fast)", "set_anime_ca"),
                  ("Anime4K: Mode A (HQ)", "set_anime_hq_a"),
                  ("Anime4K: Mode B (HQ)", "set_anime_hq_b"),
                  ("Anime4K: Mode C (HQ)", "set_anime_hq_c"),
                  ("Anime4K: Mode A+A (HQ)", "set_anime_hq_aa"),
                  ("Anime4K: Mode B+B (HQ)", "set_anime_hq_bb"),
                  ("Anime4K: Mode C+A (HQ)", "set_anime_hq_ca"),
                  ("AMD FSR", "set_fsr"),
                  ("Luma Upscaling", "set_luma"),
                  ("Qualcomm Snapdragon GSR", "set_snapdragon"),
                  ("NVIDIA Image Scaling", "set_nvidia"),
                  ("Clear GLSL shaders", "clear_anime"),
                ]
                .map(
                  (mode) => PopupMenuItem<String>(
                    value: mode.$1,
                    child: Text(
                      mode.$1,
                      style: TextStyle(
                        fontWeight: _selectedShader.value == mode.$1
                            ? FontWeight.w900
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      (_player.platform as NativePlayer).command([
                        "script-message",
                        mode.$2,
                      ]);
                    },
                  ),
                )
                .toList(),
      ),
      ArrowPopupMenuButton<String>(
        tooltip: 'Stats',
        icon: const Icon(Icons.memory, color: Colors.white),
        itemBuilder: (context) =>
            [
                  ("Stats Toggle", "stats/display-stats-toggle"),
                  ("Stats Page 1", "stats/display-page-1"),
                  ("Stats Page 2", "stats/display-page-2"),
                  ("Stats Page 3", "stats/display-page-3"),
                  ("Stats Page 4", "stats/display-page-4"),
                  ("Stats Page 5", "stats/display-page-5"),
                ]
                .map(
                  (mode) => PopupMenuItem<String>(
                    value: mode.$1,
                    child: Text(
                      mode.$1,
                      style: TextStyle(
                        fontWeight: _selectedShader.value == mode.$1
                            ? FontWeight.w900
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      (_player.platform as NativePlayer).command([
                        "script-binding",
                        mode.$2,
                      ]);
                    },
                  ),
                )
                .toList(),
      ),
      ValueListenableBuilder(
        valueListenable: _customButtons,
        builder: (context, value, child) => value != null
            ? ArrowPopupMenuButton<String>(
                tooltip: context.l10n.custom_buttons,
                icon: const Icon(Icons.terminal, color: Colors.white),
                itemBuilder: (context) => value
                    .map(
                      (btn) => PopupMenuItem<String>(
                        value: btn.title!,
                        child: Text(btn.title!),
                        onTap: () {
                          (_player.platform as NativePlayer).command([
                            "script-message",
                            "call_button_${btn.id}",
                          ]);
                        },
                      ),
                    )
                    .toList(),
              )
            : Container(),
      ),
    ];
  }

  /// helper method for _mobileBottomButtonBar() and _desktopBottomButtonBar()
  Widget _buildSettingsButtons(BuildContext context) {
    final isFullscreen = ref.watch(fullscreenProvider);
    return Row(
      children: [
        IconButton(
          padding: _isDesktop ? EdgeInsets.zero : const EdgeInsets.all(5),
          onPressed: () => _videoSettingDraggableMenu(context),
          icon: const Icon(Icons.video_settings, color: Colors.white),
        ),
        if (useMpvConfig) ..._buildMpvSettingsButton(context),
        ValueListenableBuilder<double>(
          valueListenable: _playbackSpeed,
          builder: (context, currentSpeed, _) => ArrowPopupMenuButton<double>(
            tooltip: '',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.speed, color: Colors.white),
                if (currentSpeed != 1.0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${currentSpeed}x',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) =>
                [0.25, 0.5, 0.75, 1.0, 1.25, 1.50, 1.75, 2.0]
                    .map(
                      (speed) => PopupMenuItem<double>(
                        value: speed,
                        onTap: () => _setPlaybackSpeed(speed),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: currentSpeed == speed
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                            ),
                            Text(
                              '${speed}x',
                              style: TextStyle(
                                fontWeight: currentSpeed == speed
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        // ── Fit / format picker ────────────────────────────────────────────
        ValueListenableBuilder<BoxFit>(
          valueListenable: _fit,
          builder: (context, currentFit, _) {
            const fits = <(BoxFit, String)>[
              (BoxFit.contain, 'Contenir'),
              (BoxFit.cover, 'Couvrir'),
              (BoxFit.fill, 'Remplir'),
              (BoxFit.fitWidth, 'Largeur'),
              (BoxFit.fitHeight, 'Hauteur'),
              (BoxFit.none, 'Original'),
            ];
            return ArrowPopupMenuButton<BoxFit>(
              tooltip: '',
              icon: const Icon(Icons.fit_screen_outlined, color: Colors.white),
              itemBuilder: (context) => fits
                  .map(
                    (pair) => PopupMenuItem<BoxFit>(
                      value: pair.$1,
                      onTap: () {
                        setState(() => _fit.value = pair.$1);
                        _resize(pair.$1);
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: currentFit == pair.$1
                                ? Icon(
                                    Icons.check,
                                    size: 15,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                          ),
                          Text(
                            pair.$2,
                            style: TextStyle(
                              fontWeight: currentFit == pair.$1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (_isDesktop)
          CustomMaterialDesktopFullscreenButton(
            controller: _controller,
            desktopFullScreenPlayer: widget.desktopFullScreenPlayer,
          )
        else
          IconButton(
            icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            iconSize: 25,
            color: Colors.white,
            onPressed: () {
              if (isFullscreen) {
                _setLandscapeMode(false);
                ref.read(fullscreenProvider.notifier).state = false;
                widget.desktopFullScreenPlayer.call(false);
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              } else {
                _setLandscapeMode(true);
                ref.read(fullscreenProvider.notifier).state = true;
                widget.desktopFullScreenPlayer.call(true);
              }
            },
          ),
      ],
    );
  }

  Widget _subtitleTopButton(BuildContext context) {
    return StreamBuilder(
      stream: _player.stream.tracks,
      builder: (context, _) {
        final currentSub = _player.state.track.subtitle;
        final tracks = _player.state.tracks.subtitle
            .where((t) => (t.title ?? t.language ?? '').isNotEmpty)
            .toList();
        final items = <PopupMenuEntry<String>>[];
        items.add(PopupMenuItem<String>(
          value: 'no',
          onTap: () => _player.setSubtitleTrack(SubtitleTrack.no()),
          child: textWidget('Désactivé', currentSub.id == 'no'),
        ));
        for (final track in tracks) {
          final rawLabel = track.title ?? track.language ?? '';
          final label = _normTrackLabel(rawLabel);
          items.add(PopupMenuItem<String>(
            value: track.id,
            onTap: () => _player.setSubtitleTrack(track),
            child: textWidget(label, track.id == currentSub.id),
          ));
        }
        if (widget.videos.isNotEmpty) {
          for (final video in widget.videos) {
            for (final sub in video.subtitles ?? []) {
              if (sub.file == null || sub.file!.isEmpty) continue;
              final file = sub.file!;
              final lbl = _normTrackLabel(sub.label ?? file);
              items.add(PopupMenuItem<String>(
                value: file,
                onTap: () => _player.setSubtitleTrack(
                  file.startsWith('http') || file.startsWith('file')
                      ? SubtitleTrack.uri(file, title: lbl, language: lbl)
                      : SubtitleTrack.data(file, title: lbl, language: lbl),
                ),
                child: textWidget(lbl, false),
              ));
            }
          }
        }
        if (items.length <= 1) {
          items.add(const PopupMenuItem<String>(
            enabled: false,
            child: Text('Aucun sous-titre disponible'),
          ));
        }
        return ArrowPopupMenuButton<String>(
          tooltip: '',
          icon: const Icon(Icons.closed_caption_outlined, color: Colors.white),
          iconSize: 30,
          menuWidth: 220,
          itemBuilder: (context) => items,
        );
      },
    );
  }

  Widget _audioTopButton(BuildContext context) {
    return ArrowPopupMenuButton<String>(
      tooltip: '',
      icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
      iconSize: 26,
      menuWidth: 220,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        final currentAudio = _player.state.track.audio;
        for (final track in _player.state.tracks.audio) {
          final rawLabel = track.title ?? track.language ?? track.channels ?? '';
          if (rawLabel.isEmpty) continue;
          final label = _normTrackLabel(rawLabel);
          items.add(PopupMenuItem<String>(
            value: track.id,
            onTap: () => _player.setAudioTrack(track),
            child: textWidget(label, track.id == currentAudio.id),
          ));
        }
        if (widget.videos.isNotEmpty && !widget.isLocal) {
          final seen = <String>{};
          for (final video in widget.videos) {
            for (final audio in video.audios ?? []) {
              if (audio.file == null || audio.file!.isEmpty) continue;
              if (!seen.add(audio.file!)) continue;
              final lbl = _normTrackLabel(audio.label ?? audio.file!);
              items.add(PopupMenuItem<String>(
                value: audio.file!,
                onTap: () => _player.setAudioTrack(
                  AudioTrack.uri(audio.file!, title: lbl, language: lbl),
                ),
                child: textWidget(lbl, false),
              ));
            }
          }
        }
        if (items.isEmpty) {
          items.add(const PopupMenuItem<String>(
            enabled: false,
            child: Text('Aucune piste audio disponible'),
          ));
        }
        return items;
      },
    );
  }

  Widget _hdrTopButton(BuildContext context) {
    const modes = <(String, String)>[
      ('Auto', 'auto'),
      ('BT.2390', 'bt.2390'),
      ('Reinhard', 'reinhard'),
      ('Hable', 'hable'),
      ('Gamma', 'gamma'),
      ('Linear', 'linear'),
      ('Mobius', 'mobius'),
      ('Clip', 'clip'),
    ];
    return ArrowPopupMenuButton<String>(
      tooltip: 'HDR',
      icon: const Icon(Icons.hdr_on_outlined, color: Colors.white),
      iconSize: 30,
      menuWidth: 180,
      itemBuilder: (context) => modes
          .map(
            (m) => PopupMenuItem<String>(
              value: m.$2,
              onTap: () {
                try {
                  (_player.platform as NativePlayer).command([
                    'set',
                    'tone-mapping',
                    m.$2,
                  ]);
                } catch (_) {}
              },
              child: textWidget(m.$1, false),
            ),
          )
          .toList(),
    );
  }

  Widget _helpTopButton(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(5),
      tooltip: 'Aide',
      icon: const Icon(
        Icons.help_outline_rounded,
        color: Colors.white,
        size: 26,
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PlayerFeedbackPage(),
          fullscreenDialog: true,
        ),
      ),
    );
  }

  Widget _lockButton() {
    return IconButton(
      icon: Icon(
        _locked ? Icons.lock_outline : Icons.lock_open_outlined,
        color: Colors.white,
        size: 28,
      ),
      tooltip: _locked ? 'Déverrouiller' : 'Verrouiller',
      onPressed: () => setState(() => _locked = !_locked),
    );
  }

  Widget _muteButton() {
    return IconButton(
      icon: Icon(
        _isMuted ? Icons.volume_off : Icons.volume_up,
        color: Colors.white,
        size: 28,
      ),
      tooltip: _isMuted ? 'Réactiver le son' : 'Muet',
      onPressed: () {
        setState(() {
          if (_isMuted) {
            _isMuted = false;
            _player.setVolume(_savedVolume * 100);
          } else {
            _savedVolume = _player.state.volume / 100;
            _isMuted = true;
            _player.setVolume(0);
          }
        });
      },
    );
  }

  Widget _screenshotSideButton() {
    return btnToShowShareScreenshot(
      widget.episode,
      onChanged: (v) {
        if (v) {
          _player.play();
        } else {
          _player.pause();
        }
      },
    );
  }

  Widget _rotateSideButton() {
    return IconButton(
      icon: const Icon(
        Icons.screen_rotation_outlined,
        color: Colors.white,
        size: 28,
      ),
      tooltip: 'Rotation',
      onPressed: () {
        final orientation = MediaQuery.of(context).orientation;
        if (orientation == Orientation.landscape) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      },
    );
  }

  Widget _topButtonBar(BuildContext context) {
    final fullScreen = ref.watch(fullscreenProvider);
    return Padding(
      padding: EdgeInsets.only(
        top: !_isDesktop && !fullScreen
            ? MediaQuery.of(context).padding.top
            : 0,
      ),
      child: Row(
        children: [
          BackButton(
            color: Colors.white,
            onPressed: () {
              if (_isDesktop && fullScreen) {
                setFullScreen(value: !fullScreen);
                ref.read(fullscreenProvider.notifier).state = !fullScreen;
                widget.desktopFullScreenPlayer.call(!fullScreen);
              } else {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              }
              if (mounted) {
                // Set variable to true, so the player uses the global
                // "Use Fullscreen" setting again.
                _firstTime = true;
                Navigator.pop(context);
              }
            },
          ),
          Flexible(
            child: ListTile(
              dense: true,
              title: SizedBox(
                width: context.width(0.8),
                child: Text(
                  widget.episode.manga.value!.name!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: SizedBox(
                width: context.width(0.8),
                child: Text(
                  widget.episode.name!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Row(
            children: [
              if (_supportAlwaysOnTop())
                IconButton(
                  icon: Icon(
                    _alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _alwaysOnTop = !_alwaysOnTop);
                    windowManager.setAlwaysOnTop(_alwaysOnTop);
                  },
                ),
              _hdrTopButton(context),
              _subtitleTopButton(context),
              btnToShowChapterListDialog(
                context,
                context.l10n.episodes,
                widget.episode,
                onChanged: (v) {
                  if (v) {
                    _player.play();
                  } else {
                    _player.pause();
                  }
                },
                iconColor: Colors.white,
                iconSize: 30,
              ),
              IconButton(
                padding: const EdgeInsets.all(5),
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
                onPressed: () => _showSettingsPanel(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resize(BoxFit fit) async {
    // Wait for the widget tree to settle before updating fit
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      _key.currentState?.update(
        fit: fit,
        width: context.width(1),
        height: context.height(1),
      );
    }
  }

  Widget _videoPlayer(BuildContext context) {
    final fit = _fit.value;
    _resize(fit);
    final enableAniSkip = ref.read(enableAniSkipStateProvider);
    final enableAutoSkip = ref.read(enableAutoSkipStateProvider);
    final aniSkipTimeoutLength = ref.read(aniSkipTimeoutLengthStateProvider);
    final skipIntroLength = ref.read(defaultSkipIntroLengthStateProvider);
    return Stack(
      children: [
        Video(
          subtitleViewConfiguration: SubtitleViewConfiguration(
            visible: false,
            style: subtileTextStyle(ref),
          ),
          fit: fit,
          key: _key,
          controls: (state) => _isDesktop
              ? DesktopControllerWidget(
                  videoController: _controller,
                  topButtonBarWidget: _topButtonBar(context),
                  videoStatekey: _key,
                  bottomButtonBarWidget: _desktopBottomButtonBar(context),
                  streamController: _streamController,
                  seekToWidget: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(children: [_seekToWidget()]),
                  ),
                  tempDuration: (value) {
                    _tempPosition.value = value;
                  },
                  doubleSpeed: (value) {
                    _isDoubleSpeed.value = value ?? false;
                  },
                  defaultSkipIntroLength: skipIntroLength,
                  desktopFullScreenPlayer: widget.desktopFullScreenPlayer,
                  chapterMarks: _chapterMarks,
                )
              : MobileControllerWidget(
                  videoController: _controller,
                  topButtonBarWidget: _topButtonBar(context),
                  videoStatekey: _key,
                  bottomButtonBarWidget: _mobileBottomButtonBar(context),
                  streamController: _streamController,
                  doubleSpeed: (value) {
                    _isDoubleSpeed.value = value ?? false;
                  },
                  chapterMarks: _chapterMarks,
                  leftSideWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _muteButton(),
                      const SizedBox(height: 20),
                      _lockButton(),
                    ],
                  ),
                  rightSideWidget: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _screenshotSideButton(),
                      const SizedBox(height: 20),
                      _rotateSideButton(),
                    ],
                  ),
                ),
          controller: _controller,
          width: context.width(1),
          height: context.height(1),
          resumeUponEnteringForegroundMode: true,
        ),
        Stack(
          alignment: AlignmentDirectional.center,
          children: [
            Positioned(
              top: 30,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isDoubleSpeed,
                builder: (context, snapshot, _) {
                  return Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      style: TextStyle(
                        background: Paint()
                          ..color = Theme.of(context).scaffoldBackgroundColor
                          ..strokeWidth = 30.0
                          ..strokeJoin = StrokeJoin.round
                          ..style = PaintingStyle.stroke,
                      ),
                      children: snapshot
                          ? [
                              TextSpan(
                                text: " 2X ",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(Icons.fast_forward),
                              ),
                            ]
                          : [],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        _VideoStatsOverlay(player: _player),
        // ── OPlayer side panel overlay ────────────────────────────────────
        _buildSidePanelOverlay(context),
        if (enableAniSkip && (_hasOpeningSkip || _hasEndingSkip))
          Positioned(
            right: 0,
            bottom: 80,
            child: ValueListenableBuilder<_AniSkipPhase>(
              valueListenable: _skipPhase,
              builder: (context, phase, _) {
                if (phase == _AniSkipPhase.none) return const SizedBox.shrink();
                final isOpening = phase == _AniSkipPhase.opening;
                final result = isOpening ? _openingResult! : _endingResult!;
                return AniSkipCountDownButton(
                  key: Key(isOpening ? 'skip_opening' : 'skip_ending'),
                  active: true,
                  autoSkip: enableAutoSkip,
                  timeoutLength: aniSkipTimeoutLength,
                  skipTypeText: isOpening
                      ? context.l10n.skip_opening
                      : context.l10n.skip_ending,
                  player: _player,
                  aniSkipResult: result,
                );
              },
            ),
          ),
        // ── Lock overlay ──────────────────────────────────────────────────────
        if (_locked)
          Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {},
                  onDoubleTap: () {},
                  onLongPress: () {},
                  onHorizontalDragUpdate: (_) {},
                  onVerticalDragUpdate: (_) {},
                  child: Container(color: Colors.transparent),
                ),
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Déverrouiller',
                        onPressed: () => setState(() => _locked = false),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget btnToShowShareScreenshot(
    Chapter episode, {
    void Function(bool)? onChanged,
  }) {
    return IconButton(
      onPressed: () async {
        onChanged?.call(false);
        Widget button(String label, IconData icon, Function() onPressed) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: onPressed,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(icon),
                      ),
                      Text(label),
                    ],
                  ),
                ),
              ),
            );
        final name =
            "${episode.manga.value!.name} ${episode.name} - ${_currentPosition.value.toString()}"
                .replaceAll(RegExp(r'[^a-zA-Z0-9 .()\-\s]'), '_');
        await showModalBottomSheet(
          context: context,
          constraints: BoxConstraints(maxWidth: context.width(1)),
          builder: (context) {
            return SuperListView(
              shrinkWrap: true,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    color: context.themeData.scaffoldBackgroundColor,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 7,
                          width: 35,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: context.secondaryColor.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          button(
                            context.l10n.set_as_cover,
                            Icons.image_outlined,
                            () async {
                              final imageBytes = await _player.screenshot(
                                format: "image/png",
                                includeLibassSubtitles: _includeSubtitles,
                              );
                              if (context.mounted) {
                                final res = await showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      content: Text(
                                        context.l10n.use_this_as_cover_art,
                                      ),
                                      actions: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: Text(context.l10n.cancel),
                                            ),
                                            const SizedBox(width: 15),
                                            TextButton(
                                              onPressed: () {
                                                final manga =
                                                    episode.manga.value!;
                                                isar.writeTxnSync(() {
                                                  isar.mangas.putSync(
                                                    manga
                                                      ..updatedAt = DateTime.now()
                                                          .millisecondsSinceEpoch
                                                      ..customCoverImage =
                                                          imageBytes
                                                              ?.getCoverImage,
                                                  );
                                                });
                                                if (context.mounted) {
                                                  Navigator.pop(context, "ok");
                                                }
                                              },
                                              child: Text(context.l10n.ok),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (res != null &&
                                    res == "ok" &&
                                    context.mounted) {
                                  Navigator.pop(context);
                                  botToast(
                                    context.l10n.cover_updated,
                                    second: 3,
                                  );
                                }
                              }
                            },
                          ),
                          button(
                            context.l10n.share,
                            Icons.share_outlined,
                            () async {
                              final imageBytes = await _player.screenshot(
                                format: "image/png",
                                includeLibassSubtitles: _includeSubtitles,
                              );
                              if (context.mounted) {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                await SharePlus.instance.share(
                                  ShareParams(
                                    files: [
                                      XFile.fromData(
                                        imageBytes!,
                                        name: name,
                                        mimeType: 'image/png',
                                      ),
                                    ],
                                    sharePositionOrigin:
                                        box!.localToGlobal(Offset.zero) &
                                        box.size,
                                  ),
                                );
                              }
                            },
                          ),
                          button(
                            context.l10n.save,
                            Icons.save_outlined,
                            () async {
                              final imageBytes = await _player.screenshot(
                                format: "image/png",
                                includeLibassSubtitles: _includeSubtitles,
                              );
                              final dir = await StorageProvider()
                                  .getGalleryDirectory();
                              final file = File(
                                path.join(dir!.path, "$name.png"),
                              );
                              file.writeAsBytesSync(imageBytes!);
                              if (context.mounted) {
                                botToast(context.l10n.picture_saved, second: 3);
                              }
                            },
                          ),
                        ],
                      ),
                      SwitchListTile(
                        onChanged: (value) {
                          setState(() {
                            _includeSubtitles = value;
                          });
                        },
                        title: Text(context.l10n.include_subtitles),
                        value: _includeSubtitles,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
        onChanged?.call(true);
      },
      icon: Icon(Icons.adaptive.share, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _videoPlayer(context));
  }
}

/// Normalizes a raw subtitle/audio track label to a readable name with flag emoji.
String _normTrackLabel(String raw) {
  if (raw.isEmpty) return raw;
  var s = raw.trim();
  var lc = s.toLowerCase();
  for (final sfx in [' dubbed', ' subbed', ' dub', ' sub', ' audio']) {
    if (lc.endsWith(sfx)) {
      s = s.substring(0, s.length - sfx.length).trim();
      lc = s.toLowerCase();
      break;
    }
  }
  if (lc.isEmpty) return raw;
  final flag = langFlagEmoji(lc);
  if (flag.isNotEmpty && flag != '🌐') {
    final name = completeLanguageName(lc);
    return '$flag $name';
  }
  const nameToCode = {
    'french': 'fr', 'english': 'en', 'japanese': 'ja', 'spanish': 'es',
    'german': 'de', 'portuguese': 'pt', 'italian': 'it', 'korean': 'ko',
    'chinese': 'zh', 'arabic': 'ar', 'russian': 'ru', 'turkish': 'tr',
    'hindi': 'hi', 'indonesian': 'id', 'polish': 'pl', 'dutch': 'nl',
    'vietnamese': 'vi', 'thai': 'th', 'greek': 'el', 'swedish': 'sv',
    'danish': 'da', 'norwegian': 'no', 'finnish': 'fi', 'hebrew': 'he',
    'czech': 'cs', 'hungarian': 'hu', 'romanian': 'ro', 'ukrainian': 'uk',
    'tagalog': 'tl', 'malay': 'ms', 'tamil': 'ta', 'telugu': 'te',
    'latin american spanish': 'es-419', 'brazilian portuguese': 'pt-br',
    'brazilian': 'pt-br', 'castilian': 'es', 'catalan': 'ca',
  };
  final code = nameToCode[lc];
  if (code != null && code.isNotEmpty) {
    final f = langFlagEmoji(code);
    final name = completeLanguageName(code);
    return '$f $name';
  }
  return s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : raw;
}

Widget seekIndicatorTextWidget(Duration duration, Duration currentPosition) {
  final swipeDuration = duration.inSeconds;
  final value = currentPosition.inSeconds + swipeDuration;
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        Duration(seconds: value).label(),
        style: const TextStyle(
          fontSize: 65.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      Text(
        "[${swipeDuration > 0 ? "+${Duration(seconds: swipeDuration).label()}" : "-${Duration(seconds: swipeDuration).label()}"}]",
        style: const TextStyle(
          fontSize: 40.0,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

class VideoPrefs {
  String? title;
  VideoTrack? videoTrack;
  SubtitleTrack? subtitle;
  AudioTrack? audio;
  bool isLocal;
  final Map<String, String>? headers;
  VideoPrefs({
    this.videoTrack,
    this.isLocal = true,
    this.headers,
    this.subtitle,
    this.audio,
    this.title,
  });
}

mixin _AlwaysOnTopStateMixin<T extends StatefulWidget> on State<T> {
  // The original alwaysOnTop state.
  // This will be used to restore the original state when the widget disposed.
  bool? _savedAlwaysOnTop;

  bool _alwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    _initAlwaysOnTop();
  }

  @override
  void dispose() {
    super.dispose();
    _disposeAlwaysOnTop();
  }

  Future<void> _initAlwaysOnTop() async {
    if (_supportAlwaysOnTop()) {
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();
      if (mounted) {
        setState(() => _alwaysOnTop = _savedAlwaysOnTop!);
      }
    }
  }

  Future<void> _disposeAlwaysOnTop() async {
    if (_supportAlwaysOnTop()) {
      if (_savedAlwaysOnTop != null) {
        await windowManager.setAlwaysOnTop(_savedAlwaysOnTop!);
      }
    }
  }

  // Whether the platform support AlwaysOnTop feature.
  bool _supportAlwaysOnTop() =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
}

// ── Stats vidéo overlay (résolution, codec, FPS, bitrate) ────────────────────

class _VideoStatsOverlay extends StatefulWidget {
  final Player player;
  const _VideoStatsOverlay({required this.player});
  @override
  State<_VideoStatsOverlay> createState() => _VideoStatsOverlayState();
}

class _VideoStatsOverlayState extends State<_VideoStatsOverlay> {
  bool _visible = false;
  // Résolution live via stream width/height
  double _w = 0, _h = 0;
  double _fps = 0;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    try { _w = (widget.player.state.width as num).toDouble(); } catch (_) {}
    try { _h = (widget.player.state.height as num).toDouble(); } catch (_) {}
    try {
      _subs.add(widget.player.stream.width.listen((v) {
        if (mounted) {
          try { setState(() => _w = (v as num?)?.toDouble() ?? _w); } catch (_) {}
        }
      }));
    } catch (_) {}
    try {
      _subs.add(widget.player.stream.height.listen((v) {
        if (mounted) {
          try { setState(() => _h = (v as num?)?.toDouble() ?? _h); } catch (_) {}
        }
      }));
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  String get _resolution =>
      (_w > 0 && _h > 0) ? '${_w.toInt()}×${_h.toInt()}' : '—';

  String get _codec {
    try {
      final t = widget.player.state.track.video;
      return (t as dynamic).codec as String? ?? '—';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned(
            top: 60,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _visible = !_visible),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _visible ? 1.0 : 0.55,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: _visible ? Colors.amberAccent : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          if (_visible)
            Positioned(
              top: 55,
              right: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _statRow(Icons.aspect_ratio_rounded,
                              'Résolution', _resolution),
                          _statRow(Icons.movie_creation_outlined,
                              'Codec', _codec),
                          _statRow(Icons.speed_rounded, 'FPS',
                              _fps > 0
                                  ? _fps.toStringAsFixed(3)
                                  : '—'),
                          _statRow(Icons.graphic_eq_rounded, 'Bitrate',
                              '—'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Comprehensive player settings dialog ─────────────────────────────────────

class _PlayerSettingsDialog extends StatefulWidget {
  final Player player;
  final BoxFit fit;
  final int doubleTapSkip;
  final int introSkip;
  final double playbackSpeed;
  final bool useLibassVal;
  final bool enableHwAccel;
  final String hwdecModeVal;
  final bool forceLandscape;
  final bool useMpvConfigVal;
  final bool useGpuNextVal;
  final String audioPreferredLangVal;
  final bool enableAniSkipVal;
  final bool enableAutoSkipVal;
  // When true, renders as a plain scrollable column (no Dialog chrome)
  final bool inline;

  final void Function(int) onDoubleTapSkipChange;
  final void Function(int) onIntroSkipChange;
  final void Function(double) onSpeedChange;
  final void Function(bool) onForceLandscapeChange;
  final void Function(bool) onEnableAniSkipChange;
  final void Function(bool) onEnableAutoSkipChange;

  const _PlayerSettingsDialog({
    required this.player,
    required this.fit,
    required this.doubleTapSkip,
    required this.introSkip,
    required this.playbackSpeed,
    required this.useLibassVal,
    required this.enableHwAccel,
    required this.hwdecModeVal,
    required this.forceLandscape,
    required this.useMpvConfigVal,
    required this.useGpuNextVal,
    required this.audioPreferredLangVal,
    required this.enableAniSkipVal,
    required this.enableAutoSkipVal,
    required this.onDoubleTapSkipChange,
    required this.onIntroSkipChange,
    required this.onSpeedChange,
    required this.onForceLandscapeChange,
    required this.onEnableAniSkipChange,
    required this.onEnableAutoSkipChange,
    this.inline = false,
  });

  @override
  State<_PlayerSettingsDialog> createState() => _PlayerSettingsDialogState();
}

class _PlayerSettingsDialogState extends State<_PlayerSettingsDialog> {
  late int _doubleTapSkip = widget.doubleTapSkip;
  late int _introSkip = widget.introSkip;
  late double _speed = widget.playbackSpeed;
  late bool _forceLandscape = widget.forceLandscape;
  late bool _enableAniSkip = widget.enableAniSkipVal;
  late bool _enableAutoSkip = widget.enableAutoSkipVal;

  String get _fitName {
    switch (widget.fit) {
      case BoxFit.contain:
        return 'Contenir';
      case BoxFit.cover:
        return 'Couvrir';
      case BoxFit.fill:
        return 'Remplir';
      case BoxFit.fitWidth:
        return 'Largeur';
      case BoxFit.fitHeight:
        return 'Hauteur';
      case BoxFit.scaleDown:
        return 'Réduire';
      default:
        return 'Aucun';
    }
  }

  String get _audioLabel {
    final t = widget.player.state.track.audio;
    return t.title ??
        t.language ??
        t.channels ??
        (t.id == 'auto' ? 'Auto' : t.id);
  }

  String get _subLabel {
    final t = widget.player.state.track.subtitle;
    return t.title ??
        t.language ??
        (t.id == 'auto'
            ? 'Auto'
            : t.id == 'no'
                ? 'Aucun'
                : t.id);
  }

  /// The shared settings content (tiles, toggles, sections).
  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                        // ── SECTION: Lecture ─────────────────────────────────
                        _sectionHeader('Lecture'),
                        _editableTile(
                          label: 'Durée double-tap',
                          value: '${_doubleTapSkip}s',
                          icon: Icons.touch_app_rounded,
                          onTap: () => _pickInt(
                            context,
                            title: 'Durée double-tap (secondes)',
                            min: 1,
                            max: 60,
                            current: _doubleTapSkip,
                            onConfirm: (v) {
                              setState(() => _doubleTapSkip = v);
                              widget.onDoubleTapSkipChange(v);
                            },
                          ),
                        ),
                        _editableTile(
                          label: 'Skip intro',
                          value: '${_introSkip}s',
                          icon: Icons.skip_next_rounded,
                          onTap: () => _pickInt(
                            context,
                            title: 'Durée skip intro (secondes)',
                            min: 1,
                            max: 300,
                            current: _introSkip,
                            onConfirm: (v) {
                              setState(() => _introSkip = v);
                              widget.onIntroSkipChange(v);
                            },
                          ),
                        ),
                        _readOnlyTile(
                          label: 'Secondes skip ±',
                          value: '15s',
                          icon: Icons.fast_forward_rounded,
                        ),
                        _editableTile(
                          label: 'Vitesse de lecture',
                          value: '${_speed}x',
                          icon: Icons.speed_rounded,
                          onTap: () => _pickSpeed(context),
                        ),
                        _readOnlyTile(
                          label: 'Vitesse maximale',
                          value: '2.0x',
                          icon: Icons.arrow_upward_rounded,
                        ),
                        _readOnlyTile(
                          label: 'Vitesse minimale',
                          value: '0.25x',
                          icon: Icons.arrow_downward_rounded,
                        ),

                        // ── SECTION: Affichage ───────────────────────────────
                        _sectionHeader('Affichage'),
                        _readOnlyTile(
                          label: 'Mode affichage',
                          value: _fitName,
                          icon: Icons.fit_screen_outlined,
                        ),
                        _toggleTile(
                          label: 'Verrouillage orientation paysage',
                          value: _forceLandscape,
                          icon: Icons.screen_rotation_rounded,
                          onChanged: (v) {
                            setState(() => _forceLandscape = v);
                            widget.onForceLandscapeChange(v);
                          },
                        ),

                        // ── SECTION: Audio ───────────────────────────────────
                        _sectionHeader('Audio'),
                        _readOnlyTile(
                          label: 'Langue audio préférée',
                          value: widget.audioPreferredLangVal.isEmpty
                              ? 'Auto'
                              : widget.audioPreferredLangVal,
                          icon: Icons.language_rounded,
                        ),
                        _readOnlyTile(
                          label: 'Piste audio active',
                          value: _audioLabel,
                          icon: Icons.audio_file_rounded,
                        ),

                        // ── SECTION: Sous-titres ─────────────────────────────
                        _sectionHeader('Sous-titres'),
                        _readOnlyTile(
                          label: 'Piste sous-titres',
                          value: _subLabel,
                          icon: Icons.subtitles_rounded,
                        ),
                        _readOnlyTile(
                          label: 'Décodage sous-titres',
                          value: widget.useLibassVal
                              ? 'Libass (logiciel)'
                              : 'Natif',
                          icon: Icons.closed_caption_rounded,
                        ),

                        // ── SECTION: Décodeur ────────────────────────────────
                        _sectionHeader('Décodeur'),
                        _readOnlyTile(
                          label: 'Accélération matérielle',
                          value: widget.enableHwAccel ? 'Activée' : 'Désactivée',
                          icon: Icons.memory_rounded,
                        ),
                        _readOnlyTile(
                          label: 'Mode hwdec',
                          value: widget.hwdecModeVal,
                          icon: Icons.developer_board_rounded,
                        ),
                        _readOnlyTile(
                          label: 'GPU-Next',
                          value: widget.useGpuNextVal ? 'Activé' : 'Désactivé',
                          icon: Icons.videocam_rounded,
                        ),
                        _readOnlyTile(
                          label: 'Rendu vidéo',
                          value: widget.useMpvConfigVal
                              ? 'MPV (config)'
                              : 'Natif',
                          icon: Icons.settings_applications_rounded,
                        ),

                        // ── SECTION: AniSkip ─────────────────────────────────
                        _sectionHeader('AniSkip'),
                        _toggleTile(
                          label: 'AniSkip activé',
                          value: _enableAniSkip,
                          icon: Icons.auto_fix_high_rounded,
                          onChanged: (v) {
                            setState(() => _enableAniSkip = v);
                            widget.onEnableAniSkipChange(v);
                          },
                        ),
                        _toggleTile(
                          label: 'Skip automatique',
                          value: _enableAutoSkip,
                          icon: Icons.skip_next_rounded,
                          onChanged: (v) {
                            setState(() => _enableAutoSkip = v);
                            widget.onEnableAutoSkipChange(v);
                          },
                        ),

        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      // Rendered inside the OPlayer side panel — no Dialog chrome needed
      return _buildContent(context);
    }
    // Standalone dialog mode
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            decoration: BoxDecoration(
              color: const Color(0xEA10101F),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 50,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Paramètres — Lecteur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
                Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.09)),
                // ── Scrollable content ──────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: _buildContent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white54),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String label,
    required bool value,
    required IconData icon,
    required void Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickInt(
    BuildContext context, {
    required String title,
    required int min,
    required int max,
    required int current,
    required void Function(int) onConfirm,
  }) async {
    int tempVal = current;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: StatefulBuilder(
          builder: (ctx, ss) => SizedBox(
            height: 130,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white60),
                      onPressed: () {
                        if (tempVal > min) ss(() => tempVal--);
                      },
                    ),
                    Text(
                      '$tempVal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white60),
                      onPressed: () {
                        if (tempVal < max) ss(() => tempVal++);
                      },
                    ),
                  ],
                ),
                Slider(
                  min: min.toDouble(),
                  max: max.toDouble(),
                  value: tempVal.toDouble(),
                  onChanged: (v) => ss(() => tempVal = v.round()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              onConfirm(tempVal);
              Navigator.pop(ctx);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSpeed(BuildContext context) async {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    double tempSpeed = _speed;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Vitesse de lecture',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: StatefulBuilder(
          builder: (ctx, ss) => SizedBox(
            width: 260,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: speeds.map((s) {
                final sel = s == tempSpeed;
                return ChoiceChip(
                  label: Text('${s}x'),
                  selected: sel,
                  onSelected: (_) => ss(() => tempSpeed = s),
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : Colors.white60,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _speed = tempSpeed);
              widget.onSpeedChange(tempSpeed);
              Navigator.pop(ctx);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── OPlayer side-panel tab button ─────────────────────────────────────────────

class _PanelTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: primary.withValues(alpha: 0.55), width: 1)
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? primary : Colors.white54,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptyEpisodeView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _EmptyEpisodeView({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: onBack,
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.movie_filter_outlined,
                    color: Colors.white24,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '404',
                  style: TextStyle(
                    color: Colors.white12,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Épisode introuvable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'La source n\'a retourné aucune vidéo pour cet épisode.',
                  style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
