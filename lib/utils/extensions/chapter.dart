import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/manga/reader/providers/push_router.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/m_downloader.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:path/path.dart' as p;

extension ChapterExtension on Chapter {
  Future<void> pushToReaderView(
    BuildContext context, {
    bool ignoreIsRead = false,
  }) async {
    if (ignoreIsRead || !isRead!) {
      await pushMangaReaderView(context: context, chapter: this);
    } else {
      final filteredChaps = manga.value!.getFilteredChapterList();
      bool exist = false;
      for (var filteredChap in filteredChaps.reversed) {
        if (filteredChap.toJson().toString() == toJson().toString()) {
          exist = true;
        }
        if (exist && !filteredChap.isRead!) {
          await pushMangaReaderView(context: context, chapter: filteredChap);
          break;
        }
      }
    }
  }

  void cancelDownloads(int? downloadId) {
    // Cancel via the Isolate pool (new system)
    DownloadIsolatePool.instance.cancelTask('$id');
    DownloadIsolatePool.instance.cancelTask('m3u8_$id');

    // Clean the map for compatibility
    isolateChapsSendPorts.remove('$id');

    isar.writeTxnSync(() {
      isar.downloads.deleteSync(id!);
      if (downloadId != null) {
        isar.downloads.deleteSync(downloadId);
      }
    });
  }

  Future<void> deleteDownloadedFiles() async {
    final download = isar.downloads.getSync(id!);
    if (download == null) return;

    await ActiveDownloadRegistry.cancel(download.id ?? id!);
    DownloadIsolatePool.instance.cancelTask('$id');
    DownloadIsolatePool.instance.cancelTask('m3u8_$id');

    final storageProvider = StorageProvider();
    final mangaDir = await storageProvider.getMangaMainDirectory(this);
    final chapterDir = await storageProvider.getMangaChapterDirectory(
      this,
      mangaMainDirectory: mangaDir,
    );

    try {
      final archivePaths = [
        for (final extension in ['.cbz', '.zip', '.cbr', '.cb7'])
          p.join(mangaDir!.path, '$name$extension'),
      ];
      for (final archivePath in archivePaths) {
        final candidatePaths = [archivePath, '$archivePath.part'];
        for (final candidate in candidatePaths) {
          final file = File(candidate);
          if (file.existsSync()) file.deleteSync();
        }
      }
    } catch (_) {}
    try {
      // The MP4 is written as `<name> [360p].mp4`, so the delete path must
      // apply the same quality tag or the file survives the "delete" and keeps
      // occupying storage. Older, untagged files are removed as well.
      final mp4Paths = {
        p.join(
          mangaDir!.path,
          '${animeMp4BaseName(chapterName: name, chapterId: id, quality: download.quality)}.mp4',
        ),
        p.join(
          mangaDir.path,
          '${safeChapterBaseName(chapterName: name, chapterId: id)}.mp4',
        ),
      };
      for (final mp4Path in mp4Paths) {
        for (final candidate in [
          mp4Path,
          '$mp4Path.part',
          '$mp4Path.part.meta',
        ]) {
          final file = File(candidate);
          if (file.existsSync()) file.deleteSync();
        }
      }
    } catch (_) {}
    try {
      final htmlFile = File(p.join(mangaDir!.path, "$name.html"));
      if (htmlFile.existsSync()) htmlFile.deleteSync();
    } catch (_) {}
    final savedPath = download.filePath;
    if (savedPath != null && savedPath.isNotEmpty) {
      for (final path in [savedPath, '$savedPath.part', '$savedPath.part.meta']) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
    try {
      chapterDir?.deleteSync(recursive: true);
    } catch (_) {}

    cancelDownloads(download.id);
  }
}
