import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/manga/download/providers/convert_to_cbz.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/get_chapter_pages.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/download_manager/m3u8/m3u8_downloader.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/engine_selector.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_engine.dart';
import 'package:watchtower/utils/chapter_recognition.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'download_provider.g.dart';

@riverpod
Future<void> addDownloadToQueue(Ref ref, {required Chapter chapter}) async {
  final download = isar.downloads.getSync(chapter.id!);
  if (download == null) {
    final download = Download(
      id: chapter.id,
      succeeded: 0,
      failed: 0,
      total: 100,
      isDownload: false,
      isStartDownload: true,
    );
    isar.writeTxnSync(() {
      isar.downloads.putSync(download..chapter.value = chapter);
    });
  }
}

@riverpod
Future<void> downloadChapter(
  Ref ref, {
  required Chapter chapter,
  bool? useWifi,
  VoidCallback? callback,
}) async {
  final keepAlive = ref.keepAlive();

  try {
    bool onlyOnWifi = useWifi ?? ref.read(onlyOnWifiStateProvider);
    final connectivity = await Connectivity().checkConnectivity();
    final isOnWifi =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet);
    if (onlyOnWifi && !isOnWifi) {
      botToast(navigatorKey.currentContext!.l10n.downloads_are_limited_to_wifi);
      return;
    }

    final http = MClient.init(
      reqcopyWith: {'useDartHttpClient': true, 'followRedirects': false},
    );

    // ── Per-type connection settings ────────────────────────────────────────
    final mangaConnections = ref.read(mangaConnectionsStateProvider);
    final animeConnections = ref.read(animeConnectionsStateProvider);

    List<PageUrl> pageUrls = [];
    PageUrl? novelPage;
    List<PageUrl> pages = [];
    final StorageProvider storageProvider = StorageProvider();
    await storageProvider.requestPermission();
    final mangaMainDirectory = await storageProvider.getMangaMainDirectory(
      chapter,
    );
    List<Track>? subtitles;
    bool isOk = false;
    final manga = chapter.manga.value!;
    final chapterName = chapter.name!.replaceForbiddenCharacters(' ');
    final itemType = chapter.manga.value!.itemType;
    final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaMainDirectory,
    ))!;
    await storageProvider.createDirectorySafely(chapterDirectory.path);
    Map<String, String> videoHeader = {};
    Map<String, String> htmlHeader = {
      "Priority": "u=0, i",
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    };
    bool hasM3U8File = false;
    bool nonM3U8File = false;
    M3u8Downloader? m3u8Downloader;

    Future<void> processConvert() async {
      if (!ref.read(saveAsCBZArchiveStateProvider)) return;
      try {
        final chapterNumber = ChapterRecognition().parseChapterNumber(
          chapter.manga.value!.name!,
          chapter.name!,
        );
        final comicInfo = ComicInfoData(
          title: chapter.name,
          series: manga.name,
          number: chapterNumber.toString(),
          writer: manga.author,
          penciller: manga.artist,
          summary: manga.description,
          genre: manga.genre?.join(', '),
          translator: chapter.scanlator,
          publishingStatusStr: manga.status.name,
        );
        await ref.read(
          convertToCBZProvider(
            chapterDirectory.path,
            mangaMainDirectory!.path,
            chapter.name!,
            pages.map((e) => e.fileName!).toList(),
            comicInfo: comicInfo,
          ).future,
        );
      } catch (error) {
        botToast("Failed to create CBZ: $error");
      }
    }

    Future<void> setProgress(DownloadProgress progress) async {
      if (progress.isCompleted && itemType == ItemType.manga) {
        await processConvert();
      }
      final download = isar.downloads.getSync(chapter.id!);
      if (download == null) {
        final download = Download(
          id: chapter.id,
          succeeded: progress.completed == 0
              ? 0
              : (progress.completed / progress.total * 100).toInt(),
          failed: 0,
          total: 100,
          isDownload: progress.isCompleted,
          isStartDownload: true,
        );
        isar.writeTxnSync(() {
          isar.downloads.putSync(download..chapter.value = chapter);
        });
      } else {
        final download = isar.downloads.getSync(chapter.id!);
        if (download != null && progress.total != 0) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(
              download
                ..succeeded = progress.completed == 0
                    ? 0
                    : (progress.completed / progress.total * 100).toInt()
                ..total = 100
                ..failed = 0
                ..isDownload = progress.isCompleted,
            );
          });
        }
      }
    }

    setProgress(DownloadProgress(0, 0, itemType));

    void savePageUrls() {
      final settings = isar.settings.getSync(227)!;
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
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings
            ..chapterPageUrlsList = chapterPageUrls
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    String? fetchError;

    if (itemType == ItemType.manga) {
      ref
          .read(getChapterPagesProvider(chapter: chapter).future)
          .then((value) {
            if (value.pageUrls.isNotEmpty) {
              pageUrls = value.pageUrls;
              isOk = true;
            } else {
              fetchError = 'getChapterPages returned empty list';
              isOk = true;
            }
          })
          .catchError((e, st) {
            fetchError = e.toString();
            isOk = true;
            log('[downloadChapter][manga] getChapterPages error: $e', error: e, stackTrace: st);
          });
    } else if (itemType == ItemType.anime) {
      ref.read(getVideoListProvider(episode: chapter).future).then((
        value,
      ) async {
        final m3u8Urls = value.$1
            .where(
              (element) =>
                  element.originalUrl.endsWith(".m3u8") ||
                  element.originalUrl.endsWith(".m3u"),
            )
            .toList();
        final nonM3u8Urls = value.$1
            .where((element) => element.originalUrl.isMediaVideo())
            .toList();
        nonM3U8File = nonM3u8Urls.isNotEmpty;
        hasM3U8File = nonM3U8File ? false : m3u8Urls.isNotEmpty;
        final videosUrls = nonM3U8File ? nonM3u8Urls : m3u8Urls;
        if (videosUrls.isNotEmpty) {
          subtitles = videosUrls.first.subtitles;

          final videoUri = Uri.tryParse(videosUrls.first.originalUrl);
          final referer = videoUri != null
              ? '${videoUri.scheme}://${videoUri.host}'
              : null;

          if (hasM3U8File) {
            m3u8Downloader = M3u8Downloader(
              m3u8Url: videosUrls.first.url,
              downloadDir: chapterDirectory.path,
              headers: videosUrls.first.headers ?? {},
              subtitles: subtitles,
              fileName: p.join(mangaMainDirectory!.path, "$chapterName.mp4"),
              chapter: chapter,
              refererUrl: referer,
              concurrentDownloads: animeConnections,
            );
          } else {
            pageUrls = [PageUrl(videosUrls.first.url)];
          }
          videoHeader.addAll(videosUrls.first.headers ?? {});
          isOk = true;
        } else {
          fetchError = 'getVideoList returned no playable URLs';
          isOk = true;
        }
      }).catchError((e, st) {
        fetchError = e.toString();
        isOk = true;
        log('[downloadChapter][anime] getVideoList error: $e', error: e, stackTrace: st);
      });
    } else if (itemType == ItemType.novel && chapter.url != null) {
      final manga = chapter.manga.value!;
      final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
      final chapterUrl = "${source.baseUrl}${chapter.url!.getUrlWithoutDomain}";
      final cookie = MClient.getCookiesPref(chapterUrl);
      final headers = htmlHeader;
      if (cookie.isNotEmpty) {
        final userAgent = isar.settings.getSync(227)!.userAgent!;
        headers.addAll(cookie);
        headers[HttpHeaders.userAgentHeader] = userAgent;
      }
      final res = await http.get(Uri.parse(chapterUrl), headers: headers);
      if (res.headers.containsKey("Location")) {
        novelPage = PageUrl(res.headers["Location"]!);
      } else {
        novelPage = PageUrl(chapterUrl);
      }
      isOk = true;
    }

    // Wait for async fetch (manga/anime) with a hard 90-second timeout so
    // downloads never hang at 0% indefinitely.
    const maxWaitTicks = 90;
    var waitTicks = 0;
    await Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (isOk == true) return false;
      waitTicks++;
      if (waitTicks >= maxWaitTicks) {
        fetchError = 'Fetch timed out after ${maxWaitTicks}s — source returned no data';
        log('[downloadChapter] timeout after ${maxWaitTicks}s for chapterId=${chapter.id}');
        isOk = true;
        return false;
      }
      return true;
    });

    // If the fetch failed (exception, empty result, or timeout), mark failed and abort.
    if (fetchError != null) {
      log('[downloadChapter] aborting — fetch error: $fetchError');
      await isar.writeTxn(() async {
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.downloads.putSync(
            dl
              ..failed = (dl.failed ?? 0) + 1
              ..isDownload = false,
          );
        }
      });
      return;
    }

    log('[downloadChapter] itemType=$itemType chapterId=${chapter.id} chapterName=$chapterName');
    log('[downloadChapter] pageUrls=${pageUrls.length} novelPage=$novelPage hasM3U8=$hasM3U8File nonM3U8=$nonM3U8File');

    if (pageUrls.isNotEmpty) {
      bool cbzFileExist =
          await File(
            p.join(mangaMainDirectory!.path, "${chapter.name}.cbz"),
          ).exists() &&
          ref.read(saveAsCBZArchiveStateProvider);
      bool mp4FileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.mp4"),
      ).exists();
      bool htmlFileExist = await File(
        p.join(mangaMainDirectory.path, "$chapterName.html"),
      ).exists();
      if (!cbzFileExist && itemType == ItemType.manga ||
          !mp4FileExist && itemType == ItemType.anime ||
          !htmlFileExist && itemType == ItemType.novel) {
        final mainDirectory = (await storageProvider.getDirectory())!;
        storageProvider.createDirectorySafely(mainDirectory.path);
        for (var index = 0; index < pageUrls.length; index++) {
          if (Platform.isAndroid) {
            if (!(await File(
              p.join(mainDirectory.path, ".nomedia"),
            ).exists())) {
              await File(p.join(mainDirectory.path, ".nomedia")).create();
            }
          }
          final page = pageUrls[index];
          final cookie = MClient.getCookiesPref(page.url);
          final headers = itemType == ItemType.manga
              ? ref.read(
                  headersProvider(
                    source: manga.source!,
                    lang: manga.lang!,
                    sourceId: manga.sourceId,
                  ),
                )
              : itemType == ItemType.anime
              ? videoHeader
              : htmlHeader;
          if (cookie.isNotEmpty) {
            final userAgent = isar.settings.getSync(227)!.userAgent!;
            headers.addAll(cookie);
            headers[HttpHeaders.userAgentHeader] = userAgent;
          }
          Map<String, String> pageHeaders = headers;
          pageHeaders.addAll(page.headers ?? {});

          if (itemType == ItemType.manga) {
            final file = File(
              p.join(chapterDirectory.path, "${padIndex(index)}.jpg"),
            );
            if (!file.existsSync()) {
              pages.add(
                PageUrl(
                  page.url.trim(),
                  headers: pageHeaders,
                  fileName: p.join(
                    chapterDirectory.path,
                    "${padIndex(index)}.jpg",
                  ),
                ),
              );
            }
          } else if (itemType == ItemType.anime) {
            final file = File(
              p.join(mangaMainDirectory.path, "$chapterName.mp4"),
            );
            if (!file.existsSync()) {
              pages.add(
                PageUrl(
                  page.url.trim(),
                  headers: pageHeaders,
                  fileName: p.join(mangaMainDirectory.path, "$chapterName.mp4"),
                ),
              );
            }
          }
        }
      }

      if (pages.isEmpty && pageUrls.isNotEmpty) {
        await processConvert();
        savePageUrls();
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else {
        savePageUrls();

        // Register internal task for pause/cancel support
        final taskId = '${chapter.id}';
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
          ref
              .read(downloadQueueStateProvider.notifier)
              .setEngine(chapter.id!, 'IMG');
        }
        log('[downloadChapter][manga] starting ${pages.length} pages chapterId=${chapter.id}');
        try {
          await MDownloader(
            chapter: chapter,
            pageUrls: pages,
            subtitles: subtitles,
            subDownloadDir: chapterDirectory.path,
            concurrentDownloads: mangaConnections,
          ).download((progress) {
            setProgress(progress);
          });
          log('[downloadChapter][manga] completed chapterId=${chapter.id}');
        } catch (e) {
          log('[downloadChapter][manga] FAILED chapterId=${chapter.id} error=$e');
          rethrow;
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }
      }
    } else if (itemType == ItemType.novel) {
      final file = File(p.join(chapterDirectory.path, "$chapterName.html"));
      log('[downloadChapter][novel] target=${file.path} exists=${file.existsSync()} novelPage=$novelPage');
      if (!file.existsSync() && novelPage != null) {
        final source = getSource(manga.lang!, manga.source!, manga.sourceId)!;
        log('[downloadChapter][novel] calling getHtmlContent url=${chapter.url}');
        try {
          final html = await withExtensionService(
            source,
            ref.read(androidProxyServerStateProvider),
            (service) => service.getHtmlContent(
              chapter.manga.value!.name!,
              chapter.url!,
            ),
          );
          log('[downloadChapter][novel] getHtmlContent returned ${html.length} chars');
          if (html.isNotEmpty) {
            await file.writeAsString(html);
            log('[downloadChapter][novel] HTML saved to ${file.path}');
            await setProgress(
              DownloadProgress(1, 1, itemType, isCompleted: true),
            );
          } else {
            log('[downloadChapter][novel] ERROR: getHtmlContent returned empty string for ${chapter.url}');
            // Mark as failed so the user can retry
            final dl = isar.downloads.getSync(chapter.id!);
            if (dl != null) {
              isar.writeTxnSync(() {
                isar.downloads.putSync(dl..failed = 1);
              });
            }
          }
        } catch (e, st) {
          log('[downloadChapter][novel] EXCEPTION in getHtmlContent: $e\n$st');
          final dl = isar.downloads.getSync(chapter.id!);
          if (dl != null) {
            isar.writeTxnSync(() {
              isar.downloads.putSync(dl..failed = 1);
            });
          }
        }
      } else if (file.existsSync()) {
        log('[downloadChapter][novel] file already exists, marking complete');
        await setProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
      } else {
        log('[downloadChapter][novel] novelPage is null — nothing to download for ${chapter.url}');
        final dl = isar.downloads.getSync(chapter.id!);
        if (dl != null) {
          isar.writeTxnSync(() {
            isar.downloads.putSync(dl..failed = 1);
          });
        }
      }
    } else if (hasM3U8File && m3u8Downloader != null) {
      // ── Engine selection ────────────────────────────────────────────────
      await DownloadSettingsService.instance.load();
      final downloadMode = DownloadSettingsService.instance.animeDownloadMode;
      final videoUrl = m3u8Downloader!.m3u8Url;

      final engine = EngineSelector.select(
        url: videoUrl,
        itemType: itemType,
        mode: downloadMode,
      );

      log('[downloadChapter][anime] engine=${engine.badgeLabel} url=$videoUrl');
      if (chapter.id != null) {
        ref
            .read(downloadQueueStateProvider.notifier)
            .setEngine(chapter.id!, engine.badgeLabel);
      }

      if (engine == SelectedEngine.zeusDl) {
        // ── ZeusDL path ─────────────────────────────────────────────────
        log('[downloadChapter][anime/ZeusDL] starting chapterId=${chapter.id}');
        final zeusEngine = ZeusDlEngine(
          url: videoUrl,
          outputPath: m3u8Downloader!.fileName,
          headers: m3u8Downloader!.headers ?? {},
          itemType: itemType,
          chapterId: '${chapter.id}',
        );

        if (chapter.id != null) {
          ActiveDownloadRegistry.registerEngine(chapter.id!, zeusEngine);
        }

        bool zeusFailed = false;
        try {
          await zeusEngine.start((progress) => setProgress(progress));
          log('[downloadChapter][anime/ZeusDL] completed chapterId=${chapter.id}');
        } catch (e) {
          zeusFailed = true;
          log('[downloadChapter][anime/ZeusDL] FAILED chapterId=${chapter.id} error=$e');
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }

        // Fallback to internal HLS if ZeusDL failed and mode allows it
        if (zeusFailed && downloadMode != DownloadMode.zeusDl) {
          log('[downloadChapter][anime/ZeusDL→HLS] falling back to internal HLS chapterId=${chapter.id}');
          if (chapter.id != null) {
            ref
                .read(downloadQueueStateProvider.notifier)
                .setEngine(chapter.id!, 'HLS');
          }
          final taskId = 'm3u8_${chapter.id}';
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
          }
          try {
            await m3u8Downloader!.download(
              (progress) => setProgress(progress),
            );
          } finally {
            if (chapter.id != null) {
              ActiveDownloadRegistry.unregister(chapter.id!);
            }
          }
        }
      } else {
        // ── Internal HLS path ───────────────────────────────────────────
        log('[downloadChapter][anime/HLS] starting chapterId=${chapter.id}');
        final taskId = 'm3u8_${chapter.id}';
        if (chapter.id != null) {
          ActiveDownloadRegistry.registerInternal(chapter.id!, taskId);
        }

        Object? caughtError;
        try {
          await m3u8Downloader!.download((progress) => setProgress(progress));
          log('[downloadChapter][anime/HLS] completed chapterId=${chapter.id}');
        } catch (e) {
          caughtError = e;
          log('[downloadChapter][anime/HLS] FAILED chapterId=${chapter.id} error=$e');
        } finally {
          if (chapter.id != null) {
            ActiveDownloadRegistry.unregister(chapter.id!);
          }
        }

        // Fallback to ZeusDL on internal failure (legacy — kept for ZeusDL mode)
        if (caughtError != null && false) {
          final zeusEngine = ZeusDlEngine(
            url: videoUrl,
            outputPath: m3u8Downloader!.fileName,
            headers: m3u8Downloader!.headers ?? {},
            itemType: itemType,
            chapterId: '${chapter.id}',
          );
          if (chapter.id != null) {
            ActiveDownloadRegistry.registerEngine(chapter.id!, zeusEngine);
          }
          try {
            await zeusEngine.start((progress) => setProgress(progress));
          } finally {
            if (chapter.id != null) {
              ActiveDownloadRegistry.unregister(chapter.id!);
            }
          }
        } else if (caughtError != null) {
          throw caughtError;
        }
      }
    }

    if (callback != null) {
      callback();
    }
    keepAlive.close();
  } catch (_) {
    keepAlive.close();
  }
}

