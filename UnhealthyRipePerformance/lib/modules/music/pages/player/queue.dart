import 'package:auto_route/annotations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/modules/player/player_queue.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';

class PlayerQueuePage extends HookConsumerWidget {
  const PlayerQueuePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(
      audioPlayerProvider,
    );
    final playlistNotifier = ref.read(audioPlayerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PlayerQueue.fromAudioPlayerNotifier(
          floating: false,
          playlist: playlist,
          notifier: playlistNotifier,
        ),
      ),
    );
  }
}
