import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Result of [reindexDownloads].
class ReindexResult {
  const ReindexResult({required this.fixed, required this.total});

  final int fixed;
  final int total;
}

/// Scans every `Download` record and marks the ones whose file already exists
/// on disk as complete. Same behaviour as the Advanced settings action, shared
/// so the library three-dots menu can expose it too.
Future<ReindexResult> reindexDownloads() async {
  final storageProvider = StorageProvider();
  int fixed = 0;
  final downloads = await isar.downloads.where().findAll();

  for (final dl in downloads) {
    if (dl.isDownload == true) continue;
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) continue;
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null) continue;

    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    if (mangaDir == null) continue;

    bool fileFound = false;
    int sizeKb = 0;
    final chapterName = (chapter.name ?? '')
        .replaceForbiddenCharacters(' ')
        .truncateToBytes(kMaxDownloadNameBytes);

    if (manga.itemType == ItemType.anime) {
      final candidates = {
        animeMp4BaseName(
          chapterName: chapter.name,
          chapterId: chapter.id,
          quality: dl.quality,
        ),
        chapterName,
      };
      for (final base in candidates) {
        final mp4 = File(p.join(mangaDir.path, '$base.mp4'));
        if (mp4.existsSync()) {
          fileFound = true;
          sizeKb = (mp4.lengthSync() / 1024).ceil();
          break;
        }
      }
    } else if (manga.itemType == ItemType.manga) {
      final chapterDir = await storageProvider.getMangaChapterDirectory(
        chapter,
        mangaMainDirectory: mangaDir,
      );
      if (chapterDir != null && chapterDir.existsSync()) {
        final imgs = chapterDir
            .listSync()
            .where((f) => f.path.endsWith('.jpg'))
            .toList();
        if (imgs.isNotEmpty) {
          fileFound = true;
          sizeKb = imgs.length;
        }
      }
      final cbz = File(p.join(mangaDir.path, '${chapter.name}.cbz'));
      if (!fileFound && cbz.existsSync()) {
        fileFound = true;
        sizeKb = (cbz.lengthSync() / 1024).ceil();
      }
    } else if (manga.itemType == ItemType.novel) {
      final html = File(p.join(mangaDir.path, '${chapter.name}.html'));
      if (html.existsSync()) {
        fileFound = true;
        sizeKb = (html.lengthSync() / 1024).ceil();
      }
    }

    if (fileFound) {
      await isar.writeTxn(() async {
        final record = await isar.downloads.get(dl.id!);
        if (record != null && record.isDownload != true) {
          record
            ..isDownload = true
            ..isStartDownload = false
            ..failed = 0;
          if (sizeKb > 0) {
            record.succeeded = sizeKb;
            record.total = sizeKb;
          }
          await isar.downloads.put(record);
        }
      });
      fixed++;
    }
  }
  return ReindexResult(fixed: fixed, total: downloads.length);
}

/// Adds to the library every series that has a fully-downloaded chapter but is
/// not yet a favourite. Returns the number of series added.
Future<int> addDownloadedToLibrary() async {
  final downloads = (await isar.downloads.where().findAll())
      .where((download) => download.isDownload == true)
      .toList();

  int added = 0;
  for (final dl in downloads) {
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) continue;
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null || manga.id == null || manga.favorite == true) {
      continue;
    }

    await isar.writeTxn(() async {
      final m = await isar.mangas.get(manga.id!);
      if (m != null && m.favorite != true) {
        m.favorite = true;
        await isar.mangas.put(m);
        added++;
      }
    });
  }
  return added;
}

/// Removes `Download` records whose backing file is gone from disk, so the
/// download manager and library badges stop counting ghost entries. Returns the
/// number of records purged.
Future<int> purgeMissingDownloads() async {
  final storageProvider = StorageProvider();
  int purged = 0;
  final downloads = (await isar.downloads.where().findAll())
      .where((dl) => dl.isDownload == true)
      .toList();

  for (final dl in downloads) {
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) continue;
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null) continue;

    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    if (mangaDir == null) continue;

    final chapterName = (chapter.name ?? '')
        .replaceForbiddenCharacters(' ')
        .truncateToBytes(kMaxDownloadNameBytes);
    bool fileFound = false;

    if (manga.itemType == ItemType.manga) {
      final chapterDir = await storageProvider.getMangaChapterDirectory(
        chapter,
        mangaMainDirectory: mangaDir,
      );
      if (chapterDir != null && chapterDir.existsSync()) {
        fileFound = chapterDir.listSync().any((f) => f.path.endsWith('.jpg'));
      }
      if (!fileFound) {
        fileFound = File(p.join(mangaDir.path, '${chapter.name}.cbz'))
            .existsSync();
      }
    } else if (manga.itemType == ItemType.anime) {
      final candidates = {
        animeMp4BaseName(
          chapterName: chapter.name,
          chapterId: chapter.id,
          quality: dl.quality,
        ),
        chapterName,
      };
      fileFound = candidates.any(
        (base) => File(p.join(mangaDir.path, '$base.mp4')).existsSync(),
      );
    } else {
      fileFound = File(p.join(mangaDir.path, '${chapter.name}.html'))
          .existsSync();
    }

    if (!fileFound) {
      await isar.writeTxn(() => isar.downloads.delete(dl.id!));
      purged++;
    }
  }
  return purged;
}

/// Localised toast text for [reindexDownloads].
String reindexToastMessage(AppLocalizations l10n, ReindexResult result) =>
    l10n.settings_reindex_done('${result.fixed}', '${result.total}');

/// Localised toast text for [addDownloadedToLibrary].
String addDownloadedToastMessage(AppLocalizations l10n, int added) =>
    l10n.settings_added_to_library('$added');

/// Localised toast text for [purgeMissingDownloads].
String purgeMissingToastMessage(AppLocalizations l10n, int purged) =>
    l10n.settings_purged_downloads('$purged');
