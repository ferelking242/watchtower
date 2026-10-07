import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/page_url_cache.dart';
import 'package:watchtower/services/http/persisted_request_metadata.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/manga/archive_reader/providers/archive_reader_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watchtower/utils/constant.dart';
part 'get_chapter_pages.g.dart';

class GetChapterPagesModel {
  Directory? path;
  List<PageUrl> pageUrls = [];
  List<bool> isLocaleList = [];
  List<Uint8List?> archiveImages = [];
  List<UChapDataPreload> uChapDataPreload;
  GetChapterPagesModel({
    required this.path,
    required this.pageUrls,
    required this.isLocaleList,
    required this.archiveImages,
    required this.uChapDataPreload,
  });
}

@riverpod
Future<GetChapterPagesModel> getChapterPages(
  Ref ref, {
  required Chapter chapter,
}) async {
  final keepAlive = ref.keepAlive();

  final chManga = chapter.manga.value;
  final srcLabel =
      '${chManga?.source ?? "?"}[${chManga?.lang ?? "?"}]';
  final chLabel = 'ch:${chapter.id}';

  AppLogger.log(
    '[$chLabel] getChapterPages START  source=$srcLabel  '
    'origin=${chapter.url == null ? "n/a" : safeUrlOriginForLog(chapter.url!)}',
    logLevel: LogLevel.info,
    tag: LogTag.page,
  );

  // ── Web: route page list through remote server, no filesystem ────────────
  if (kIsWeb) {
    try {
      final chapterUrl = chapter.url ?? '';
      final sourceId = chManga?.sourceId;
      if (sourceId != null && chapterUrl.isNotEmpty &&
          RemoteClient.instance.isConfigured) {
        final data = await RemoteClient.instance.get(
          '/api/sources/$sourceId/pages',
          params: {'url': chapterUrl},
        );
        final rawPages = (data['pages'] as List?)?.cast<Map<String, dynamic>>();
        if (rawPages != null && rawPages.isNotEmpty) {
          final pageUrls = rawPages.map((p) {
            final url = p['url'] as String? ?? '';
            final headersRaw = p['headers'] as Map?;
            final headers = headersRaw?.cast<String, String>();
            return PageUrl(url, headers: headers);
          }).toList();
          keepAlive.close();
          return GetChapterPagesModel(
            path: null,
            pageUrls: pageUrls,
            isLocaleList: List.filled(pageUrls.length, false),
            archiveImages: List.filled(pageUrls.length, null),
            uChapDataPreload: [],
          );
        }
      }
    } catch (e) {
      AppLogger.log('[$chLabel] getChapterPages WEB ERROR: $e',
          logLevel: LogLevel.error, tag: LogTag.page);
    }
    keepAlive.close();
    return GetChapterPagesModel(
      path: null,
      pageUrls: [],
      isLocaleList: [],
      archiveImages: [],
      uChapDataPreload: [],
    );
  }

  try {
    List<UChapDataPreload> uChapDataPreloadp = [];
    Directory? path;
    List<PageUrl> pageUrls = [];
    List<bool> isLocaleList = [];
    // Lecture auto-réparante : un enregistrement Settings corrompu (cache de
    // pages embarqué désérialisable → `RangeError (length)`) ne doit jamais
    // faire échouer le démarrage d'un téléchargement / l'ouverture d'un
    // chapitre. readSettingsSafely répare le record au passage.
    final settings = readSettingsSafely(isar: isar);
    List<ChapterPageurls> chapterPageUrlsList =
        settings.chapterPageUrlsList ?? [];
    final isarPageUrls = chapterPageUrlsList
        .where((element) => element.chapterId == chapter.id)
        .firstOrNull;
    final hasUnsafeCachedMetadata =
        hasUnsafePersistedPageMetadata(isarPageUrls);
    if (chapterPageUrlsList.any(hasUnsafePersistedPageMetadata)) {
      chapterPageUrlsList = chapterPageUrlsList
          .where((entry) => !hasUnsafePersistedPageMetadata(entry))
          .toList();
      settings.chapterPageUrlsList = chapterPageUrlsList;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
    }
    final incognitoMode = ref.read(incognitoModeStateProvider);
    final storageProvider = StorageProvider();
    final mangaDirectory = await storageProvider.getMangaMainDirectory(chapter);
    path = await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaDirectory,
    );

    List<Uint8List?> archiveImages = [];
    final isLocalArchive = (chapter.archivePath ?? '').isNotEmpty;

    if (!(chManga?.isLocalArchive ?? false)) {
      final source = getSource(
        chManga?.lang ?? '',
        chManga?.source ?? '',
        chManga?.sourceId,
      )!;

      // ── Cache hit? ──────────────────────────────────────────────────────
      if ((isarPageUrls?.urls?.isNotEmpty ?? false) &&
          !hasUnsafeCachedMetadata &&
          (isarPageUrls?.chapterUrl ?? chapter.url) == chapter.url) {
        AppLogger.log(
          '[$chLabel] getChapterPages CACHE HIT  '
          '${isarPageUrls!.urls!.length} URLs from Isar (no extension call needed)',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
        pageUrls = decodeChapterPageurls(isarPageUrls);
      } else {
        // ── Cache miss → call extension ─────────────────────────────────
        AppLogger.log(
          '[$chLabel] getChapterPages CACHE MISS  '
          'calling extension getPageList  source=$srcLabel  '
          'origin=${safeUrlOriginForLog(chapter.url!)}',
          logLevel: LogLevel.info,
          tag: LogTag.page,
        );
        final sw = Stopwatch()..start();
        pageUrls = await getIsolateService.get<List<PageUrl>>(
          url: chapter.url!,
          source: source,
          serviceType: 'getPageList',
        );
        sw.stop();

        if (pageUrls.isEmpty) {
          AppLogger.log(
            '[$chLabel] getChapterPages WARNING: extension returned 0 pages '
            'in ${sw.elapsedMilliseconds}ms ← check extension JS or chapter URL',
            logLevel: LogLevel.warning,
            tag: LogTag.page,
          );
        } else {
          AppLogger.log(
            '[$chLabel] getChapterPages extension returned ${pageUrls.length} pages '
            'in ${sw.elapsedMilliseconds}ms  '
            'origin[0]=${safeUrlOriginForLog(pageUrls.first.url)}',
            logLevel: LogLevel.info,
            tag: LogTag.page,
          );
        }
      }
    } else {
      AppLogger.log(
        '[$chLabel] getChapterPages local archive — skipping extension call',
        logLevel: LogLevel.debug,
        tag: LogTag.page,
      );
    }

    // Persist the source response immediately. The directory scan and reader
    // preload below can take time; a forced app stop during either operation
    // should not discard the page URLs and request headers needed on resume.
    if (!incognitoMode && pageUrls.isNotEmpty) {
      try {
        final latestSettings = readSettingsSafely(isar: isar);
        final existingEntry = (latestSettings.chapterPageUrlsList ?? [])
            .where((element) => element.chapterId == chapter.id)
            .firstOrNull;
        if (!cachedPagesUnchanged(existingEntry, pageUrls)) {
          final protectedChapterIds = isar.downloads
              .where()
              .findAllSync()
              .where(
                (download) =>
                    download.id != null && download.isDownload != true,
              )
              .map((download) => download.id!)
              .toSet();
          final chapterPageUrls = mergeChapterPageurls(
            latestSettings.chapterPageUrlsList,
            chapterId: chapter.id,
            chapterUrl: chapter.url,
            pageUrls: pageUrls,
            protectedChapterIds: protectedChapterIds,
          );
          isar.writeTxnSync(() {
            isar.settings.putSync(
              latestSettings
                ..chapterPageUrlsList = chapterPageUrls
                ..updatedAt = DateTime.now().millisecondsSinceEpoch,
            );
          });
        }
      } catch (e, st) {
        // A cache failure should remain visible in logs without breaking
        // chapter reading; the downloader retries this write before transfer.
        AppLogger.log(
          '[$chLabel] immediate page cache write FAILED: $e',
          logLevel: LogLevel.error,
          tag: LogTag.page,
          error: e,
          stackTrace: st,
        );
      }
    }

    if (pageUrls.isNotEmpty || isLocalArchive) {
      String? downloadedArchivePath;
      for (final extension in ['.cbz', '.zip']) {
        final candidate =
            p.join(mangaDirectory!.path, "${chapter.name}$extension");
        if (await File(candidate).exists()) {
          downloadedArchivePath = candidate;
          break;
        }
      }
      if (downloadedArchivePath != null || isLocalArchive) {
        final path = isLocalArchive
            ? chapter.archivePath
            : downloadedArchivePath;
        AppLogger.log(
          '[$chLabel] getChapterPages reading archive: $path',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
        final local = await ref.read(
          getArchiveDataFromFileProvider(path!).future,
        );
        for (var image in local.images!) {
          archiveImages.add(image.image!);
          isLocaleList.add(true);
        }
      } else {
        int localCount = 0;
        int remoteCount = 0;
        for (var i = 0; i < pageUrls.length; i++) {
          archiveImages.add(null);
          if (await File(p.join(path!.path, '${padIndex(i)}.jpg')).exists()) {
            isLocaleList.add(true);
            localCount++;
          } else {
            isLocaleList.add(false);
            remoteCount++;
          }
        }
        AppLogger.log(
          '[$chLabel] getChapterPages disk check: $localCount already on disk, '
          '$remoteCount to fetch',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
      }
      if (isLocalArchive) {
        for (var i = 0; i < archiveImages.length; i++) {
          pageUrls.add(PageUrl(""));
        }
      }
      for (var i = 0; i < pageUrls.length; i++) {
        uChapDataPreloadp.add(
          UChapDataPreload(
            chapter,
            path,
            pageUrls[i],
            isLocaleList[i],
            archiveImages[i],
            i,
            GetChapterPagesModel(
              path: path,
              pageUrls: pageUrls,
              isLocaleList: isLocaleList,
              archiveImages: archiveImages,
              uChapDataPreload: uChapDataPreloadp,
            ),
            i,
          ),
        );
      }
    }

    AppLogger.log(
      '[$chLabel] getChapterPages DONE  pages=${pageUrls.length}  '
      'localArchive=$isLocalArchive',
      logLevel: LogLevel.info,
      tag: LogTag.page,
    );

    keepAlive.close();
    return GetChapterPagesModel(
      path: path,
      pageUrls: pageUrls,
      isLocaleList: isLocaleList,
      archiveImages: archiveImages,
      uChapDataPreload: uChapDataPreloadp,
    );
  } catch (e, st) {
    keepAlive.close();
    AppLogger.log(
      '[$chLabel] getChapterPages FAILED  source=$srcLabel: $e',
      logLevel: LogLevel.error,
      tag: LogTag.page,
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
