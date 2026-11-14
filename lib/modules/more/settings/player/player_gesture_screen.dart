import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Video player gestures, mirroring Aniyomi's "Gestes" block.
class PlayerGestureScreen extends ConsumerWidget {
  const PlayerGestureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doubleTapSeek = ref.watch(playerDoubleTapSeekProvider);
    final seekSeconds = ref.watch(playerDoubleTapSeekSecondsProvider);
    final swipeGestures = ref.watch(playerSwipeGesturesProvider);
    final gestureOverlay = ref.watch(playerGestureOverlayProvider);
    final doubleTapPause = ref.watch(playerDoubleTapToPauseProvider);

    return SettingsSubpageScaffold(
      title: l10n.player_gestures_title,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Broken.mouse),
                value: doubleTapSeek,
                title: Text(l10n.player_double_tap_seek),
                subtitle: Text(
                  l10n.player_double_tap_seek_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerDoubleTapSeekProvider.notifier).set(v),
              ),
              if (doubleTapSeek)
                ListTile(
                  leading: const Icon(Broken.timer_1),
                  title: Text(l10n.player_double_tap_duration),
                  subtitle: Text(
                    l10n.player_seconds(seekSeconds),
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
                                  title: Text(l10n.player_seconds(s)),
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
                title: Text(l10n.player_swipe_gestures),
                subtitle: Text(
                  l10n.player_swipe_gestures_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerSwipeGesturesProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.element_4),
                value: gestureOverlay,
                title: Text(l10n.player_gesture_overlay),
                subtitle: Text(
                  l10n.player_gesture_overlay_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerGestureOverlayProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.play_circle),
                value: doubleTapPause,
                title: Text(l10n.player_center_double_tap),
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
