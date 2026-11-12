import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path/path.dart' as p;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/media_file_name.dart';
import 'package:watchtower/services/download_manager/partial/hls_segment_manifest.dart';
import 'package:watchtower/services/download_manager/partial/partial_playback_plan.dart';

/// Whether a plan describes an episode worth playing from the fragments on
/// disk.
///
/// Any playable fragment counts — including the case where *every* fragment is
/// present but the merged `.mp4` is missing, which is what a failed merge after
/// a full download leaves behind. The merged file is the only real "done"
/// signal and the caller has already checked for it; a complete-looking plan
/// with no merged file must still play locally instead of hitting the network.
bool shouldBuildPartialPlaylist(PartialPlaybackPlan plan) =>
    plan.hasPlayableContent;

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
    // The merged `.mp4` is the only thing that means "done"; its absence was
    // checked above. When every fragment is present but the merge never
    // produced the file — a merge that failed after the whole episode was
    // fetched (e.g. the >600 MB `File name too long` case) — the fragments are
    // still perfectly playable, so build the playlist for them too instead of
    // falling back to a network source that is usually blocked.
    if (!shouldBuildPartialPlaylist(plan)) return null;

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

  /// Mirrors the name the download provider uses for the merged file
  /// (`animeMp4BaseName`: `<name, truncated to the NAME_MAX budget> [<q>p]`).
  ///
  /// The same helper must be used here, otherwise a long episode title makes
  /// this resolver look for a file the downloader never wrote (it truncated the
  /// name), conclude the merge is missing and rebuild a playlist for an
  /// episode that is actually complete.
  String _chapterName(Chapter chapter, Download download) => animeMp4BaseName(
    chapterName: chapter.name,
    chapterId: chapter.id,
    quality: download.quality,
  );
}
