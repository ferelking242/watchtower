import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/local_indexer/metadata/local_media_metadata.dart';
import 'package:watchtower/local_indexer/models/local_file_cache.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/search/search_engine.dart';

/// A proposed rename for one indexed file.
class LocalRenamePlan {
  final LocalIndexedItem item;
  final String targetPath;
  final String targetName;
  final String? blockedReason;

  const LocalRenamePlan({
    required this.item,
    required this.targetPath,
    required this.targetName,
    this.blockedReason,
  });

  bool get isRenameable => blockedReason == null && targetPath != item.filePath;
}

/// Renames indexed files to the canonical name their metadata implies.
///
/// The library keeps the original paths untouched until the user asks for a
/// rename: [plan] only computes the target name, [apply] performs the move and
/// rewrites the index. Files are renamed *in place* (the directory is never
/// changed), which keeps the operation reversible and avoids moving a whole
/// season or album by accident.
class LocalRenameService {
  LocalRenameService._();

  static final instance = LocalRenameService._();

  static final _illegalPattern = RegExp(r'[<>:"/\\|?*\x00-\x1f]');

  /// Target name for [item] given its resolved [metadata].
  ///
  /// - Movie  : `Title (Year).ext`
  /// - Series : `Title S01E03.ext`
  /// - Anime  : `Title - 012.ext` (absolute episode number)
  /// - Music  : `Artist - Title.ext`
  ///
  /// A title the user locked by hand always wins over the catalogue one.
  LocalRenamePlan plan(LocalIndexedItem item, {LocalMediaMetadata? metadata}) {
    final extension = p.extension(item.filePath);
    final title = _sanitize(metadata?.title ?? item.title);
    if (title.isEmpty) {
      return LocalRenamePlan(
        item: item,
        targetPath: item.filePath,
        targetName: item.rawFilename,
        blockedReason: 'no_title',
      );
    }

    final String base;
    switch (item.kind) {
      case LocalMediaKind.music:
        final artist = _sanitize(item.artist ?? metadata?.artist ?? '');
        base = artist.isEmpty ? title : '$artist - $title';
      case LocalMediaKind.series:
      case LocalMediaKind.anime:
        final season = item.season ?? 1;
        final episode = item.episode;
        if (episode == null) {
          base = title;
        } else if (item.kind == LocalMediaKind.anime) {
          base = '$title - ${episode.toString().padLeft(3, '0')}';
        } else {
          base = '$title S${season.toString().padLeft(2, '0')}'
              'E${episode.toString().padLeft(2, '0')}';
        }
      case LocalMediaKind.movie:
        final year = metadata?.year;
        base = year == null ? title : '$title ($year)';
      case LocalMediaKind.manga:
      case LocalMediaKind.novel:
      case LocalMediaKind.unknown:
        base = title;
    }

    final directory = p.dirname(item.filePath);
    final targetName = '$base$extension';
    return LocalRenamePlan(
      item: item,
      targetPath: p.join(directory, targetName),
      targetName: targetName,
    );
  }

  /// Applies [plan] on disk and updates the index.
  ///
  /// Returns the plan unchanged (with a [LocalRenamePlan.blockedReason]) when
  /// the move is unsafe: the source is gone, the target already belongs to
  /// another file, or the platform refuses the rename.
  Future<LocalRenamePlan> apply(
    LocalRenamePlan plan, {
    required Isar isar,
    required LocalSearchEngine searchEngine,
  }) async {
    if (!plan.isRenameable) return plan;

    final source = File(plan.item.filePath);
    if (!await source.exists()) {
      return _blocked(plan, 'source_missing');
    }
    final target = File(plan.targetPath);
    if (await target.exists() && plan.targetPath != plan.item.filePath) {
      return _blocked(plan, 'target_exists');
    }

    try {
      await source.rename(plan.targetPath);
    } catch (_) {
      return _blocked(plan, 'rename_failed');
    }

    final originalPath = plan.item.filePath;
    final updated = plan.item
      ..filePath = plan.targetPath
      ..rawFilename = plan.targetName;
    await isar.writeTxn(() async {
      await isar.localIndexedItems.put(updated);
      final cache = await isar.localFileCaches
          .where()
          .filePathEqualTo(originalPath)
          .findFirst();
      if (cache != null) {
        cache.filePath = plan.targetPath;
        await isar.localFileCaches.put(cache);
      }
    });
    searchEngine.upsert(updated);
    return plan;
  }

  LocalRenamePlan _blocked(LocalRenamePlan plan, String reason) =>
      LocalRenamePlan(
        item: plan.item,
        targetPath: plan.targetPath,
        targetName: plan.targetName,
        blockedReason: reason,
      );

  /// Strips characters a filesystem rejects and collapses whitespace.
  String _sanitize(String value) => value
      .replaceAll(_illegalPattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[.\s]+$'), '');
}