@riverpod
Future<void> processDownloads(Ref ref, {bool? useWifi}) async {
  final keepAlive = ref.keepAlive();
  try {
    final ongoingDownloads = await isar.downloads
        .filter()
        .idIsNotNull()
        .isDownloadEqualTo(false)
        .isStartDownloadEqualTo(true)
        .findAll();

    // Skip chapters that are currently paused
    final pausedIds = ref.read(downloadQueueStateProvider).pausedIds;
    // Also skip downloads already actively running to avoid double-start / flicker
    final activeDownloads = ongoingDownloads
        .where(
          (d) =>
              d.chapter.value?.id == null ||
              (!pausedIds.contains(d.chapter.value!.id) &&
                  !ActiveDownloadRegistry.isActive(d.chapter.value!.id!)),
        )
        .toList();

    log('[processDownloads] total=${ongoingDownloads.length} paused=${pausedIds.length} toStart=${activeDownloads.length}');

    final maxConcurrentDownloads = ref.read(concurrentDownloadsStateProvider);
    int index = 0;
    int downloaded = 0;
    int current = 0;

    await Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (activeDownloads.length == downloaded) {
        return false;
      }
      if (current < maxConcurrentDownloads &&
          index < activeDownloads.length) {
        current++;
        final downloadItem = activeDownloads[index++];
        final chapter = downloadItem.chapter.value!;
        // Cancel any stale pool task without deleting the Isar record.
        // Using ActiveDownloadRegistry.cancel() avoids the flicker caused by
        // chapter.cancelDownloads() which deletes the record from Isar.
        if (chapter.id != null) {
          await ActiveDownloadRegistry.cancel(chapter.id!);
        }
        log('[processDownloads] starting chapterId=${chapter.id} "${chapter.name}"');
        await Future.delayed(const Duration(milliseconds: 300));
        ref.read(
          downloadChapterProvider(
            chapter: chapter,
            useWifi: useWifi,
            callback: () {
              downloaded++;
              current--;
              log('[processDownloads] done chapterId=${chapter.id} downloaded=$downloaded/${activeDownloads.length}');
            },
          ),
        );
      }
      return true;
    });
    keepAlive.close();
  } catch (_) {
    keepAlive.close();
  }
}
