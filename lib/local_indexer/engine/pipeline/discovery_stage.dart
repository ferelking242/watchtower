import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:path/path.dart' as p;

/// Étape 1 du pipeline : Découverte des fichiers sur le disque.
///
/// Parcourt récursivement les dossiers racines et émet les chemins de fichiers
/// média reconnus dans un [Stream].
///
/// Principes :
///   - Ne jamais ouvrir un fichier — seul le nom suffit à ce stade.
///   - Émettre par lot ([batchSize]) pour limiter la pression mémoire.
///   - Respecte les liens symboliques selon [followLinks].
///   - Filtre sur les extensions autorisées uniquement.
class DiscoveryStage {
  // ── Extensions supportées ──────────────────────────────────────────────────
  static const _videoExts = {
    '.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.mpg', '.ts',
    '.m2ts', '.mts', '.m4v', '.webm', '.3gp',
  };
  static const _mangaExts = {'.cbz', '.cbr', '.cbt', '.cb7', '.zip'};
  static const _novelExts = {'.epub', '.mobi', '.azw3', '.fb2'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif'};

  static const _allExts = {
    ..._videoExts,
    ..._mangaExts,
    ..._novelExts,
    ..._imageExts,
  };

  final int batchSize;
  final bool followLinks;
  final bool includeImages; // désactivé par défaut pour éviter les photos
  final ScanPolicy policy;

  const DiscoveryStage({
    this.batchSize = 500,
    this.followLinks = false,
    this.includeImages = false,
    this.policy = const ScanPolicy(),
  });

  /// Démarre la découverte dans [roots] et retourne un Stream de batches.
  ///
  /// Chaque élément du stream est une liste de [DiscoveredFile].
  Stream<List<DiscoveredFile>> discover(
    List<String> roots, {
    Iterable<DiscoveredFile> additionalFiles = const [],
  }) async* {
    final allowed = includeImages
        ? policy.allowedExtensions
        : policy.allowedExtensions.difference(_imageExts);
    final batch = <DiscoveredFile>[];
    final seen = <String>{};

    // Android MediaStore can provide the same file as the filesystem walk.
    // De-duplicate before the expensive analysis stage.
    for (final file in additionalFiles) {
      if (!allowed.contains(file.extension) ||
          file.size < policy.minimumFileSize ||
          !seen.add(file.path)) {
        continue;
      }
      batch.add(file);
      if (batch.length >= batchSize) {
        yield List.unmodifiable(batch);
        batch.clear();
      }
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: followLinks,
        )) {
          if (entity is! File) continue;

          if (_isInExcludedDir(entity.path)) continue;
          if (policy.maximumDepth != null &&
              _relativeDepth(entity.path, root) > policy.maximumDepth!) {
            continue;
          }

          final ext = p.extension(entity.path).toLowerCase();
          if (!allowed.contains(ext)) continue;

          // Lire seulement la stat (taille + mtime), jamais le contenu
          FileStat stat;
          try {
            stat = entity.statSync();
          } catch (_) {
            // A single inaccessible file must not abort the whole library scan.
            continue;
          }
          if (stat.size < policy.minimumFileSize || !seen.add(entity.path)) {
            continue;
          }

          batch.add(DiscoveredFile(
            path: entity.path,
            size: stat.size,
            modifiedAt: stat.modified.millisecondsSinceEpoch,
            extension: ext,
          ));

          if (batch.length >= batchSize) {
            yield List.unmodifiable(batch);
            batch.clear();
          }
        }
      } on FileSystemException {
        // Scoped storage may expose a MediaStore entry while denying a
        // recursive filesystem walk. Continue with the other roots and with
        // the files already supplied by MediaStore.
      }
    }

    if (batch.isNotEmpty) yield List.unmodifiable(batch);
  }

  /// Vérifie si un chemin contient un dossier exclu.
  bool _isInExcludedDir(String path) {
    final parts = p.split(path);
    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i].toLowerCase();
      if (segment.isEmpty) continue;
      if (segment.startsWith('.') ||
          policy.ignoredDirectories.contains(segment) ||
          (segment == 'android' &&
              i + 1 < parts.length &&
              {'data', 'obb'}.contains(parts[i + 1].toLowerCase()))) {
        return true;
      }
      if (policy.ignoredPatterns.any((pattern) => pattern.hasMatch(segment))) {
        return true;
      }
    }
    return false;
  }

  static int _relativeDepth(String filePath, String root) {
    final fileParts = p.split(p.normalize(filePath));
    final rootParts = p.split(p.normalize(root));
    return (fileParts.length - rootParts.length).clamp(0, 1 << 20);
  }

  /// Catégorie d'un fichier basée uniquement sur son extension.
  static FileCategory categoryOf(String ext) {
    if (_videoExts.contains(ext)) return FileCategory.video;
    if (_mangaExts.contains(ext)) return FileCategory.archive;
    if (_novelExts.contains(ext)) return FileCategory.novel;
    if (_imageExts.contains(ext)) return FileCategory.image;
    return FileCategory.unknown;
  }
}

/// Rules used by Smart Library during fast discovery.
///
/// The defaults intentionally include shared media folders such as DCIM,
/// Downloads and Telegram while skipping caches and private Android data.
class ScanPolicy {
  final Set<String> allowedExtensions;
  final Set<String> ignoredDirectories;
  final List<RegExp> ignoredPatterns;
  final int minimumFileSize;
  final int? maximumDepth;

  const ScanPolicy({
    this.allowedExtensions = const {
      '.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.mpg', '.ts',
      '.m2ts', '.mts', '.m4v', '.webm', '.3gp',
      '.cbz', '.cbr', '.cbt', '.cb7', '.zip',
      '.epub', '.mobi', '.azw3', '.fb2',
      '.jpg', '.jpeg', '.png', '.webp', '.avif',
    },
    this.ignoredDirectories = const {
      '.git',
      '.svn',
      '__pycache__',
      'node_modules',
      '.thumbnails',
      'cache',
      'caches',
      'tmp',
      'temp',
      'lost.dir',
      '.trash',
      'lost+found',
      'system volume information',
    },
    this.ignoredPatterns = const [],
    this.minimumFileSize = 1,
    this.maximumDepth,
  });
}

/// Fichier découvert sur le disque (pas encore analysé).
class DiscoveredFile {
  final String path;
  final int size;
  final int modifiedAt;
  final String extension;

  const DiscoveredFile({
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.extension,
  });

  String get basename => p.basename(path);

  FileCategory get category => DiscoveryStage.categoryOf(extension);
}

enum FileCategory { video, archive, novel, image, unknown }
