import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf_io.dart';
import 'package:watchtower/modules/music/provider/server/pipeline.dart';
import 'package:watchtower/modules/music/provider/server/router.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';

final serverProvider = FutureProvider(
  (ref) async {
    final enabledRemoteConnect = ref.watch(
      userPreferencesProvider.select((value) => value.enableConnect),
    );
    final connectPort = ref.watch(
      userPreferencesProvider.select((value) => value.connectPort),
    );
    final pipeline = ref.watch(pipelineProvider);
    final router = ref.watch(serverRouterProvider);

    final handler = pipeline.addHandler(router.call);
    final address =
        enabledRemoteConnect ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;

    // Port -1 means "pick one automatically". Binding port 0 lets the OS hand
    // out a free port and reporting `server.port` keeps the URL the player
    // builds in sync with the socket that is actually listening: a hard-coded
    // random port could already be taken, and the bind failure left every
    // `SpotubeMedia` pointing at a dead port (silent playback failures).
    Future<HttpServer> bind(int port) async {
      try {
        return await serve(handler, address, port);
      } on SocketException {
        if (port == 0) rethrow;
        AppLogger.log.w(
          'Playback server could not bind port $port, falling back to a free port',
        );
        return serve(handler, address, 0);
      }
    }

    final server = await bind(connectPort == -1 ? 0 : connectPort);
    SpotubeMedia.serverPort = server.port;

    AppLogger.log.t(
      'Playback server at http://${server.address.host}:${server.port}',
    );

    ref.onDispose(() {
      server.close();
    });

    return (
      server: server,
      port: SpotubeMedia.serverPort,
    );
  },
);
