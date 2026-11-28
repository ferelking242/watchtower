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
import 'package:watchtower/services/download_series_metadata.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

typedef MaintenanceProgress = void Function(int done, int total);

/// Files smaller than this are treated as noise (thumbnails, samples, cover
/// art) and skipped by the download-folder import.
const _kMinimumImportBytes = 1024 * 1024;

class ReindexResult {
  const ReindexResult({
    required this.fixed,
    required this.total,
    this.removed = 0,
    this.added = 0,
  });

  final int fixed;
  final int total;

  /// Downloaded rows whose file disappeared from disk.
  final int removed;

  /// Files found on disk that had no completed Download row yet.
  final int added;
}

class _FoundFile {
  const _FoundFile(this.path, this.sizeKb, this.seriesDir);
  final String path;
  final int sizeKb;
  final Directory seriesDir;
}

/// Reconciles the Download table with what is actually on disk.
///
/// A row whose file exists becomes complete; a row whose file disappeared is
/// marked incomplete so "downloaded only" stops lying; a chapter with a file
/// but no row gets one. [itemType] limits the scan to the library the user is
/// looking at (Watch stays on Watch, Manga stays on Manga).
Future<ReindexResult> reindexDownloads({
  MaintenanceProgress? onProgress,
  ItemType? itemType,
}) async {
  final storageProvider = StorageProvider();
  final allDownloads = await isar.downloads.where().findAll();
  _loadDownloadLinks(allDownloads);
  final downloads = allDownloads
      .where((download) => _matchesType(download, itemType))
      .toList();
  final total = downloads.length;
  var done = 0;
  var fixed = 0;
  var removed = 0;
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

    final found = await _locateChapterFile(
      chapter,
      manga,
      quality: dl.quality,
      storage: storageProvider,
    );

    if (found != null) {
      if (dl.isDownload != true) fixed++;
      await _repairSeries(manga, dl, found.seriesDir);
      await isar.writeTxn(() async {
        final record = await isar.downloads.get(dl.id!);
        if (record == null) return;
        record
          ..isDownload = true
          ..isStartDownload = false
          ..failed = 0
          ..filePath = found.path;
        if (found.sizeKb > 0) {
          record
            ..succeeded = found.sizeKb
            ..total = found.sizeKb;
        }
        await isar.downloads.put(record);
      });
    } else if (dl.isDownload == true) {
      removed++;
      await isar.writeTxn(() async {
        final record = await isar.downloads.get(dl.id!);
        if (record == null) return;
        record
          ..isDownload = false
          ..isStartDownload = false
          ..filePath = null
          ..status = 'queued';
        await isar.downloads.put(record);
      });
    }
    onProgress?.call(done, total);
  }

  final added = await _discoverFilesWithoutRows(
    itemType,
    storageProvider,
    onProgress,
  );
  return ReindexResult(
    fixed: fixed,
    total: total,
    removed: removed,
    added: added,
  );
}

/// Adds to the library every series present in `watchtower/download` but not
/// yet a favourite. [itemType] keeps a Watch run from importing manga folders.
Future<int> addDownloadedToLibrary({
  MaintenanceProgress? onProgress,
  ItemType? itemType,
}) async {
  onProgress?.call(0, 1);
  var added = await _promoteDownloadedRecords(itemType);

  final root = await _downloadRoot();
  if (root == null || !await root.exists()) return added;

  final tracked = <String>{};
  for (final dl in await isar.downloads.where().findAll()) {
    final path = dl.filePath;
    if (path != null && path.isNotEmpty) tracked.add(p.normalize(path));
  }

  final mediaFiles = (await _collectMediaFiles(root))
      .where((f) => !tracked.contains(p.normalize(f.path)))
      .where((f) => itemType == null || _typeOfFile(f.path) == itemType)
      .toList();
  final total = mediaFiles.length;
  onProgress?.call(0, total);

  final bySeries = <String, List<File>>{};
  for (final file in mediaFiles) {
    bySeries.putIfAbsent(p.dirname(file.path), () => []).add(file);
  }

  final existing = await isar.mangas.filter().sourceEqualTo('local').findAll();
  final existingLinks = {for (final m in existing) m.link ?? ''};

  var processed = 0;
  for (final entry in bySeries.entries) {
    final folderPath = entry.key;
    final files = entry.value;
    processed += files.length;
    onProgress?.call(processed, total);

    if (existingLinks.contains(folderPath)) continue;
    final type = _classify(files);
    if (type == null || (itemType != null && type != itemType)) continue;

    final metadata = await readSeriesMetadata(folderPath);
    final title = (metadata?.name ?? '').trim().isNotEmpty
        ? metadata!.name!.trim()
        : p.basename(folderPath);
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
      itemType: type,
      dateAdded: now,
      lastUpdate: now,
      sourceId: null,
    );
    metadata?.applyTo(manga, keepLink: true);
    if ((manga.imageUrl ?? '').isEmpty) {
      manga.imageUrl = await _posterForFolder(folderPath);
    }

    try {
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
      if (!await File(p.join(folderPath, kSeriesMetadataFile)).exists()) {
        await writeSeriesMetadata(manga, folderPath: folderPath);
      }
    } catch (_) {}
  }
  return added;
}

