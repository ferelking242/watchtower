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
    '.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.mpeg', '.ts',
    '.m2ts', '.mts', '.m4v', '.webm',
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

  // Dossiers à ignorer (système, cachés, etc.)
  static const _excludedDirs = {
    '.git', '.svn', '__pycache__', 'node_modules', '.thumbnails',
    'Android', 'DCIM', 'LOST.DIR', '.trash', '.Trash',
    'lost+found', 'System Volume Information',
  };

  final int batchSize;
  final bool followLinks;
  final bool includeImages; // désactivé par défaut pour éviter les photos

  const DiscoveryStage({
    this.batchSize = 500,
    this.followLinks = false,
    this.includeImages = false,
  });

  /// Démarre la découverte dans [roots] et retourne un Stream de batches.
  ///
  /// Chaque élément du stream est une liste de [DiscoveredFile].
  Stream<List<DiscoveredFile>> discover(List<String> roots) async* {
    final allowed = includeImages ? _allExts : _allExts.difference(_imageExts);
    final batch = <DiscoveredFile>[];

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list(
        recursive: true,
        followLinks: followLinks,
      )) {
        if (entity is! File) continue;

        // Ignorer les dossiers système
        if (_isInExcludedDir(entity.path)) continue;

        final ext = p.extension(entity.path).toLowerCase();
        if (!allowed.contains(ext)) continue;

        // Lire seulement la stat (taille + mtime), jamais le contenu
        final stat = entity.statSync();
        if (stat.size == 0) continue; // fichiers vides = ignorer

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
    }

    if (batch.isNotEmpty) yield List.unmodifiable(batch);
  }

  /// Vérifie si un chemin contient un dossier exclu.
  static bool _isInExcludedDir(String path) {
    final parts = p.split(path);
    return parts.any((seg) => _excludedDirs.contains(seg));
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
