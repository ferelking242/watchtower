import 'dart:convert';

import 'package:media_kit/media_kit.dart' hide Track;
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/state.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/collections/riverpod_compat.dart';
import 'package:watchtower/modules/music/models/connect/connect.dart';

import 'package:watchtower/modules/music/provider/connect/clients.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

final playingProvider = StateProvider<bool>(
  (ref) => false,
);

final positionProvider = StateProvider<Duration>(
  (ref) => Duration.zero,
);

final durationProvider = StateProvider<Duration>(
  (ref) => Duration.zero,
);

final shuffleProvider = StateProvider<bool>(
  (ref) => false,
);

final loopModeProvider = StateProvider<PlaylistMode>(
  (ref) => PlaylistMode.none,
);

final queueProvider = StateProvider<AudioPlayerState>(
  (ref) => AudioPlayerState(
    playing: audioPlayer.isPlaying,
    loopMode: audioPlayer.loopMode,
    shuffled: audioPlayer.isShuffled,
    tracks: [],
    currentIndex: 0,
    collections: [],
  ),
);

final volumeProvider = StateProvider<double>(
  (ref) => 1.0,
);

typedef ConnectState = ({WebSocketChannel channel, Stream stream});

class ConnectNotifier extends AsyncNotifier<ConnectState?> {
  @override
  build() async {
    try {
      final connectClients = await ref.watch(connectClientsProvider.future);

      if (connectClients.resolvedService == null) return null;

      final service = connectClients.resolvedService!;

      AppLogger.log.t(
        '♾️ Connecting to ${service.name}: ws://${service.host}:${service.port}/ws',
      );

      final channel = WebSocketChannel.connect(
        Uri.parse('ws://${service.host}:${service.port}/ws'),
      );

      await channel.ready;

      AppLogger.log.t(
        '✅ Connected to ${service.name}: ws://${service.host}:${service.port}/ws',
      );

      final stream = channel.stream.asBroadcastStream();

      final subscription = stream.listen(
        (message) {
          final event =
              WebSocketEvent.fromJson(jsonDecode(message), (data) => data);

          event.onQueue((event) {
            ref.read(queueProvider.notifier).state = event.data;
          });

          event.onPlaying((event) {
            ref.read(playingProvider.notifier).state = event.data;
          });

          event.onPosition((event) {
            ref.read(positionProvider.notifier).state = event.data;
          });

          event.onDuration((event) {
            ref.read(durationProvider.notifier).state = event.data;
          });

          event.onShuffle((event) {
            ref.read(shuffleProvider.notifier).state = event.data;
          });

          event.onLoop((event) {
            ref.read(loopModeProvider.notifier).state = event.data;
          });

          event.onVolume((event) {
            ref.read(volumeProvider.notifier).state = event.data;
          });

          event.onError((event) {
            if (event.data == "Connection denied") {
              ref.read(connectClientsProvider.notifier).clearResolvedService();

              if (rootNavigatorKey.currentContext?.mounted == true) {
                final theme = Theme.of(rootNavigatorKey.currentContext!);

                ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
                  SnackBar(
                    content: Text(rootNavigatorKey.currentContext!.l10n.connection_request_denied),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          });
        },
        onError: (error) {
          AppLogger.reportError(error, StackTrace.current);
        },
      );

      ref.onDispose(() {
        subscription.cancel();
        channel.sink.close(status.goingAway);
      });

      return (channel: channel, stream: stream);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      rethrow;
    }
  }

  Future<void> emit(Object message) async {
    if (state.value == null) return;
    state.value?.channel.sink.add(
      message is String ? message : (message as dynamic).toJson(),
    );
  }

  Future<void> resume() async {
    emit(WebSocketResumeEvent());
  }

  Future<void> pause() async {
    emit(WebSocketPauseEvent());
  }

  Future<void> stop() async {
    emit(WebSocketStopEvent());
  }

  Future<void> jumpTo(int position) async {
    emit(WebSocketJumpEvent(position));
  }

  Future<void> load(WebSocketLoadEventData data) async {
    emit(WebSocketLoadEvent(data));
  }

  Future<void> next() async {
    emit(WebSocketNextEvent());
  }

  Future<void> previous() async {
    emit(WebSocketPreviousEvent());
  }

  Future<void> seek(Duration position) async {
    emit(WebSocketSeekEvent(position));
  }

  Future<void> setShuffle(bool value) async {
    emit(WebSocketShuffleEvent(value));
  }

  Future<void> setLoopMode(PlaylistMode value) async {
    emit(WebSocketLoopEvent(value));
  }

  Future<void> addTrack(SpotubeFullTrackObject data) async {
    emit(WebSocketAddTrackEvent(data));
  }

  Future<void> removeTrack(String data) async {
    emit(WebSocketRemoveTrackEvent(data));
  }

  Future<void> reorder(ReorderData data) async {
    emit(WebSocketReorderEvent(data));
  }

  Future<void> setVolume(double value) async {
    emit(WebSocketVolumeEvent(value));
  }
}

final connectProvider = AsyncNotifierProvider<ConnectNotifier, ConnectState?>(
  () => ConnectNotifier(),
);