/// Promotes every downloaded chapter whose parent series is not yet a
/// favourite. Metadata is repaired on the way, so a local rebuild recovers the
/// original extension and cover instead of showing "Local" on a white card.
Future<int> _promoteDownloadedRecords(ItemType? itemType) async {
  final allDownloads = await isar.downloads.where().findAll();
  _loadDownloadLinks(allDownloads);
  final downloads = allDownloads
      .where((download) => download.isDownload == true)
      .where((download) => _matchesType(download, itemType))
      .toList();

  var added = 0;
  for (final dl in downloads) {
    dl.chapter.loadSync();
    final chapter = dl.chapter.value;
    if (chapter == null) continue;
    chapter.manga.loadSync();
    final manga = chapter.manga.value;
    if (manga == null || manga.id == null) continue;

    final found = await _locateChapterFile(chapter, manga, quality: dl.quality);
    if (found != null) {
      await _repairSeries(manga, dl, found.seriesDir);
    } else if ((manga.imageUrl ?? '').isEmpty &&
        (dl.posterUrl ?? '').isNotEmpty) {
      await _setCoverAndMetadata(
        manga,
        dl.posterUrl!,
        folderPath: manga.isLocalArchive == true ? manga.link : null,
      );
    }

    if (manga.favorite == true) continue;
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

/// Finds the file backing [chapter] and the series folder that holds it.
Future<_FoundFile?> _locateChapterFile(
  Chapter chapter,
  Manga manga, {
  String? quality,
  StorageProvider? storage,
}) async {
  final provider = storage ?? StorageProvider();
  Directory? mangaDir;
  final localPath = (manga.link ?? '').trim();
  if (manga.isLocalArchive == true && localPath.isNotEmpty) {
    final localDir = Directory(localPath);
    if (await localDir.exists()) mangaDir = localDir;
  }
  mangaDir ??= await provider.getMangaMainDirectoryFor(manga);
  if (mangaDir == null || !await mangaDir.exists()) return null;
  final chapterName = (chapter.name ?? '')
      .replaceForbiddenCharacters(' ')
      .truncateToBytes(kMaxDownloadNameBytes);

  if (manga.itemType == ItemType.anime) {
    final candidates = {
      animeMp4BaseName(
        chapterName: chapter.name,
        chapterId: chapter.id,
        quality: quality,
      ),
      chapterName,
    }.where((name) => name.trim().isNotEmpty);
    for (final base in candidates) {
      for (final ext in const ['.mp4', '.mkv', '.webm']) {
        final file = File(p.join(mangaDir.path, '$base$ext'));
        if (await file.exists()) {
          return _FoundFile(
            file.path,
            (await file.length() / 1024).ceil(),
            mangaDir,
          );
        }
      }
    }
    // Fallback: a renamed file that still starts with the episode title.
    try {
      await for (final entity in mangaDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!const ['.mp4', '.mkv', '.webm'].contains(ext)) continue;
        final base = p.basenameWithoutExtension(entity.path);
        if (base == chapterName || base.startsWith('$chapterName [')) {
          return _FoundFile(
            entity.path,
            (await entity.length() / 1024).ceil(),
            mangaDir,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  if (manga.itemType == ItemType.manga) {
    final chapterDir = await provider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaDir,
    );
    if (chapterDir != null && await chapterDir.exists()) {
      final images = await chapterDir.list(followLinks: false).where((f) {
        if (f is! File) return false;
        final ext = p.extension(f.path).toLowerCase();
        return const ['.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif']
            .contains(ext);
      }).toList();
      if (images.isNotEmpty) {
        return _FoundFile(chapterDir.path, images.length, mangaDir);
      }
    }
    for (final name in {chapter.name ?? '', chapterName}) {
      if (name.trim().isEmpty) continue;
      final cbz = File(p.join(mangaDir.path, '$name.cbz'));
      if (await cbz.exists()) {
        return _FoundFile(
          cbz.path,
          (await cbz.length() / 1024).ceil(),
          mangaDir,
        );
      }
    }
    return null;
  }

  for (final ext in const ['.html', '.epub', '.txt']) {
    for (final base in {chapter.name ?? '', chapterName}) {
      if (base.trim().isEmpty) continue;
      final file = File(p.join(mangaDir.path, '$base$ext'));
      if (await file.exists()) {
        return _FoundFile(
          file.path,
          (await file.length() / 1024).ceil(),
          mangaDir,
        );
      }
    }
  }
  return null;
}

/// Repairs a series from its sidecar and the download poster.
Future<void> _repairSeries(
  Manga manga,
  Download download,
  Directory seriesDir,
) async {
  final metadata = await readSeriesMetadata(seriesDir.path);
  if (metadata != null) {
    metadata.applyTo(manga, keepLink: manga.isLocalArchive == true);
    if ((manga.imageUrl ?? '').isEmpty &&
        (download.posterUrl ?? '').isNotEmpty) {
      manga.imageUrl = download.posterUrl;
    }
    await isar.writeTxn(() => isar.mangas.put(manga));
    if (!await File(p.join(seriesDir.path, kSeriesMetadataFile)).exists()) {
      await writeSeriesMetadata(manga, folderPath: seriesDir.path);
    }
    return;
  }
  if ((manga.imageUrl ?? '').isEmpty &&
      (download.posterUrl ?? '').isNotEmpty) {
    await _setCoverAndMetadata(
      manga,
      download.posterUrl!,
      folderPath: seriesDir.path,
    );
  } else if (await seriesDir.exists()) {
    await writeSeriesMetadata(manga, folderPath: seriesDir.path);
  }
}

Future<void> _setCoverAndMetadata(
  Manga manga,
  String cover, {
  String? folderPath,
}) async {
  manga.imageUrl = cover;
  await isar.writeTxn(() => isar.mangas.put(manga));
  await writeSeriesMetadata(manga, folderPath: folderPath);
}

/// Creates rows for chapters whose file exists but that have no completed row,
/// so "which chapter was added" is visible after the scan.
Future<int> _discoverFilesWithoutRows(
  ItemType? itemType,
  StorageProvider storage,
  MaintenanceProgress? onProgress,
) async {
  final mangas = itemType == null
      ? await isar.mangas.where().findAll()
      : await isar.mangas.filter().itemTypeEqualTo(itemType).findAll();
  var added = 0;
  var done = 0;
  final total = mangas.length;
  for (final manga in mangas) {
    done++;
    onProgress?.call(done, total);
    if (manga.id == null) continue;
    final chapters = await isar.chapters
        .where()
        .mangaIdEqualTo(manga.id!)
        .findAll();
    if (chapters.isEmpty) continue;
    for (final chapter in chapters) {
      if (chapter.id == null) continue;
      final existing = isar.downloads.getSync(chapter.id!);
      if (existing?.isDownload == true) continue;
      final found = await _locateChapterFile(
        chapter,
        manga,
        quality: existing?.quality,
        storage: storage,
      );
      if (found == null) continue;
      final record =
          existing ??
          Download(
            id: chapter.id,
            succeeded: 0,
            failed: 0,
            total: found.sizeKb,
            isDownload: true,
            isStartDownload: false,
          );
      record
        ..isDownload = true
        ..isStartDownload = false
        ..failed = 0
        ..filePath = found.path
        ..status = 'completed'
        ..title = chapter.name
        ..quality = existing?.quality
        ..posterUrl = existing?.posterUrl ?? chapter.thumbnailUrl ?? manga.imageUrl;
      if (found.sizeKb > 0) {
        record
          ..succeeded = found.sizeKb
          ..total = found.sizeKb;
      }
      await isar.writeTxn(() => isar.downloads.put(record));
      added++;
    }
  }
  return added;
}

/// Fetches the chapter/manga chain once. Isar queries return bare rows, so
/// filtering by type without this loads every relation lazily inside a loop.
void _loadDownloadLinks(Iterable<Download> downloads) {
  for (final download in downloads) {
    try {
      download.chapter.loadSync();
      download.chapter.value?.manga.loadSync();
    } catch (_) {}
  }
}

bool _matchesType(Download download, ItemType? itemType) {
  if (itemType == null) return true;
  final manga = download.chapter.value?.manga.value;
  return manga?.itemType == itemType;
}

Future<Directory?> _downloadRoot() async {
  final base = await StorageProvider().getDefaultDirectory();
  if (base == null) return null;
  return Directory(p.join(base.path, 'download'));
}

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
        if (p.basename(child.path).startsWith('.')) continue;
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

ItemType? _typeOfFile(String path) {
  final ext = p.extension(path).toLowerCase();
  if (DiscoveryStage.videoExtensions.contains(ext)) return ItemType.anime;
  if (DiscoveryStage.mangaArchiveExtensions.contains(ext)) return ItemType.manga;
  if (DiscoveryStage.novelExtensions.contains(ext)) return ItemType.novel;
  return null;
}

ItemType? _classify(List<File> files) {
  for (final file in files) {
    final type = _typeOfFile(file.path);
    if (type != null) return type;
  }
  return null;
}

/// Finds a poster for a folder that has no sidecar by borrowing the poster of
/// one of its Download rows.
Future<String> _posterForFolder(String folderPath) async {
  final normalized = p.normalize(folderPath);
  for (final dl in await isar.downloads.where().findAll()) {
    final path = dl.filePath;
    if (path == null || path.isEmpty) continue;
    if (!p.normalize(path).startsWith(normalized)) continue;
    if ((dl.posterUrl ?? '').isNotEmpty) return dl.posterUrl!;
  }
  return '';
}

/// Removes Download rows whose backing file is gone, limited to [itemType].
Future<int> purgeMissingDownloads({
  MaintenanceProgress? onProgress,
  ItemType? itemType,
}) async {
  final storageProvider = StorageProvider();
  var purged = 0;
  final allDownloads = await isar.downloads.where().findAll();
  _loadDownloadLinks(allDownloads);
  final downloads = allDownloads
      .where((dl) => dl.isDownload == true)
      .where((dl) => _matchesType(dl, itemType))
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
    final found = await _locateChapterFile(
      chapter,
      manga,
      quality: dl.quality,
      storage: storageProvider,
    );
    if (found == null) {
      await isar.writeTxn(() => isar.downloads.delete(dl.id!));
      purged++;
    } else if ((dl.filePath ?? '') != found.path) {
      await isar.writeTxn(() async {
        final record = await isar.downloads.get(dl.id!);
        if (record != null) {
          record.filePath = found.path;
          await isar.downloads.put(record);
        }
      });
    }
    onProgress?.call(done, total);
  }
  return purged;
}

String reindexToastMessage(AppLocalizations l10n, ReindexResult result) {
  final base = l10n.settings_reindex_done('${result.fixed}', '${result.total}');
  final extras = [
    if (result.removed > 0) '-${result.removed}',
    if (result.added > 0) '+${result.added}',
  ];
  return extras.isEmpty ? base : '$base · ${extras.join(' ')}';
}

String addDownloadedToastMessage(AppLocalizations l10n, int added) =>
    l10n.settings_added_to_library('$added');

String purgeMissingToastMessage(AppLocalizations l10n, int purged) =>
    l10n.settings_purged_downloads('$purged');
