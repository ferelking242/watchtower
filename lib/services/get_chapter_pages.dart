import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
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
    '[$chLabel] getChapterPages START  source=$srcLabel  url=${chapter.url ?? "n/a"}',
    logLevel: LogLevel.info,
    tag: LogTag.page,
  );

  try {
    List<UChapDataPreload> uChapDataPreloadp = [];
    Directory? path;
    List<PageUrl> pageUrls = [];
    List<bool> isLocaleList = [];
    final settings = isar.settings.getSync(kSettingsId);
    List<ChapterPageurls>? chapterPageUrlsList =
        settings!.chapterPageUrlsList ?? [];
    final isarPageUrls = chapterPageUrlsList
        .where((element) => element.chapterId == chapter.id)
        .firstOrNull;
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
          (isarPageUrls?.chapterUrl ?? chapter.url) == chapter.url) {
        AppLogger.log(
          '[$chLabel] getChapterPages CACHE HIT  '
          '${isarPageUrls!.urls!.length} URLs from Isar (no extension call needed)',
          logLevel: LogLevel.debug,
          tag: LogTag.page,
        );
        for (var i = 0; i < isarPageUrls.urls!.length; i++) {
          Map<String, String>? headers;
          if (isarPageUrls.headers?.isNotEmpty ?? false) {
            headers = (jsonDecode(isarPageUrls.headers![i]) as Map?)
                ?.toMapStringString;
          }
          pageUrls.add(PageUrl(isarPageUrls.urls![i], headers: headers));
        }
      } else {
        // ── Cache miss → call extension ─────────────────────────────────
        AppLogger.log(
          '[$chLabel] getChapterPages CACHE MISS  '
          'calling extension getPageList  source=$srcLabel  url=${chapter.url}',
          logLevel: LogLevel.info,
          tag: LogTag.page,
        );
        final sw = Stopwatch()..start();
        pageUrls = await getIsolateService.get<List<PageUrl>>(
          url: chapter.url!,
          source: source,
          serviceType: 'getPageList',
          proxyServer: ref.read(androidProxyServerStateProvider),
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
            'url[0]=${pageUrls.first.url.length > 90 ? pageUrls.first.url.substring(0, 90) : pageUrls.first.url}',
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

    if (pageUrls.isNotEmpty || isLocalArchive) {
      if (await File(
            p.join(mangaDirectory!.path, "${chapter.name}.cbz"),
          ).exists() ||
          isLocalArchive) {
        final path = isLocalArchive
            ? chapter.archivePath
            : p.join(mangaDirectory.path, "${chapter.name}.cbz");
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
      if (!incognitoMode) {
        List<ChapterPageurls>? chapterPageUrls = [];
        for (var chapterPageUrl in settings.chapterPageUrlsList ?? []) {
          if (chapterPageUrl.chapterId != chapter.id) {
            chapterPageUrls.add(chapterPageUrl);
          }
        }
        final chapterPageHeaders = pageUrls
            .map((e) => e.headers == null ? null : jsonEncode(e.headers))
            .toList();
        chapterPageUrls.add(
          ChapterPageurls()
            ..chapterId = chapter.id
            ..urls = pageUrls.map((e) => e.url).toList()
            ..chapterUrl = chapter.url
            ..headers = chapterPageHeaders.first != null
                ? chapterPageHeaders.map((e) => e.toString()).toList()
                : null,
        );
        isar.writeTxnSync(() {
          isar.settings.putSync(
            settings
              ..chapterPageUrlsList = chapterPageUrls
              ..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
        });
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
