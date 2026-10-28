import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Video player gestures, mirroring Aniyomi's "Gestes" block.
class PlayerGestureScreen extends ConsumerWidget {
  const PlayerGestureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doubleTapSeek = ref.watch(playerDoubleTapSeekProvider);
    final seekSeconds = ref.watch(playerDoubleTapSeekSecondsProvider);
    final swipeGestures = ref.watch(playerSwipeGesturesProvider);
    final gestureOverlay = ref.watch(playerGestureOverlayProvider);
    final doubleTapPause = ref.watch(playerDoubleTapToPauseProvider);

    return SettingsSubpageScaffold(
      title: 'Gestes',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Broken.mouse),
                value: doubleTapSeek,
                title: const Text('Chercher par double-clic'),
                subtitle: const Text(
                  'Avance ou recule dans la vidéo en double-cliquant sur les côtés',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerDoubleTapSeekProvider.notifier).set(v),
              ),
              if (doubleTapSeek)
                ListTile(
                  leading: const Icon(Broken.timer_1),
                  title: const Text('Durée du double-clic'),
                  subtitle: Text(
                    '$seekSeconds secondes',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Broken.arrow_right_2),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: RadioGroup<int>(
                        groupValue: seekSeconds,
                        onChanged: (v) {
                          if (v == null) return;
                          ref
                              .read(playerDoubleTapSeekSecondsProvider.notifier)
                              .set(v);
                          Navigator.pop(ctx);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [5, 10, 15, 30, 60]
                              .map(
                                (s) => RadioListTile<int>(
                                  value: s,
                                  title: Text('$s secondes'),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              SwitchListTile(
                secondary: const Icon(Broken.maximize_4),
                value: swipeGestures,
                title: const Text('Gestes de balayage'),
                subtitle: const Text(
                  'Balayage horizontal pour chercher, vertical pour le volume '
                  'et la luminosité',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerSwipeGesturesProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.element_4),
                value: gestureOverlay,
                title: const Text('Superposition des gestes'),
                subtitle: const Text(
                  'Affiche un aperçu pendant un geste',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerGestureOverlayProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.play_circle),
                value: doubleTapPause,
                title: const Text('Double-clic au centre pour lecture/pause'),
                onChanged: (v) =>
                    ref.read(playerDoubleTapToPauseProvider.notifier).set(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
