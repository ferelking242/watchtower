import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/models/parser/range_headers.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/audio_player/state.dart';

import 'package:watchtower/modules/music/provider/server/active_track_sources.dart';
import 'package:watchtower/modules/music/provider/server/sourced_track_provider.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/logger/logger.dart';
import 'package:watchtower/modules/music/services/sourced_track/sourced_track.dart';
import 'package:watchtower/modules/music/utils/service_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final _deviceClients = Set.unmodifiable({
  YoutubeApiClient.ios,
  YoutubeApiClient.android,
  YoutubeApiClient.mweb,
  YoutubeApiClient.safari,
});

String? get _randomUserAgent => _deviceClients
    .elementAt(
      Random().nextInt(_deviceClients.length),
    )
    .payload["context"]["client"]["userAgent"];

/// Returns the YouTube user-agent that matches the client type embedded in
/// [url]'s `c=` query parameter (e.g. ANDROID, IOS, MWEB).
/// Sending a mismatched user-agent causes the CDN to return 403.
/// Falls back to the Android user-agent when no match is found.
String _userAgentForUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final clientType = uri.queryParameters['c']?.toUpperCase();
    if (clientType != null) {
      for (final client in _deviceClients) {
        final name = (client.payload['context']?['client']?['clientName']
                as String?)
            ?.toUpperCase();
        if (name == clientType) {
          return client.payload['context']?['client']?['userAgent'] as String?
              ?? YoutubeApiClient.android.payload['context']['client']['userAgent'] as String;
        }
      }
    }
  } catch (_) {}
  return YoutubeApiClient.android.payload['context']['client']['userAgent']
      as String;
}

class ServerPlaybackRoutes {
  final Ref ref;
  UserPreferences get userPreferences => ref.read(userPreferencesProvider);
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  Future<String> _getTrackCacheFilePath(SourcedTrack track) async {
    return join(
      await UserPreferencesNotifier.getMusicCacheDir(),
      ServiceUtils.sanitizeFilename(
        '${track.query.name} - ${track.query.artists.map((d) => d.name).join(",")} (${track.info.id}).${track.qualityPreset!.getFileExtension()}',
      ),
    );
  }

  Future<SourcedTrack?> _getSourcedTrack(
    Request request,
    String trackId,
  ) async {
    final track =
        playlist.tracks.firstWhereOrNull((element) => element.id == trackId);
    if (track == null) return null;

    final activeSourcedTrack =
        await ref.read(activeTrackSourcesProvider.future);

    final media = audioPlayer.playlist.medias
        .firstWhereOrNull((e) => e.uri == request.requestedUri.toString());
    if (media == null) return null;
    final spotubeMedia =
        media is SpotubeMedia ? media : SpotubeMedia.media(media);
    final sourcedTrack = activeSourcedTrack?.track.id == track.id
        ? activeSourcedTrack?.source
        : await ref.read(
            sourcedTrackProvider(spotubeMedia.track as SpotubeFullTrackObject)
                .future,
          );

    return sourcedTrack as SourcedTrack?;
  }

  Future<dio_lib.Response> streamTrackInformation(
    Request request,
    SourcedTrack track,
  ) async {
    AppLogger.log.i(
      "HEAD request for track: ${track.query.name}\n"
      "Headers: ${request.headers}",
    );

    final trackCacheFile = File(await _getTrackCacheFilePath(track));

    if (await trackCacheFile.exists() && userPreferences.cacheMusic) {
      final fileLength = await trackCacheFile.length();

      return dio_lib.Response(
        statusCode: 200,
        headers: Headers.fromMap({
          "content-type": ["audio/${track.qualityPreset!.name}"],
          "content-length": ["$fileLength"],
          "accept-ranges": ["bytes"],
          "content-range": ["bytes 0-$fileLength/$fileLength"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
      );
    }

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    // Return a synthetic HEAD response instead of querying YouTube CDN.
    // Dart's HttpClient TLS fingerprint is rejected by YouTube CDN (→ 403).
    // libmpv only needs content-type + accept-ranges to proceed to GET.
    return dio_lib.Response<Uint8List>(
      statusCode: 200,
      headers: Headers.fromMap({
        "content-type": ["audio/${track.qualityPreset?.name ?? 'mp4'}"],
        "accept-ranges": ["bytes"],
      }),
      requestOptions: RequestOptions(path: request.requestedUri.toString()),
    );
  }

  Future<dio_lib.Response> streamTrack(
    Request request,
    SourcedTrack track,
    Map<String, dynamic> headers,
  ) async {
    AppLogger.log.i(
      "GET request for track: ${track.query.name}\n"
      "Headers: ${request.headers}",
    );

    final trackCacheFile = File(await _getTrackCacheFilePath(track));

    if (await trackCacheFile.exists() && userPreferences.cacheMusic) {
      final bytes = await trackCacheFile.readAsBytes();
      final cachedFileLength = bytes.length;

      return dio_lib.Response<Uint8List>(
        statusCode: 200,
        headers: Headers.fromMap({
          "content-type": ["audio/${track.qualityPreset!.name}"],
          "content-length": ["${cachedFileLength - 1}"],
          "accept-ranges": ["bytes"],
          "content-range": [
            "bytes 0-${cachedFileLength - 1}/$cachedFileLength"
          ],
          "connection": ["close"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
        data: bytes,
      );
    }

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    // Redirect libmpv directly to the YouTube CDN URL instead of proxying.
    // Dart's HttpClient TLS fingerprint is rejected by YouTube CDN (→ 403).
    // libmpv/libcurl follows 302 redirects transparently using its own TLS
    // stack, which matches Spotube's original direct-URL approach.
    // Note: caching is bypassed; add a post-download hook if needed later.
    AppLogger.log.i("Redirecting ${track.query.name} → $url");
    return dio_lib.Response<Uint8List>(
      statusCode: 302,
      statusMessage: "Direct CDN Redirect",
      headers: Headers.fromMap({
        "location": [url],
        "cache-control": ["no-cache"],
      }),
      requestOptions: RequestOptions(path: request.requestedUri.toString()),
      isRedirect: true,
    );

  }

  /// @head('/stream/<trackId>')
  Future<Response> headStreamTrackId(Request request, String trackId) async {
    try {
      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final res = await streamTrackInformation(
        request,
        sourcedTrack,
      );

      return Response(
        res.statusCode!,
        headers: res.headers.map,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/stream/<trackId>')
  Future<Response> getStreamTrackId(Request request, String trackId) async {
    try {
      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final res = await streamTrack(
        request,
        sourcedTrack,
        request.headers,
      );

      if (res.data is ResponseBody) {
        return Response(
          res.statusCode!,
          body: (res.data as ResponseBody).stream,
          headers: res.headers.map,
        );
      }

      return Response(
        res.statusCode!,
        body: res.data,
        headers: res.headers.map,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/playback/toggle-playback')
  Future<Response> togglePlayback(Request request) async {
    audioPlayer.isPlaying
        ? await audioPlayer.pause()
        : await audioPlayer.resume();

    return Response.ok("Playback toggled");
  }

  /// @get('/playback/previous')
  Future<Response> previousTrack(Request request) async {
    await audioPlayer.skipToPrevious();
    return Response.ok("Previous track");
  }

  /// @get('/playback/next')
  Future<Response> nextTrack(Request request) async {
    await audioPlayer.skipToNext();
    return Response.ok("Next track");
  }
}

final serverPlaybackRoutesProvider =
    Provider((ref) => ServerPlaybackRoutes(ref));
