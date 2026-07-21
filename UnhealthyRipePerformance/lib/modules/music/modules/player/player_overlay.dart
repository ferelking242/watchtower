import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:watchtower/modules/music/modules/player/player_overlay_collapsed.dart';

import 'package:watchtower/modules/music/modules/root/spotube_navigation_bar.dart';
import 'package:watchtower/modules/music/modules/player/player.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';

final playerOverlayControllerProvider = StateProvider<PanelController>((ref) {
  return PanelController();
});

class PlayerOverlay extends HookConsumerWidget {
  final String albumArt;

  const PlayerOverlay({
    required this.albumArt,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final canShow = playlist.activeTrack != null;

    final screenSize = MediaQuery.sizeOf(context);

    final panelController = ref.watch(playerOverlayControllerProvider);

    return SlidingUpPanel(
      maxHeight: screenSize.height,
      backdropEnabled: false,
      minHeight: canShow ? 63 : 0,
      onPanelSlide: (position) {
        final invertedPosition = 1 - position;
        ref.read(navigationPanelHeight.notifier).state = 50 * invertedPosition;
      },
      controller: panelController,
      color: Theme.of(context).colorScheme.surface,
      parallaxEnabled: true,
      renderPanelSheet: false,
      header: SizedBox(
        height: 63,
        width: screenSize.width,
        child: PlayerOverlayCollapsedSection(panelController: panelController),
      ),
      panelBuilder: (scrollController) => PlayerView(
        panelController: panelController,
        scrollController: scrollController,
      ),
    );
  }
}
