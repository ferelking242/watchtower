import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path/path.dart' as p;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/partial/hls_segment_manifest.dart';
import 'package:watchtower/services/download_manager/partial/partial_playback_plan.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';

/// A partially-downloaded episode that can be played on its real timeline.
class PartialPlaybackMedia {
  /// Local `.m3u8` playlist that plays only the fragments present on disk.
  final String playlistPath;

  /// Mapping between the compressed (available-only) stream and the real
  /// timeline.
  final PartialPlaybackPlan plan;

  /// Working directory that holds the fragments and the playlist.
  final String workDir;

  /// Merged `.mp4` path that will exist once the download finishes. Used to
  /// detect that the episode became complete while it was being played.
  final String mergedFilePath;

  const PartialPlaybackMedia({
    required this.playlistPath,
    required this.plan,
    required this.workDir,
    required this.mergedFilePath,
  });
}

/// Resolves a download into a playable partial media, or null when there is
/// nothing to play partially.
///
/// A complete download (or one whose merged file already exists) resolves to
/// null: the caller plays the merged `.mp4` through the normal local-file path.
class PartialPlaybackResolver {
  PartialPlaybackResolver({StorageProvider? storageProvider})
    : _storage = storageProvider ?? StorageProvider();

  final StorageProvider _storage;

  /// Playlist written into the working directory and opened by the player.
  static const String playlistFileName = 'partial.m3u8';

  Future<PartialPlaybackMedia?> resolve(
    Download download, {
    Chapter? chapter,
  }) async {
    if (download.isDownload == true) return null;
    final resolvedChapter = chapter ?? _resolveChapter(download);
    final manga = _resolveManga(resolvedChapter);
    if (resolvedChapter == null || manga == null) return null;
    if (manga.itemType != ItemType.anime) return null;

    final mainDir = await _storage.getMangaMainDirectory(resolvedChapter);
    if (mainDir == null) return null;
    final mergedPath = p.join(mainDir.path, '${_chapterName(resolvedChapter, download)}.mp4');
    if (await File(mergedPath).exists()) return null;

    final chapterDir = await _storage.getMangaChapterDirectory(
      resolvedChapter,
      mangaMainDirectory: mainDir,
    );
    if (chapterDir == null) return null;
    final tempDir = p.join(chapterDir.path, 'temp');

    final manifest = await HlsSegmentManifest.read(tempDir);
    if (manifest == null || manifest.segments.isEmpty) return null;

    final available = await scanAvailability(tempDir, manifest);

    final plan = buildPartialPlaybackPlan(
      segments: manifest.segments,
      available: available,
    );
    if (!plan.hasPlayableContent) return null;
    if (plan.isComplete) return null;

    String? initSegmentFileName;
    final initName = manifest.initSegmentName;
    if (initName != null && initName.isNotEmpty) {
      if (await _isSegmentReady(tempDir, initName.replaceAll('.ts', ''))) {
        initSegmentFileName = initName;
      }
    }

    final playlistPath = p.join(tempDir, playlistFileName);
    try {
      await File(playlistPath).writeAsString(
        buildPartialPlaylistText(
          plan: plan,
          initSegmentFileName: initSegmentFileName,
        ),
      );
    } catch (_) {
      return null;
    }

    return PartialPlaybackMedia(
      playlistPath: playlistPath,
      plan: plan,
      workDir: tempDir,
      mergedFilePath: mergedPath,
    );
  }

  /// A fragment counts as present only when its final file is non-empty and the
  /// `.done` marker exists — the same contract the resume logic and the merge
  /// step rely on. A half-written `.part` is never played.
  Future<bool> _isSegmentReady(String tempDir, String name) =>
      isSegmentReadyOnDisk(tempDir, name);

  /// Availability of every fragment, aligned with [manifest.segments].
  static Future<List<bool>> scanAvailability(
    String tempDir,
    HlsSegmentManifest manifest,
  ) async {
    final result = <bool>[];
    for (final segment in manifest.segments) {
      result.add(await isSegmentReadyOnDisk(tempDir, segment.name));
    }
    return result;
  }

  static Future<bool> isSegmentReadyOnDisk(String tempDir, String name) async {
    if (name.isEmpty) return false;
    try {
      final file = File(p.join(tempDir, '$name.ts'));
      if (!await file.exists()) return false;
      if (await file.length() <= 0) return false;
      return await File('${file.path}.done').exists();
    } catch (_) {
      return false;
    }
  }

  /// The chapter linked to [download], tolerating an unloaded or missing Isar
  /// link. Mirrors the player's local-file lookup.
  Chapter? _resolveChapter(Download download) {
    Chapter? chapter = download.chapter.value;
    if (chapter == null && !download.chapter.isLoaded) {
      try {
        download.chapter.loadSync();
        chapter = download.chapter.value;
      } catch (_) {}
    }
    chapter ??= download.id == null ? null : isar.chapters.getSync(download.id!);
    return chapter;
  }

  Manga? _resolveManga(Chapter? chapter) {
    if (chapter == null) return null;
    Manga? manga = chapter.manga.value;
    if (manga == null && !chapter.manga.isLoaded) {
      try {
        chapter.manga.loadSync();
        manga = chapter.manga.value;
      } catch (_) {}
    }
    if (manga == null && chapter.mangaId != null) {
      manga = isar.mangas.getSync(chapter.mangaId!);
    }
    return manga;
  }

  /// Mirrors the name the download provider uses for the merged file:
  /// `<chapter name with spaces> [<quality>p].mp4`.
  String _chapterName(Chapter chapter, Download download) {
    final base = (chapter.name ?? '').replaceForbiddenCharacters(' ');
    final resolution = _qualityDigits(download.quality ?? '');
    final suffix = RegExp(r'^\d{3,4}$').hasMatch(resolution)
        ? ' [${resolution}p]'
        : '';
    return '$base$suffix';
  }

  static String _qualityDigits(String raw) {
    final match = RegExp(r'(\d{3,4})').firstMatch(raw);
    if (match != null) return match.group(1)!;
    return raw.trim().toLowerCase();
  }
}
