import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:logger/logger.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/server/server.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

/// Initialises HomeWidget once per process. On iOS the package requires an
/// App Group to be set before any save/update call, otherwise it logs a
/// warning and silently skips writes.
Future<void> _initHomeWidget() async {
  if (!kIsMobile) return;
  if (kIsIOS) {
    await HomeWidget.setAppGroupId('group.com.watchtower.app');
  }
  await HomeWidget.registerBackgroundCallback(glanceBackgroundCallback);
}

@pragma("vm:entry-point")
Future<void> glanceBackgroundCallback(Uri? data) async {
  final logger = Logger();
  try {
    if (data == null ||
        data.host != "playback" ||
        data.pathSegments.isEmpty ||
        data.queryParameters["serverAddress"] == null) {
      return;
    }

    final command = data.pathSegments.first;
    final res = await get(
      Uri.parse(
        "http://${data.queryParameters["serverAddress"]}/playback/$command",
      ),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to execute command: $command\nBody: ${res.body}");
    }
  } catch (e) {
    logger.e("[GlanceBackgroundCallback] $e");
  }
}

Future<bool?> _saveWidgetData<T>(String key, T? value) async {
  try {
    if (!kIsMobile) return null;

    return await HomeWidget.saveWidgetData<T>(key, value);
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    return null;
  }
}

Future<void> _updateWidget() async {
  try {
    if (!kIsMobile) return;

    if (kIsAndroid) {
      await HomeWidget.updateWidget(
        androidName: 'HomePlayerWidgetReceiver',
        qualifiedAndroidName:
            'com.watchtower.app.glance.HomePlayerWidgetReceiver',
      );
    }
    if (kIsIOS) {
      await HomeWidget.updateWidget(
        name: 'HomePlayerWidget',
        iOSName: 'HomePlayerWidget',
      );
    }
  } on Exception catch (e, stack) {
    AppLogger.reportError(e, stack);
  }
}

Future<void> _sendActiveTrack(SpotubeTrackObject? track) async {
  if (track == null) {
    await _saveWidgetData("activeTrack", null);
    await _updateWidget();
    return;
  }

  final jsonTrack = track.toJson();

  final image = track.album.images.firstOrNull;
  final cachedImage = image == null
      ? null
      : image.url.startsWith("http")
          ? (await DefaultCacheManager().getSingleFile(image.url)).path
          : image.url;
  final data = {
    ...jsonTrack,
    "album": {
      ...jsonTrack["album"],
      "images": [
        if (cachedImage != null && image != null)
          {
            ...image.toJson(),
            "path": cachedImage,
          }
      ]
    }
  };

  await _saveWidgetData("activeTrack", jsonEncode(data));

  await _updateWidget();
}

final glanceProvider = Provider((ref) {
  _initHomeWidget();

  final server = ref.read(serverProvider);
  final activeTrack = ref.read(audioPlayerProvider).activeTrack;

  server.whenData(
    (value) async {
      final (:server, :port) = value;

      await _saveWidgetData(
        "playbackServerAddress",
        "${server.address.host}:$port",
      );
      await _updateWidget();
    },
  );

  _sendActiveTrack(activeTrack);

  ref.listen(serverProvider, (prev, next) async {
    next.whenData(
      (value) async {
        final (:server, :port) = value;

        await _saveWidgetData(
          "playbackServerAddress",
          "${server.address.host}:$port",
        );
        await _updateWidget();
      },
    );
  });

  ref.listen(
    audioPlayerProvider,
    (previous, next) async {
      try {
        if (previous?.activeTrack != next.activeTrack &&
            next.activeTrack != null) {
          await _sendActiveTrack(next.activeTrack);
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    },
  );

  final subscriptions = [
    audioPlayer.playingStream.listen((playing) async {
      await _saveWidgetData("isPlaying", playing);
      await _updateWidget();
    }),
    audioPlayer.positionStream.listen((position) async {
      await _saveWidgetData("position", position.inSeconds);
      await _updateWidget();
    }),
    audioPlayer.durationStream.listen((duration) async {
      await _saveWidgetData("duration", duration.inSeconds);
      await _updateWidget();
    }),
  ];

  ref.onDispose(() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
  });
});
