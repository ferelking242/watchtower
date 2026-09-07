import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/youtube_watch_resolver.dart';
import 'package:watchtower/services/torrent_server.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;

import '../models/source.dart';
part 'get_video_list.g.dart';

@riverpod
Future<(List<Video>, bool, List<String>, Directory?)> getVideoList(
  Ref ref, {
  required Chapter episode,
}) async {
  (List<Video>, bool, List<String>, Directory?) result;
  final keepAlive = ref.keepAlive();

  final epManga = episode.manga.value;
  final srcLabel =
      '${epManga?.source ?? "?"}[${epManga?.lang ?? "?"}]';
  final epLabel = 'ep:${episode.id}';

  AppLogger.log(
    '[$epLabel] getVideoList START  source=$srcLabel  url=${episode.url ?? "n/a"}  name="${episode.name}"',
    logLevel: LogLevel.info,
    tag: LogTag.watch,
  );

  // ── Web: all video resolution goes through the remote server ────────────
  if (kIsWeb) {
    try {
      if (epManga == null) throw StateError('Episode has no linked manga');
      final episodeUrl = episode.url ?? '';
      final sourceId = epManga.sourceId;

      // isLocal source on web → episode.url is already a direct video URL
      final localSrc = getSource(epManga.lang!, epManga.source!, sourceId);
      if (localSrc?.isLocal == true && episodeUrl.isNotEmpty) {
        keepAlive.close();
        return ([Video(episodeUrl, episode.name ?? 'Vidéo', episodeUrl)], false, <String>[], null);
      }

      if (sourceId != null && episodeUrl.isNotEmpty &&
          RemoteClient.instance.isConfigured) {
        final data = await RemoteClient.instance.get(
          '/api/sources/$sourceId/videos',
          params: {'url': episodeUrl},
        );
        final rawVideos = (data['videos'] as List?)?.cast<Map<String, dynamic>>();
        if (rawVideos != null && rawVideos.isNotEmpty) {
          final videos = rawVideos.map((v) => Video(
            v['url'] as String? ?? '',
            v['quality'] as String? ?? episode.name ?? 'Auto',
            v['originalUrl'] as String? ?? v['url'] as String? ?? '',
            headers: (v['headers'] as Map?)?.cast<String, String>(),
          )).toList();
          keepAlive.close();
          return (videos, false, <String>[], null);
        }
      }
    } catch (e) {
      AppLogger.log('[$epLabel] getVideoList WEB ERROR: $e',
          logLevel: LogLevel.error, tag: LogTag.watch);
    }
    keepAlive.close();
    return (<Video>[], false, <String>[], null);
  }

  try {
    if (epManga == null) throw StateError('Episode has no linked manga');

    // ── Local/demo source — episode.url IS the direct video URL ──────────
    // Sources flagged isLocal=true (e.g. the FrenchStream Démo web demo
    // source) have no extension code to run and no filesystem to touch.
    // Return the chapter URL directly, exactly like webview_intercept.
    final localSource =
        getSource(epManga.lang!, epManga.source!, epManga.sourceId);
    if (localSource?.isLocal == true) {
      final videoUrl = episode.url ?? '';
      AppLogger.log(
        '[$epLabel] getVideoList LOCAL_SOURCE  url=$videoUrl',
        logLevel: LogLevel.info,
        tag: LogTag.watch,
      );
      keepAlive.close();
      return (
        [Video(videoUrl, episode.name ?? 'Vidéo', videoUrl)],
        false,
        <String>[],
        null,
      );
    }

    final storageProvider = StorageProvider();
    final mpvDirectory = await storageProvider.getMpvDirectory();
    final mangaDirectory = await storageProvider.getMangaMainDirectory(episode);
    final isLocalArchive =
        (epManga.isLocalArchive ?? false) &&
        epManga.source != "torrent";
    final mp4animePath = p.join(
      mangaDirectory!.path,
      "${episode.name!.replaceForbiddenCharacters(' ')}.mp4",
    );
    List<String> infoHashes = [];

    // ── Local file path — no extension call needed ────────────────────────
    if (await File(mp4animePath).exists() || isLocalArchive) {
      AppLogger.log(
        '[$epLabel] getVideoList LOCAL FILE  path=${isLocalArchive ? episode.archivePath : mp4animePath}',
        logLevel: LogLevel.debug,
        tag: LogTag.watch,
      );
      final animeDir =
          episode.archivePath != null && episode.manga.value?.source == "local"
          ? Directory(p.dirname(episode.archivePath!))
          : null;
      final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
        episode,
        mangaMainDirectory: animeDir ?? mangaDirectory,
      ))!;
      final path = isLocalArchive ? episode.archivePath : mp4animePath;
      final subtitlesDir = Directory(
        p.join('${chapterDirectory.path}_subtitles'),
      );
      List<Track> subtitles = [];
      if (subtitlesDir.existsSync()) {
        for (var element in subtitlesDir.listSync()) {
          if (element is File) {
            final subtitle = Track(
              label: element.uri.pathSegments.last.replaceAll('.srt', ''),
              file: element.uri.toString(),
            );
            subtitles.add(subtitle);
          }
        }
      }
      AppLogger.log(
        '[$epLabel] getVideoList DONE (local)  subtitles=${subtitles.length}',
        logLevel: LogLevel.info,
        tag: LogTag.watch,
      );
      keepAlive.close();
      return (
        [Video(path!, episode.name!, path, subtitles: subtitles)],
        true,
        infoHashes,
        mpvDirectory,
      );
    }

    // ── WebView-intercepted URL — play directly, no extension needed ──────────
    if (epManga.source == 'webview_intercept') {
      final videoUrl = episode.url ?? '';
      AppLogger.log(
        '[$epLabel] getVideoList WEBVIEW_INTERCEPT  url=$videoUrl',
        logLevel: LogLevel.info,
        tag: LogTag.watch,
      );
      keepAlive.close();
      return (
        [Video(videoUrl, episode.name ?? 'Vidéo', videoUrl)],
        false,
        <String>[],
        mpvDirectory,
      );
    }

    final source = getSource(
      epManga.lang!,
      epManga.source!,
      epManga.sourceId,
    );
    final proxyServer = ref.read(androidProxyServerStateProvider);

    // ── Torrent path ──────────────────────────────────────────────────────
    final isMihonTorrent =
        source?.sourceCodeLanguage == SourceCodeLanguage.mihon &&
        source!.name!.contains("(Torrent");
    if ((source?.isTorrent ?? false) ||
        epManga.source == "torrent" ||
        isMihonTorrent) {
      AppLogger.log(
        '[$epLabel] getVideoList TORRENT path  archivePath=${episode.archivePath ?? "none"}',
        logLevel: LogLevel.debug,
        tag: LogTag.watch,
      );
      List<Video> list = [];
      List<Video> torrentList = [];
      if (episode.archivePath?.isNotEmpty ?? false) {
        final (videos, infohash) = await MTorrentServer().getTorrentPlaylist(
          episode.url,
          episode.archivePath,
        );
        AppLogger.log(
          '[$epLabel] getVideoList DONE (torrent local)  videos=${videos.length}',
          logLevel: LogLevel.info,
          tag: LogTag.watch,
        );
        keepAlive.close();
        return (videos, false, [infohash ?? ""], mpvDirectory);
      }

      try {
        AppLogger.log(
          '[$epLabel] getVideoList calling extension getVideoList (torrent source)',
          logLevel: LogLevel.info,
          tag: LogTag.watch,
        );
        list = await getIsolateService.get<List<Video>>(
          url: episode.url!,
          source: source,
          serviceType: 'getVideoList',
          proxyServer: proxyServer,
        );
      } catch (e) {
        AppLogger.log(
          '[$epLabel] getVideoList torrent extension failed, using direct URL: $e',
          logLevel: LogLevel.warning,
          tag: LogTag.watch,
        );
        list = [Video(episode.url!, episode.name!, episode.url!)];
      }

      for (var v in list) {
        final (videos, infohash) = await MTorrentServer().getTorrentPlaylist(
          v.url,
          episode.archivePath,
        );
        for (var video in videos) {
          torrentList.add(
            video..quality = video.quality.substringBeforeLast("."),
          );
          if (infohash != null) {
            infoHashes.add(infohash);
          }
        }
      }
      AppLogger.log(
        '[$epLabel] getVideoList DONE (torrent)  videos=${torrentList.length}  hashes=${infoHashes.length}',
        logLevel: LogLevel.info,
        tag: LogTag.watch,
      );
      keepAlive.close();
      return (torrentList, false, infoHashes, mpvDirectory);
    }

    // ── Extension call ────────────────────────────────────────────────────
    AppLogger.log(
      '[$epLabel] getVideoList calling extension  source=$srcLabel  url=${episode.url}',
      logLevel: LogLevel.info,
      tag: LogTag.watch,
    );
    final sw = Stopwatch()..start();

    List<Video> list = await getIsolateService.get<List<Video>>(
      url: episode.url!,
      source: source,
      serviceType: 'getVideoList',
      proxyServer: proxyServer,
    );
    sw.stop();

    List<Video> videos = [];
    for (var video in list) {
      if (!videos.any((element) => element.quality == video.quality)) {
        videos.add(video);
      }
    }

    // Some source extensions (lightweight FR streaming wrappers, mostly)
    // have no real CDN backend of their own — they just relay the official
    // YouTube embed the site uses, so they hand back the YouTube watch/embed
    // page verbatim. mpv can't play that page directly, so resolve those
    // entries into actually-playable streams via the same YouTube backend
    // already powering the Music module.
    if (videos.any(
      (v) => YoutubeWatchResolver.isYoutubeUrl(
        v.originalUrl.isNotEmpty ? v.originalUrl : v.url,
      ),
    )) {
      videos = await YoutubeWatchResolver.resolve(
        videos,
        epLabel: epLabel,
      );
    }

    if (videos.isEmpty) {
      AppLogger.log(
        '[$epLabel] getVideoList WARNING: extension returned 0 videos in ${sw.elapsedMilliseconds}ms '
        '← check extension JS or episode URL',
        logLevel: LogLevel.warning,
        tag: LogTag.watch,
      );
    } else {
      AppLogger.log(
        '[$epLabel] getVideoList DONE  ${videos.length} video(s) in ${sw.elapsedMilliseconds}ms',
        logLevel: LogLevel.info,
        tag: LogTag.watch,
      );
      for (var i = 0; i < videos.length && i < 5; i++) {
        AppLogger.log(
          '[$epLabel] getVideoList  [${i + 1}] quality="${videos[i].quality}"  '
          'url=${videos[i].originalUrl.length > 90 ? videos[i].originalUrl.substring(0, 90) : videos[i].originalUrl}',
          logLevel: LogLevel.debug,
          tag: LogTag.watch,
        );
      }
      if (videos.length > 5) {
        AppLogger.log(
          '[$epLabel] getVideoList  … +${videos.length - 5} more '
          '(switch to Extreme log mode to see all)',
          logLevel: LogLevel.debug,
          tag: LogTag.watch,
        );
      }
    }

    result = (videos, false, infoHashes, mpvDirectory);
    keepAlive.close();
    return result;
  } catch (e, st) {
    keepAlive.close();
    AppLogger.log(
      '[$epLabel] getVideoList FAILED  source=$srcLabel: $e',
      logLevel: LogLevel.error,
      tag: LogTag.watch,
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
