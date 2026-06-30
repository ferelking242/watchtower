import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'dart:convert';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/connect/connect.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/player/player_queue.dart';
import 'package:watchtower/modules/music/modules/player/volume_slider.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/links/anchor_button.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/duration.dart';
import 'package:watchtower/modules/music/provider/connect/clients.dart';
import 'package:watchtower/modules/music/provider/connect/connect.dart';
import 'package:media_kit/media_kit.dart' hide Track;

class RemotePlayerQueue extends ConsumerWidget {
  const RemotePlayerQueue({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final connectNotifier = ref.watch(connectProvider.notifier);
    final playlist = ref.watch(queueProvider);
    return PlayerQueue(
      playlist: playlist,
      floating: true,
      onJump: (track) async {
        final index = playlist.tracks.toList().indexOf(track);
        connectNotifier.jumpTo(index);
      },
      onRemove: (track) async {
        await connectNotifier.removeTrack(track);
      },
      onStop: () async => connectNotifier.stop(),
      onReorder: (oldIndex, newIndex) async {
        await connectNotifier.reorder(
          (oldIndex: oldIndex, newIndex: newIndex),
        );
      },
    );
  }
}

class ConnectControlPage extends HookConsumerWidget {
  static const name = "connect_control";

  const ConnectControlPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resolvedService =
        ref.watch(connectClientsProvider).asData?.value.resolvedService;
    final connect = ref.watch(connectProvider);
    final connectNotifier = ref.read(connectProvider.notifier);
    final playlist = ref.watch(queueProvider);
    final playing = ref.watch(playingProvider);
    final shuffled = ref.watch(shuffleProvider);
    final loopMode = ref.watch(loopModeProvider);

    ref.listen(connectClientsProvider, (prev, next) {
      if (next.asData?.value.resolvedService == null) {
        context.back();
      }
    });

    useEffect(() {
      if (connect.asData?.value == null) return null;

      final subscription = connect.asData?.value?.stream.listen((message) {
        final event = WebSocketEvent.fromJson(
          jsonDecode(message),
          (data) => data,
        );
        event.onError((event) {
          if (event.data != "Connection denied") return;
          if (!context.mounted) return;
          context.back();
        });
      });

      return () {
        subscription?.cancel();
      };
    }, [connect.asData?.value]);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(resolvedService?.name ?? ""),
        ),
        body: LayoutBuilder(builder: (context, constrains) {
          return Row(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ).copyWith(top: 0),
                        constraints: const BoxConstraints(
                            maxHeight: 350, maxWidth: 350),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: UniversalImage(
                            path: (playlist.activeTrack?.album.images)
                                .asUrlString(
                              placeholder: ImagePlaceholder.albumArt,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: AnchorButton(
                              playlist.activeTrack?.name ?? "",
                              style: theme.textTheme.headlineSmall ?? const TextStyle(),
                              onTap: () {
                                if (playlist.activeTrack == null) return;
                                context.navigateTo(
                                  TrackRoute(
                                      trackId: playlist.activeTrack!.id),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: ArtistLink(
                              artists:
                                  playlist.activeTrack?.artists ?? [],
                              textStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
                              mainAxisAlignment: WrapAlignment.start,
                              onOverflowArtistClick: () =>
                                  context.navigateTo(
                                TrackRoute(
                                    trackId: playlist.activeTrack!.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final position = ref.watch(positionProvider);
                          final duration = ref.watch(durationProvider);

                          final progress = duration.inSeconds == 0
                              ? 0.0
                              : position.inSeconds /
                                  duration.inSeconds.toDouble();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: Column(
                              children: [
                                Slider(
                                  value: progress.clamp(0.0, 1.0),
                                  onChanged: (value) {
                                    connectNotifier.seek(
                                      Duration(
                                        seconds: (value *
                                                duration.inSeconds)
                                            .toInt(),
                                      ),
                                    );
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        position.toHumanReadableString()),
                                    Text(
                                        duration.toHumanReadableString()),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              SpotubeIcons.shuffle,
                              color: shuffled
                                  ? colorScheme.primary
                                  : null,
                            ),
                            onPressed: playlist.activeTrack == null
                                ? null
                                : () {
                                    connectNotifier
                                        .setShuffle(!shuffled);
                                  },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(SpotubeIcons.skipBack),
                            onPressed: playlist.activeTrack == null
                                ? null
                                : connectNotifier.previous,
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                            ),
                            child: playlist.activeTrack == null
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  )
                                : Icon(
                                    playing
                                        ? SpotubeIcons.pause
                                        : SpotubeIcons.play,
                                    color: Colors.white,
                                  ),
                            onPressed: playlist.activeTrack == null
                                ? null
                                : () {
                                    if (playing) {
                                      connectNotifier.pause();
                                    } else {
                                      connectNotifier.resume();
                                    }
                                  },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(SpotubeIcons.skipForward),
                            onPressed: playlist.activeTrack == null
                                ? null
                                : connectNotifier.next,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              loopMode == PlaylistMode.single
                                  ? SpotubeIcons.repeatOne
                                  : SpotubeIcons.repeat,
                              color: loopMode == PlaylistMode.loop
                                  ? colorScheme.primary
                                  : null,
                            ),
                            onPressed: playlist.activeTrack == null
                                ? null
                                : () async {
                                    connectNotifier.setLoopMode(
                                      switch (loopMode) {
                                        PlaylistMode.loop =>
                                          PlaylistMode.single,
                                        PlaylistMode.single =>
                                          PlaylistMode.none,
                                        PlaylistMode.none =>
                                          PlaylistMode.loop,
                                      },
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    if (constrains.mdAndDown)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: OutlinedButton.icon(
                            icon: const Icon(SpotubeIcons.queue),
                            label: Text(context.l10n.queue),
                            onPressed: () {
                              final capturedTheme = Theme.of(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (context) {
                                  return Theme(
                                    data: capturedTheme,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.sizeOf(context)
                                                    .height *
                                                0.8,
                                      ),
                                      child: const RemotePlayerQueue(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Consumer(builder: (context, ref, _) {
                          final volume = ref.watch(volumeProvider);
                          return VolumeSlider(
                            fullWidth: true,
                            value: volume,
                            onChanged: (value) {
                              ref.read(volumeProvider.notifier).state =
                                  value;
                              connectNotifier.setVolume(value);
                            },
                          );
                        }),
                      ),
                    ),
                    const SliverSafeArea(sliver: SliverToBoxAdapter(child: SizedBox(height: 10))),
                  ],
                ),
              ),
              if (constrains.lgAndUp) ...[
                const VerticalDivider(thickness: 1),
                const Expanded(
                  child: RemotePlayerQueue(),
                ),
              ]
            ],
          );
        }),
      ),
    );
  }
}
