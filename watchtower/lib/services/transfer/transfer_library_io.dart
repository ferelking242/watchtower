// Native implementation — requires dart:io + Isar.
// Compiled only on Android / iOS / desktop (not web).
import 'dart:io';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';

import 'transfer_models.dart';

class LibraryEntry {
  final String name;
  final String? imageUrl;
  final TransferItemType itemType;
  final List<LibraryChapter> chapters;
  const LibraryEntry({
    required this.name,
    this.imageUrl,
    required this.itemType,
    required this.chapters,
  });
}

class LibraryChapter {
  final String id;
  final String name;
  final String localPath;
  final int size;
  final TransferItemType type;
  const LibraryChapter({
    required this.id,
    required this.name,
    required this.localPath,
    required this.size,
    required this.type,
  });

  TransferFile toTransferFile() => TransferFile(
        id: id,
        name: name,
        size: size,
        type: type,
        localPath: localPath,
      );
}

TransferItemType _itemTypeFor(ItemType mangaType, String path) {
  if (mangaType == ItemType.anime) return TransferItemType.anime;
  if (mangaType == ItemType.novel) return TransferItemType.novel;
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if ({'mp4', 'mkv', 'avi', 'webm', 'm4v', 'mov'}.contains(ext)) {
    return TransferItemType.anime;
  }
  return TransferItemType.manga;
}

Future<List<LibraryEntry>> loadLibraryDownloads() async {
  try {
    final downloads =
        await isar.downloads.filter().isDownloadEqualTo(true).findAll();
    if (downloads.isEmpty) return const [];

    await Future.wait(downloads.map((d) => d.chapter.load()));

    final Map<int, List<Chapter>> byManga = {};
    for (final d in downloads) {
      final ch = d.chapter.value;
      if (ch == null || ch.mangaId == null) continue;
      final path = ch.archivePath;
      if (path == null || path.isEmpty) continue;
      if (!File(path).existsSync()) continue;
      byManga.putIfAbsent(ch.mangaId!, () => []).add(ch);
    }
    if (byManga.isEmpty) return const [];

    final mangaIds = byManga.keys.toList();
    final mangas = await isar.mangas.getAll(mangaIds);

    final rng = Random();
    final entries = <LibraryEntry>[];
    for (int i = 0; i < mangaIds.length; i++) {
      final manga = mangas[i];
      if (manga == null) continue;
      final chapters = byManga[mangaIds[i]]!
        ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      final libChapters = chapters.map((ch) {
        final path = ch.archivePath!;
        final type = _itemTypeFor(manga.itemType, path);
        final size = File(path).statSync().size;
        return LibraryChapter(
          id: List.generate(
              12, (_) => rng.nextInt(16).toRadixString(16)).join(),
          name: ch.name ?? p.basename(path),
          localPath: path,
          size: size,
          type: type,
        );
      }).toList();

      final entryType = switch (manga.itemType) {
        ItemType.anime => TransferItemType.anime,
        ItemType.novel => TransferItemType.novel,
        _ => TransferItemType.manga,
      };

      entries.add(LibraryEntry(
        name: manga.name ?? '—',
        imageUrl: manga.imageUrl,
        itemType: entryType,
        chapters: libChapters,
      ));
    }
    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  } catch (_) {
    return const [];
  }
}
