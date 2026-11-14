import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

final audioPlayerLoopMode = StreamProvider<PlaylistMode>((ref) {
  return audioPlayer.loopModeStream;
});

final audioPlayerShuffleMode = StreamProvider<bool>((ref) {
  return audioPlayer.shuffledStream;
});
final audioPlayerPlaying = StreamProvider<bool>((ref) {
  return audioPlayer.playingStream;
});

final trayMenuProvider = Provider((ref) {
  final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
  final isPlaybackPlaying =
      ref.watch(audioPlayerProvider.select((s) => s.activeTrack != null));
  final isLoopOne =
      ref.watch(audioPlayerLoopMode).asData?.value == PlaylistMode.single;
  final isShuffled = ref.watch(audioPlayerShuffleMode).asData?.value ?? false;
  final isPlaying = ref.watch(audioPlayerPlaying).asData?.value ?? false;
  final l10n = lookupAppLocalizations(
    ref.watch(l10nLocaleStateProvider),
  );

  return Menu(
    items: [
      MenuItem(
        label: l10n.show_hide_window,
        onClick: (menuItem) async {
          if (await windowManager.isVisible()) {
            await windowManager.hide();
          } else {
            await windowManager.focus();
            await windowManager.show();
          }
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: isPlaying ? l10n.pause : l10n.play,
        disabled: !isPlaybackPlaying,
        onClick: (menuItem) async {
          if (audioPlayer.isPlaying) {
            await audioPlayer.pause();
          } else {
            await audioPlayer.resume();
          }
        },
      ),
      MenuItem(
        label: l10n.next,
        disabled: !isPlaybackPlaying,
        onClick: (menuItem) {
          audioPlayer.skipToNext();
        },
      ),
      MenuItem(
        label: l10n.previous,
        disabled: !isPlaybackPlaying,
        onClick: (menuItem) {
          audioPlayer.skipToPrevious();
        },
      ),
      MenuItem.submenu(
        label: l10n.playback,
        submenu: Menu(
          items: [
            MenuItem(
              label: l10n.repeat,
              checked: isLoopOne,
              onClick: (menuItem) {
                audioPlayer.setLoopMode(
                  isLoopOne ? PlaylistMode.none : PlaylistMode.single,
                );
              },
            ),
            MenuItem(
              label: l10n.shuffle,
              checked: isShuffled,
              onClick: (menuItem) {
                audioPlayer.setShuffle(!isShuffled);
              },
            ),
            MenuItem.separator(),
            MenuItem(
              label: l10n.stop,
              onClick: (menuItem) {
                playlistNotifier.stop();
              },
            ),
          ],
        ),
      ),
      MenuItem.separator(),
      MenuItem(
        label: l10n.quit,
        onClick: (menuItem) {
          exit(0);
        },
      ),
    ],
  );
});
