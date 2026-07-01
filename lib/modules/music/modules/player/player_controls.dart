import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/collections/intents.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/duration.dart';
import 'package:watchtower/modules/music/modules/player/use_progress.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/audio_player/querying_track_info.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

class PlayerControls extends HookConsumerWidget {
  final PaletteGenerator? palette;
  final bool compact;

  const PlayerControls({
    this.palette,
    this.compact = false,
    super.key,
  });

  static FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context, ref) {
    final shortcuts = useMemoized(
      () => {
        const SingleActivator(LogicalKeyboardKey.arrowRight): SeekIntent(ref, true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): SeekIntent(ref, false),
      },
      [ref],
    );
    final actions = useMemoized(() => {SeekIntent: SeekAction()}, []);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing = useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final theme = Theme.of(context);
    final iconSize = kIsMobile ? 28.0 : 22.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (focusNode.canRequestFocus) focusNode.requestFocus();
      },
      child: FocusableActionDetector(
        focusNode: focusNode,
        shortcuts: shortcuts,
        actions: actions,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              if (!compact)
                HookBuilder(
                  builder: (context) {
                    final mediaQuery = MediaQuery.sizeOf(context);
                    final (:bufferProgress, :duration, :position, :progressStatic) =
                        useProgress(ref);
                    final progress = useState<double>(
                      useMemoized(() => progressStatic.toDouble(), []),
                    );

                    useEffect(() {
                      progress.value = progressStatic.toDouble();
                      return null;
                    }, [progressStatic]);

                    return Column(
                      children: [
                        SizedBox(
                          width: mediaQuery.xlAndUp ? 600 : 500,
                          child: Slider(
                            secondaryTrackValue: bufferProgress.toDouble(),
                            value: progress.value.clamp(0.0, 1.0),
                            onChanged: isFetchingActiveTrack
                                ? null
                                : (v) => progress.value = v,
                            onChangeEnd: (value) async {
                              await audioPlayer.seek(
                                Duration(
                                  seconds: (value * duration.inSeconds).toInt(),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                position.toHumanReadableString(),
                                style: theme.textTheme.labelSmall,
                              ),
                              Text(
                                duration.toHumanReadableString(),
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Consumer(builder: (context, ref, _) {
                    final shuffled =
                        ref.watch(audioPlayerProvider.select((s) => s.shuffled));
                    return IconButton(
                      icon: Icon(
                        SpotubeIcons.shuffle,
                        color: shuffled ? theme.colorScheme.primary : null,
                        size: iconSize,
                      ),
                      style: shuffled
                          ? IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            )
                          : null,
                      onPressed: isFetchingActiveTrack
                          ? null
                          : () => audioPlayer.setShuffle(!shuffled),
                    );
                  }),
                  IconButton(
                    icon: Icon(SpotubeIcons.skipBack, size: iconSize),
                    onPressed:
                        isFetchingActiveTrack ? null : audioPlayer.skipToPrevious,
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: isFetchingActiveTrack
                        ? null
                        : Actions.handler<PlayPauseIntent>(
                            context, PlayPauseIntent(ref)),
                    child: isFetchingActiveTrack
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            playing ? SpotubeIcons.pause : SpotubeIcons.play,
                            size: iconSize,
                          ),
                  ),
                  IconButton(
                    icon: Icon(SpotubeIcons.skipForward, size: iconSize),
                    onPressed:
                        isFetchingActiveTrack ? null : audioPlayer.skipToNext,
                  ),
                  Consumer(builder: (context, ref, _) {
                    final loopMode =
                        ref.watch(audioPlayerProvider.select((s) => s.loopMode));
                    final isLooping = loopMode == PlaylistMode.single ||
                        loopMode == PlaylistMode.loop;
                    return IconButton(
                      icon: Icon(
                        loopMode == PlaylistMode.single
                            ? SpotubeIcons.repeatOne
                            : SpotubeIcons.repeat,
                        color: isLooping ? theme.colorScheme.primary : null,
                        size: iconSize,
                      ),
                      style: isLooping
                          ? IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            )
                          : null,
                      onPressed: isFetchingActiveTrack
                          ? null
                          : () async {
                              await audioPlayer.setLoopMode(
                                switch (loopMode as PlaylistMode) {
                                  PlaylistMode.loop => PlaylistMode.single,
                                  PlaylistMode.single => PlaylistMode.none,
                                  PlaylistMode.none => PlaylistMode.loop,
                                },
                              );
                            },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}
