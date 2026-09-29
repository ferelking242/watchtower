import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/player/player_actions.dart';
import 'package:watchtower/modules/music/modules/player/player_controls.dart';
import 'package:watchtower/modules/music/modules/player/volume_slider.dart';
import 'package:watchtower/modules/music/components/dialogs/track_details_dialog.dart';
import 'package:watchtower/modules/music/components/links/artist_link.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/root/spotube_navigation_bar.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/audio_source/quality_label.dart';
import 'package:watchtower/modules/music/provider/server/active_track_sources.dart';
import 'package:watchtower/modules/music/provider/volume_provider.dart';

class PlayerView extends HookConsumerWidget {
  final PanelController panelController;
  final ScrollController scrollController;
  const PlayerView({
    super.key,
    required this.panelController,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final sourcedCurrentTrack = ref.watch(activeTrackSourcesProvider);
    final currentActiveTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final currentActiveTrackSource = sourcedCurrentTrack.asData?.value?.source;
    final isLocalTrack = currentActiveTrack is SpotubeLocalTrackObject;
    final mediaQuery = MediaQuery.sizeOf(context);
    final qualityLabel = ref.watch(audioSourceQualityLabelProvider);

    final shouldHide = useState(true);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldHide.value = (height as double).ceil() == 50;
    });

    if (shouldHide.value) {
      return const SizedBox();
    }

    useEffect(() {
      if (mediaQuery.lgAndUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          panelController.close();
        });
      }
      return null;
    }, [mediaQuery.lgAndUp]);

    String albumArt = useMemoized(
      () => (currentActiveTrack?.album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      [currentActiveTrack?.album.images],
    );

    useEffect(() {
      for (final renderView in WidgetsBinding.instance.renderViews) {
        renderView.automaticSystemUiAdjustment = false;
      }

      return () {
        for (final renderView in WidgetsBinding.instance.renderViews) {
          renderView.automaticSystemUiAdjustment = true;
        }
      };
    }, [panelController.isAttached && panelController.isPanelOpen]);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        await panelController.close();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SafeArea(
            bottom: false,
            child: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                iconSize: 24,
                icon: const Icon(SpotubeIcons.angleDown),
                onPressed: panelController.close,
              ),
              actions: [
                if (!isLocalTrack)
                  IconButton(
                    iconSize: 24,
                    icon: const Icon(SpotubeIcons.info),
                    onPressed: currentActiveTrackSource == null
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return TrackDetailsDialog(
                                  track: currentActiveTrack
                                      as SpotubeFullTrackObject,
                                );
                              },
                            );
                          },
                  ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(maxHeight: 300, maxWidth: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(100),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: UniversalImage(
                      path: albumArt,
                      placeholder: Assets.images.albumPlaceholder.path,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        currentActiveTrack?.name ?? context.l10n.not_playing,
                        style: const TextStyle(fontSize: 22),
                        maxFontSize: 22,
                        maxLines: 1,
                        textAlign: TextAlign.start,
                      ),
                      if (isLocalTrack)
                        Text(
                          currentActiveTrack.artists.asString(),
                          style: theme.textTheme.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                        )
                      else
                        ArtistLink(
                          artists: currentActiveTrack?.artists ?? [],
                          textStyle: theme.textTheme.bodyMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                          onRouteChange: (route) {
                            panelController.close();
                            context.router.navigateNamed(route);
                          },
                          onOverflowArtistClick: () => context.navigateTo(
                            TrackRoute(
                              trackId: currentActiveTrack!.id,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const PlayerControls(),
                const SizedBox(height: 25),
                const PlayerActions(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  showQueue: false,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(SpotubeIcons.queue),
                        label: Text(context.l10n.queue),
                        onPressed: () {
                          context.pushRoute(const PlayerQueueRoute());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(SpotubeIcons.music),
                        label: Text(context.l10n.lyrics),
                        onPressed: () {
                          context.pushRoute(const PlayerLyricsRoute());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Consumer(builder: (context, ref, _) {
                    final volume = ref.watch(volumeProvider);
                    return VolumeSlider(
                      fullWidth: true,
                      value: volume,
                      onChanged: (value) {
                        ref.read(volumeProvider.notifier).setVolume(value);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 25, width: 25),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(SpotubeIcons.lightningOutlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        qualityLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
