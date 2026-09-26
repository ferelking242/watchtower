import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:path/path.dart' as p;

/// The two Smart Library scanners are intentionally disjoint.
enum LocalScanMode { videos, manga }

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
  static const videoExtensions = {
    '.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.mpg', '.ts',
    '.m2ts', '.mts', '.m4v', '.webm', '.3gp',
  };
  static const mangaArchiveExtensions = {
    '.cbz', '.cbr', '.cbt', '.cb7', '.zip',
  };
  static const mangaPageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.avif',
  };
  static const novelExtensions = {'.epub', '.mobi', '.azw3', '.fb2'};

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
    final allowed = (includeImages || policy.includeImages)
        ? policy.allowedExtensions
        : policy.allowedExtensions.difference(mangaPageExtensions);
    final batch = <DiscoveredFile>[];
    final seen = <String>{};
    final seenMangaFolders = <String>{};

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
          if (policy.mode == LocalScanMode.manga &&
              ext == '.zip' &&
              !isLikelyMangaPath(entity.path)) {
            continue;
          }
          if (policy.mode == LocalScanMode.manga &&
              mangaPageExtensions.contains(ext)) {
            final folder = _mangaFolderKey(entity.path);
            if (folder == null || !seenMangaFolders.add(folder)) continue;
          }

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
            analysisName: policy.mode == LocalScanMode.manga &&
                    (mangaPageExtensions.contains(ext) ||
                        mangaArchiveExtensions.contains(ext))
                ? mangaAnalysisName(entity.path)
                : null,
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
    if (videoExtensions.contains(ext)) return FileCategory.video;
    if (mangaArchiveExtensions.contains(ext)) return FileCategory.archive;
    if (novelExtensions.contains(ext)) return FileCategory.novel;
    if (mangaPageExtensions.contains(ext)) return FileCategory.image;
    return FileCategory.unknown;
  }

  static bool isLikelyMangaPath(String path) {
    final parts = p
        .split(path)
        .map((part) => part.toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.any(
      (part) => {
        'manga',
        'manhwa',
        'manhua',
        'comic',
        'comics',
        'scan',
        'scans',
      }.contains(part),
    ) || parts.any(
      (part) => RegExp(
        r'^(?:chapter|chap|ch|volume|vol)[ ._-]?\d+$',
        caseSensitive: false,
      ).hasMatch(part),
    ) || RegExp(
      r'\b(?:chapter|chap|ch|volume|vol)[ ._-]?\d+\b',
      caseSensitive: false,
    ).hasMatch(p.basename(path));
  }

  /// Returns the manga chapter directory for a page file. A single
  /// representative page is indexed per chapter folder so a 200-page folder
  /// does not create 200 library entries.
  static String? _mangaFolderKey(String path) {
    final parts = p.split(path).where((part) => part.isNotEmpty).toList();
    if (parts.length < 3 || !isLikelyMangaPath(path)) return null;
    final chapterPattern = RegExp(
      r'^(?:chapter|chap|ch|volume|vol)[ ._-]?\d+$|^\d{1,4}$',
      caseSensitive: false,
    );
    for (var i = parts.length - 2; i > 0; i--) {
      if (chapterPattern.hasMatch(parts[i])) {
        return p.joinAll(parts.sublist(0, i + 1));
      }
    }
    // A page tree without an explicit chapter number is grouped by its manga
    // directory rather than by each nested "pages" folder.
    final markerIndex = parts.indexWhere(
      (part) => {
        'manga',
        'manhwa',
        'manhua',
        'comic',
        'comics',
        'scan',
        'scans',
      }.contains(part.toLowerCase()),
    );
    if (markerIndex >= 0 && markerIndex + 1 < parts.length - 1) {
      return p.joinAll(parts.sublist(0, markerIndex + 2));
    }
    return p.dirname(path);
  }

  static String mangaAnalysisName(String path) {
    final parts = p.split(path).where((part) => part.isNotEmpty).toList();
    final extension = p.extension(path).toLowerCase();
    final base = p.basenameWithoutExtension(path);
    final chapterPattern = RegExp(
      r'^(?:chapter|chap|ch|volume|vol)[ ._-]?\d+$|^\d{1,4}$',
      caseSensitive: false,
    );
    for (var i = parts.length - 2; i > 0; i--) {
      if (!chapterPattern.hasMatch(parts[i])) continue;
      final ignored = {
        'manga',
        'manhwa',
        'manhua',
        'comic',
        'comics',
        'scan',
        'scans',
      };
      final titleParts = parts
          .sublist(0, i)
          .where((part) => !ignored.contains(part.toLowerCase()))
          .toList();
      final title = titleParts.isEmpty ? parts[i] : titleParts.last;
      return '$title ${parts[i]}.cbz';
    }
    final markerIndex = parts.indexWhere(
      (part) => {
        'manga',
        'manhwa',
        'manhua',
        'comic',
        'comics',
        'scan',
        'scans',
      }.contains(part.toLowerCase()),
    );
    if (markerIndex >= 0 && markerIndex + 1 < parts.length - 1) {
      final title = parts[markerIndex + 1];
      if (!mangaPageExtensions.contains(extension) &&
          chapterPattern.hasMatch(base)) {
        return '$title $base.cbz';
      }
      return '$title.cbz';
    }
    if (mangaPageExtensions.contains(extension)) {
      final parent = p.basename(p.dirname(path));
      return '$parent.cbz';
    }
    return '$base${extension.isEmpty ? '.cbz' : extension}';
  }
}

/// Rules used by Smart Library during fast discovery.
///
/// The defaults intentionally index videos and manga archives only, while
/// skipping caches and private Android data. Other media types can be enabled
/// explicitly by a future scanner that owns those features.
class ScanPolicy {
  final LocalScanMode mode;
  final Set<String> allowedExtensions;
  final Set<String> ignoredDirectories;
  final List<RegExp> ignoredPatterns;
  final int minimumFileSize;
  final int? maximumDepth;
  final bool includeImages;

  const ScanPolicy({
    this.mode = LocalScanMode.videos,
    this.allowedExtensions = DiscoveryStage.videoExtensions,
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
    this.includeImages = false,
  });

  const ScanPolicy.videos({
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
  })  : mode = LocalScanMode.videos,
        allowedExtensions = DiscoveryStage.videoExtensions,
        includeImages = false;

  const ScanPolicy.manga({
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
  })  : mode = LocalScanMode.manga,
        allowedExtensions = const {
          ...DiscoveryStage.mangaArchiveExtensions,
          ...DiscoveryStage.mangaPageExtensions,
        },
        includeImages = true;
}

/// Fichier découvert sur le disque (pas encore analysé).
class DiscoveredFile {
  final String path;
  final int size;
  final int modifiedAt;
  final String extension;
  final String? analysisName;

  const DiscoveredFile({
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.extension,
    this.analysisName,
  });

  String get basename => p.basename(path);

  FileCategory get category => DiscoveryStage.categoryOf(extension);
}

enum FileCategory { video, archive, novel, image, unknown }
