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

    Options _buildOptions(String targetUrl) => Options(
          headers: {
            "user-agent": _userAgentForUrl(targetUrl),
            "Cache-Control": "max-age=3600",
            "Connection": "keep-alive",
            "host": Uri.parse(targetUrl).host,
            if (headers.containsKey("range")) "range": headers["range"],
          },
          responseType: ResponseType.stream,
          validateStatus: (status) => status! < 400,
        );

    // YouTube CDN returns 403 on HEAD requests for videoplayback URLs,
    // so we skip HEAD entirely and go straight to GET.
    // If GET fails (expired URL), we refresh and retry once.
    dio_lib.Response<ResponseBody> res;
    try {
      res = await dio.get<ResponseBody>(url, options: _buildOptions(url));
    } catch (e, stack) {
      AppLogger.reportError(e, stack);

      // URL likely expired — refresh it and retry GET once.
      final sourcedTrack = await ref
          .read(sourcedTrackProvider(track.query).notifier)
          .refreshStreamingUrl();

      url = sourcedTrack.url!;
      AppLogger.log.i("Refreshing ${track.query.name}: $url");
      res = await dio.get<ResponseBody>(url, options: _buildOptions(url));
    }

    // Check if the refreshed/initial URL is an m3u8 playlist — redirect
    // those directly because libmpv handles HLS range requests internally.
    final resolvedContentType = res.headers.value("content-type");
    if (resolvedContentType == "application/vnd.apple.mpegurl") {
      return dio_lib.Response<Uint8List>(
        statusCode: 301,
        statusMessage: "M3U8 Redirect",
        headers: Headers.fromMap({
          "location": [url],
          "content-type": ["application/vnd.apple.mpegurl"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
        isRedirect: true,
      );
    }

    AppLogger.log.i(
      "Streaming ${track.query.name}\n"
      "Status Code: ${res.statusCode}\n"
      "Headers: ${res.headers.map}",
    );

    if (!userPreferences.cacheMusic) {
      return res;
    }

    final resStream = res.data!.stream.asBroadcastStream();

    final trackPartialCacheFile = File("${trackCacheFile.path}.part");
    if (!await trackPartialCacheFile.exists()) {
      await trackPartialCacheFile.create(recursive: true);
    }

    final partialCacheFileSink =
        trackPartialCacheFile.openWrite(mode: FileMode.writeOnlyAppend);
    final contentRange = res.headers.value("content-range") != null
        ? ContentRangeHeader.parse(res.headers.value("content-range") ?? "")
        : ContentRangeHeader(0, 0, 0);

    resStream.listen(
      (data) {
        partialCacheFileSink.add(data);
      },
      onError: (e, stack) {
        partialCacheFileSink.close();
      },
      onDone: () async {
        await partialCacheFileSink.close();

        final fileLength = await trackPartialCacheFile.length();
        if (fileLength != contentRange.total) return;

        await trackPartialCacheFile.rename(trackCacheFile.path);

        if (track.qualityPreset!.getFileExtension() == "weba") return;

        final imageBytes = await ServiceUtils.downloadImage(
          track.query.album.images.asUrlString(
            placeholder: ImagePlaceholder.albumArt,
            index: 1,
          ),
        );

        await MetadataGod.writeMetadata(
          file: trackCacheFile.path,
          metadata: track.query.toMetadata(
            imageBytes: imageBytes,
            fileLength: fileLength,
          ),
        ).catchError((e, stackTrace) {
          AppLogger.reportError(e, stackTrace);
        });
      },
      cancelOnError: true,
    );

    res.data?.stream = resStream;
    return res;
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

      // Serve from the local cache when available (no YouTube request needed).
      if (userPreferences.cacheMusic) {
        final trackCacheFile =
            File(await _getTrackCacheFilePath(sourcedTrack));
        if (await trackCacheFile.exists()) {
          final res = await streamTrack(request, sourcedTrack, request.headers);
          if (res.data is ResponseBody) {
            return Response(
              res.statusCode!,
              body: (res.data as ResponseBody).stream,
              headers: res.headers.map,
            );
          }
          return Response(res.statusCode!, body: res.data, headers: res.headers.map);
        }
      }

      // For non-cached tracks, redirect MediaKit's libmpv to the CDN URL
      // directly instead of proxying through Dart.  Dart's HttpClient TLS
      // fingerprint causes YouTube CDN to return 403; libmpv's native
      // HTTP stack (via FFmpeg) is accepted by YouTube CDN.
      String url = sourcedTrack.url ??
          await ref
              .read(sourcedTrackProvider(sourcedTrack.query).notifier)
              .swapWithNextSibling()
              .then((t) => t.url!);

      AppLogger.log.i(
        "CDN redirect: ${sourcedTrack.query.name}\nURL: $url",
      );
      return Response.found(url);
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
