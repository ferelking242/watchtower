import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Reports `(done, total)` as a maintenance scan progresses. Optional so the
/// callers that do not show a progress notification (CLI, tests) can ignore it.
typedef MaintenanceProgress = void Function(int done, int total);

/// Result of [reindexDownloads].
class ReindexResult {
  const ReindexResult({required this.fixed, required this.total});

  final int fixed;
  final int total;
}

/// Scans every `Download` record and marks the ones whose file already exists
/// on disk as complete. Same behaviour as the Advanced settings action, shared
/// so the library three-dots menu can expose it too.
Future<ReindexResult> reindexDownloads({
  MaintenanceProgress? onProgress,
}) async {
  final storageProvider = StorageProvider();
  int fixed = 0;
  final downloads = await isar.downloads.where().findAll();
  final total = downloads.length;
  var done = 0;
  onProgress?.call(0, total);

  for (final dl in downloads) {
    done++;
    if (dl.isDownload == true) {
      onProgress?.call(done, total);
      continue;
    }
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) {
      onProgress?.call(done, total);
      continue;
    }
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null) {
      onProgress?.call(done, total);
      continue;
    }

    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    if (mangaDir == null) {
      onProgress?.call(done, total);
      continue;
    }

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
        if (await mp4.exists()) {
          fileFound = true;
          sizeKb = (await mp4.length() / 1024).ceil();
          break;
        }
      }
    } else if (manga.itemType == ItemType.manga) {
      final chapterDir = await storageProvider.getMangaChapterDirectory(
        chapter,
        mangaMainDirectory: mangaDir,
      );
      if (chapterDir != null && await chapterDir.exists()) {
        final imgs = await chapterDir
            .list(followLinks: false)
            .where((f) => f.path.endsWith('.jpg'))
            .toList();
        if (imgs.isNotEmpty) {
          fileFound = true;
          sizeKb = imgs.length;
        }
      }
      final cbz = File(p.join(mangaDir.path, '${chapter.name}.cbz'));
      if (!fileFound && await cbz.exists()) {
        fileFound = true;
        sizeKb = (await cbz.length() / 1024).ceil();
      }
    } else if (manga.itemType == ItemType.novel) {
      final html = File(p.join(mangaDir.path, '${chapter.name}.html'));
      if (await html.exists()) {
        fileFound = true;
        sizeKb = (await html.length() / 1024).ceil();
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
    onProgress?.call(done, total);
  }
  return ReindexResult(fixed: fixed, total: total);
}

/// Files smaller than this are treated as noise (thumbnails, samples, cover
/// art) and skipped by the download-folder import — the same spirit as the
/// Smart Library scanner's size gate.
const _kMinimumImportBytes = 1024 * 1024; // 1 MiB

/// Adds to the library every series that is fully present in the
/// `watchtower/download` folder but is not yet a favourite.
///
/// Two sources feed this folder:
///   * chapters downloaded inside Watchtower, already present as Isar records
///     (those are promoted by flipping `favorite`), and
///   * files dropped there by the sister download extension — `.cbz` comics,
///     `.epub` books and torrented videos — which have **no** Isar record at
///     all, so a record has to be created for the reader to find them.
///
/// Returns the number of series added.
Future<int> addDownloadedToLibrary({MaintenanceProgress? onProgress}) async {
  onProgress?.call(0, 1);
  var added = await _promoteDownloadedRecords();

  // Then import whatever the sister extension left on disk.
  final root = await _downloadRoot();
  if (root == null || !await root.exists()) return added;

  // Files that already back a Download record are Watchtower's own downloads
  // and must not be imported a second time as local entries.
  final tracked = <String>{};
  for (final dl in await isar.downloads.where().findAll()) {
    final path = dl.filePath;
    if (path != null && path.isNotEmpty) tracked.add(p.normalize(path));
  }

  final mediaFiles = (await _collectMediaFiles(
    root,
  )).where((f) => !tracked.contains(p.normalize(f.path))).toList();
  final total = mediaFiles.length;
  onProgress?.call(0, total);

  // Group files by their immediate parent folder: that folder is the series.
  final bySeries = <String, List<File>>{};
  for (final file in mediaFiles) {
    final key = p.dirname(file.path);
    bySeries.putIfAbsent(key, () => []).add(file);
  }

  // Pre-load the library once so the "already there?" check is not a query per
  // series. Match on the on-disk folder link, exactly like the local scanner.
  final existing = await isar.mangas.filter().sourceEqualTo('local').findAll();
  final existingLinks = {for (final m in existing) m.link ?? ''};

  var processed = 0;
  for (final entry in bySeries.entries) {
    final folderPath = entry.key;
    final files = entry.value;
    processed += files.length;
    onProgress?.call(processed, total);

    if (existingLinks.contains(folderPath)) continue;
    final itemType = _classify(files);
    if (itemType == null) continue;

    final title = p.basename(folderPath);
    if (title.isEmpty || title == 'download') continue;

    final now = DateTime.now().millisecondsSinceEpoch;
    final manga = Manga(
      favorite: true,
      source: 'local',
      author: '',
      artist: '',
      genre: [],
      imageUrl: '',
      lang: '',
      link: folderPath,
      name: title,
      status: Status.unknown,
      description: '',
      isLocalArchive: true,
      itemType: itemType,
      dateAdded: now,
      lastUpdate: now,
      sourceId: null,
    );

    try {
      // Sizes are read before the transaction opens: a stat per file inside
      // the write txn keeps it open long enough to block the download queue.
      final sizesKb = <String, String>{};
      for (final file in files) {
        var kb = 0;
        try {
          kb = (await file.length() / 1024).ceil();
        } catch (_) {}
        sizesKb[file.path] = '$kb';
      }
      await isar.writeTxn(() async {
        final id = await isar.mangas.put(manga);
        final chapters = <Chapter>[];
        for (final file in files) {
          chapters.add(
            Chapter(
              mangaId: id,
              name: p.basenameWithoutExtension(file.path),
              url: '',
              archivePath: file.path,
              downloadSize: sizesKb[file.path] ?? '0',
            )..manga.value = manga,
          );
        }
        await isar.chapters.putAll(chapters);
      });
      added++;
    } catch (_) {
      // A single unreadable folder must not abort the whole import.
    }
  }
  return added;
}

