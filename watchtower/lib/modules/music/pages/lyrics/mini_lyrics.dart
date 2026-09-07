import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/player/player_controls.dart';
import 'package:watchtower/modules/music/modules/player/player_queue.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/hooks/utils/use_force_update.dart';
import 'package:watchtower/modules/music/pages/lyrics/plain_lyrics.dart';
import 'package:watchtower/modules/music/pages/lyrics/synced_lyrics.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class MiniLyricsPage extends HookConsumerWidget {
  static const name = "mini_lyrics";

  final Size prevSize;
  const MiniLyricsPage({super.key, required this.prevSize});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final update = useForceUpdate();
    final wasMaximized = useRef<bool>(false);

    final playlistQueue = ref.watch(audioPlayerProvider);

    final index = useState(0);
    final tabController = useTabController(initialLength: 2);

    final areaActive = useState(false);
    final hoverMode = useState(true);
    final showLyrics = useState(true);

    useEffect(() {
      if (kIsDesktop) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          wasMaximized.value = await windowManager.isMaximized();
        });
      }
      return null;
    }, []);

    return MouseRegion(
      onEnter: !hoverMode.value
          ? null
          : (event) {
              areaActive.value = true;
            },
      onExit: !hoverMode.value
          ? null
          : (event) {
              areaActive.value = false;
            },
      child: Scaffold(
        backgroundColor:
            theme.colorScheme.surface.withValues(alpha: 0.4),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: areaActive.value
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              secondChild: const SizedBox(height: 48),
              firstChild: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    if (kIsMacOS) const SizedBox(width: 65),
                    if (showLyrics.value)
                      Expanded(
                        child: TabBar(
                          controller: tabController,
                          onTap: (i) {
                            index.value = i;
                          },
                          tabs: [
                            Tab(child: Text(context.l10n.synced)),
                            Tab(child: Text(context.l10n.plain)),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    IconButton(
                      icon: showLyrics.value
                          ? const Icon(SpotubeIcons.lyrics)
                          : const Icon(SpotubeIcons.lyricsOff),
                      onPressed: () async {
                        showLyrics.value = !showLyrics.value;
                        areaActive.value = true;
                        hoverMode.value = false;

                        if (kIsDesktop) {
                          await windowManager.setSize(
                            showLyrics.value
                                ? const Size(400, 500)
                                : const Size(400, 150),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: hoverMode.value
                          ? const Icon(SpotubeIcons.hoverOn)
                          : const Icon(SpotubeIcons.hoverOff),
                      onPressed: () async {
                        areaActive.value = true;
                        hoverMode.value = !hoverMode.value;
                      },
                    ),
                    if (kIsDesktop)
                      FutureBuilder(
                        future: windowManager.isAlwaysOnTop(),
                        builder: (context, snapshot) {
                          return IconButton(
                            icon: Icon(
                              snapshot.data == true
                                  ? SpotubeIcons.pinOn
                                  : SpotubeIcons.pinOff,
                            ),
                            onPressed: snapshot.data == null
                                ? null
                                : () async {
                                    await windowManager.setAlwaysOnTop(
                                      snapshot.data == true ? false : true,
                                    );
                                    update();
                                  },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            if (playlistQueue.activeTrack != null)
              Text(playlistQueue.activeTrack!.name!),
            if (showLyrics.value)
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    SyncedLyrics(
                      palette: PaletteColor(
                          theme.colorScheme.surface, 0),
                      isModal: true,
                      defaultTextZoom: 65,
                    ),
                    PlainLyrics(
                      palette: PaletteColor(
                          theme.colorScheme.surface, 0),
                      isModal: true,
                      defaultTextZoom: 65,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 20, width: 20),
            AnimatedCrossFade(
              crossFadeState: areaActive.value
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              secondChild: const SizedBox(),
              firstChild: Row(
                children: [
                  IconButton(
                    icon: const Icon(SpotubeIcons.queue),
                    onPressed: playlistQueue.activeTrack != null
                        ? () {
                            final capturedTheme = Theme.of(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (context) => Theme(
                                data: capturedTheme,
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final playlist =
                                        ref.watch(audioPlayerProvider);
                                    final playlistNotifier = ref.read(
                                        audioPlayerProvider.notifier);
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                0.8,
                                      ),
                                      child: PlayerQueue
                                          .fromAudioPlayerNotifier(
                                        floating: false,
                                        playlist: playlist,
                                        notifier: playlistNotifier,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                  const Flexible(child: PlayerControls(compact: true)),
                  IconButton(
                    icon: const Icon(SpotubeIcons.maximize),
                    onPressed: () async {
                      if (!kIsDesktop) return;

                      try {
                        await windowManager
                            .setMinimumSize(const Size(300, 700));
                        await windowManager.setAlwaysOnTop(false);
                        if (wasMaximized.value) {
                          await windowManager.maximize();
                        } else {
                          await windowManager.setSize(prevSize);
                        }
                        await windowManager.setAlignment(Alignment.center);
                        if (!kIsLinux) {
                          await windowManager.setHasShadow(true);
                        }
                        await Future.delayed(
                            const Duration(milliseconds: 200));
                      } finally {
                        if (context.mounted) {
                          context.navigateTo(const LyricsRoute());
                        }
                      }
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
