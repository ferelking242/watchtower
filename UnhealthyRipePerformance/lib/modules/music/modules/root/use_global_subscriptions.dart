import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/metadata_plugins/plugin_update_available_dialog.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/updater/update_checker.dart';
import 'package:watchtower/modules/music/provider/server/routes/connect.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/server/server.dart';
import 'package:watchtower/modules/music/services/connectivity_adapter.dart';
import 'package:watchtower/modules/music/utils/service_utils.dart';

void useGlobalSubscriptions(WidgetRef ref) {
  final context = useContext();
  final theme = Theme.of(context);
  // Eagerly initialize the playback server so SpotubeMedia.serverPort is
    // set before the first track play attempt (avoids port-0 race condition).
    ref.watch(serverProvider);
    final connectRoutes = ref.watch(serverConnectRoutesProvider);

  useEffect(() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ServiceUtils.checkForUpdates(context, ref);

      final pluginUpdate =
          await ref.read(metadataPluginUpdateCheckerProvider.future);

      if (pluginUpdate != null) {
        final pluginConfig = await ref.read(metadataPluginsProvider.future);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => MetadataPluginUpdateAvailableDialog(
              plugin: pluginConfig.defaultMetadataPluginConfig!,
              update: pluginUpdate,
            ),
          );
        }
      }
    });

    StreamSubscription? audioPlayerSubscription;
    bool pausedByStream = false;

    final subscriptions = [
      ConnectionCheckerService.instance.onConnectivityChanged
          .listen((connected) async {
        audioPlayerSubscription?.cancel();

        /// Pausing or resuming based on connectivity to avoid MPV skipping
        /// audio while retrying to connect
        if (audioPlayer.currentIndex >= 0) {
          if (connected && audioPlayer.isPaused && pausedByStream) {
            await audioPlayer.resume();
            pausedByStream = false;
          } else if (!connected && audioPlayer.isPlaying) {
            if ((audioPlayer.bufferedPosition - const Duration(seconds: 1)) <=
                audioPlayer.position) {
              await audioPlayer.pause();
              pausedByStream = true;
            } else {
              audioPlayerSubscription =
                  audioPlayer.positionStream.listen((position) async {
                if (ConnectionCheckerService.instance.isConnectedSync) return;

                final bufferedPosition =
                    audioPlayer.bufferedPosition - const Duration(seconds: 1);
                final duration =
                    audioPlayer.duration - const Duration(seconds: 1);

                if (bufferedPosition <= position || position >= duration) {
                  audioPlayer.pause();
                  pausedByStream = true;
                }
              });
            }
          }
        }

        // Show notification for connection related issues
        if (!context.mounted) return;

        // showToast removed
      }),
      connectRoutes.connectClientStream.listen((clientOrigin) {
        if (!context.mounted) return;
        // toast removed - use SnackBar instead
      })
    ];

    return () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };
  }, []);
}