/// Promotes every downloaded chapter whose parent series is not yet a
/// favourite. Returns the number of series promoted.
Future<int> _promoteDownloadedRecords() async {
  final downloads = (await isar.downloads.where().findAll())
      .where((download) => download.isDownload == true)
      .toList();

  var added = 0;
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

/// The `watchtower/download` folder, or null when storage is unavailable.
Future<Directory?> _downloadRoot() async {
  final base = await StorageProvider().getDefaultDirectory();
  if (base == null) return null;
  return Directory(p.join(base.path, 'download'));
}

/// Recursively lists media files under [root], skipping anything below the
/// noise-size gate (thumbnails, samples, cover art).
///
/// Asynchronous on purpose: the walk covers the whole download folder, and the
/// blocking version froze the UI for seconds on libraries with thousands of
/// files.
Future<List<File>> _collectMediaFiles(Directory root) async {
  final result = <File>[];
  Future<void> walk(Directory dir, int depth) async {
    if (depth > 4) return;
    final List<FileSystemEntity> children;
    try {
      children = await dir.list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final child in children) {
      if (child is Directory) {
        await walk(child, depth + 1);
      } else if (child is File) {
        final ext = p.extension(child.path).toLowerCase();
        if (!_kImportExtensions.contains(ext)) continue;
        try {
          if (await child.length() < _kMinimumImportBytes) continue;
        } catch (_) {
          continue;
        }
        result.add(child);
      }
    }
  }

  await walk(root, 0);
  return result;
}

final _kImportExtensions = {
  ...DiscoveryStage.mangaArchiveExtensions,
  ...DiscoveryStage.novelExtensions,
  ...DiscoveryStage.videoExtensions,
};

/// Chooses the [ItemType] for a series folder from the files it holds.
/// Video wins over archives, archives over books; mixed folders are rare.
ItemType? _classify(List<File> files) {
  var hasVideo = false;
  var hasArchive = false;
  var hasBook = false;
  for (final file in files) {
    final ext = p.extension(file.path).toLowerCase();
    if (DiscoveryStage.videoExtensions.contains(ext)) {
      hasVideo = true;
    } else if (DiscoveryStage.mangaArchiveExtensions.contains(ext)) {
      hasArchive = true;
    } else if (DiscoveryStage.novelExtensions.contains(ext)) {
      hasBook = true;
    }
  }
  if (hasVideo) return ItemType.anime;
  if (hasArchive) return ItemType.manga;
  if (hasBook) return ItemType.novel;
  return null;
}

/// Removes `Download` records whose backing file is gone from disk, so the
/// download manager and library badges stop counting ghost entries. Returns the
/// number of records purged.
Future<int> purgeMissingDownloads({MaintenanceProgress? onProgress}) async {
  final storageProvider = StorageProvider();
  int purged = 0;
  final downloads = (await isar.downloads.where().findAll())
      .where((dl) => dl.isDownload == true)
      .toList();
  final total = downloads.length;
  var done = 0;
  onProgress?.call(0, total);

  for (final dl in downloads) {
    done++;
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) {
      onProgress?.call(done, total);
      continue;
    }
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null) {
      onProgress?.call(done, total);
      continue;
    }

    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    if (mangaDir == null) {
      onProgress?.call(done, total);
      continue;
    }

    final chapterName = (chapter.name ?? '')
        .replaceForbiddenCharacters(' ')
        .truncateToBytes(kMaxDownloadNameBytes);
    bool fileFound = false;

    if (manga.itemType == ItemType.manga) {
      final chapterDir = await storageProvider.getMangaChapterDirectory(
        chapter,
        mangaMainDirectory: mangaDir,
      );
      if (chapterDir != null && await chapterDir.exists()) {
        fileFound = await chapterDir
            .list(followLinks: false)
            .any((f) => f.path.endsWith('.jpg'));
      }
      if (!fileFound) {
        fileFound = await File(
          p.join(mangaDir.path, '${chapter.name}.cbz'),
        ).exists();
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
      fileFound = false;
      for (final base in candidates) {
        if (await File(p.join(mangaDir.path, '$base.mp4')).exists()) {
          fileFound = true;
          break;
        }
      }
    } else {
      fileFound = await File(
        p.join(mangaDir.path, '${chapter.name}.html'),
      ).exists();
    }

    if (!fileFound) {
      await isar.writeTxn(() => isar.downloads.delete(dl.id!));
      purged++;
    }
    onProgress?.call(done, total);
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
