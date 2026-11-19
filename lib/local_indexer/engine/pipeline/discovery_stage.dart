import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:path/path.dart' as p;

/// The three Smart Library scanners are intentionally disjoint.
enum LocalScanMode {
  videos,
  manga,
  music;

  /// MediaStore collection this mode reads, or `null` when the mode has no
  /// platform index (manga archives are not in MediaStore).
  ///
  /// A MediaStore URI has the shape
  /// `content://media/external/<collection>/media/<id>`, so this is what
  /// scopes stale-row reconciliation to the mode being scanned instead of
  /// letting a music scan purge every video.
  String? get mediaStoreCollection => switch (this) {
        LocalScanMode.videos => 'video',
        LocalScanMode.music => 'audio',
        LocalScanMode.manga => null,
      };
}

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
  static const audioExtensions = {
    '.mp3', '.m4a', '.aac', '.flac', '.opus', '.ogg', '.oga', '.wav', '.wma',
    '.alac', '.aiff', '.aif', '.ape', '.wv', '.mka',
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
    final allowed = (includeImages || policy.includeImages)
        ? policy.allowedExtensions
        : policy.allowedExtensions.difference(mangaPageExtensions);
    final batch = <DiscoveredFile>[];
    final seen = <String>{};
    final seenMangaFolders = <String>{};
    // A MediaStore row can name the same file as a different path: on Android
    // 10+ the DATA column may be withheld and the row arrives as a
    // `content://` URI while the walk finds `/storage/.../film.mkv`. Path
    // de-duplication cannot catch that, so the display name plus the byte size
    // identifies the file instead. MediaStore rows come first, which is what
    // we want: they carry the duration the walk cannot know.
    final seenIdentities = <String>{};

    // Android MediaStore can provide the same file as the filesystem walk.
    // De-duplicate before the expensive analysis stage.
    for (final file in additionalFiles) {
      if (!allowed.contains(file.extension) ||
          file.size < policy.minimumFileSize ||
          !_passesQualityGate(file) ||
          !seen.add(file.path) ||
          !seenIdentities.add(_identityOf(file))) {
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

      // [_walk] skips unreadable subtrees itself; scoped storage may deny the
      // whole root while MediaStore still supplies the files.
      await for (final entity in _walk(dir, root)) {
        if (entity is! File) continue;

        if (_isInExcludedDir(entity.path, root)) continue;
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
        if (!seenIdentities.add(
          '${p.basename(entity.path).toLowerCase()}|${stat.size}',
        )) {
          continue;
        }

        // A filename that announces an extra ("...sample.mkv") is not a movie
        // or an episode; drop it before it reaches the library.
        if (policy.rejectsName(p.basename(entity.path))) {
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
    }

    if (batch.isNotEmpty) yield List.unmodifiable(batch);
  }

  /// Identity of a MediaStore row, used to recognise the same file found again
  /// by the filesystem walk under a different path.
  ///
  /// [DiscoveredFile.analysisName] holds the real display name when the row
  /// came as a `content://` URI; without it the basename is the numeric row id
  /// and would never match.
  static String _identityOf(DiscoveredFile file) {
    final name = (file.analysisName ?? file.basename).toLowerCase();
    return '$name|${file.size}';
  }

  /// True when a discovered file passes the policy's duration and name gates.
  ///
  /// The filesystem walk never knows a duration (it would need to open the
  /// file), so this only ever rejects MediaStore rows. A rejected file is not a
  /// movie or an episode.
  bool _passesQualityGate(DiscoveredFile file) {
    if (policy.minimumDurationMs > 0 &&
        file.durationMs != null &&
        file.durationMs! < policy.minimumDurationMs) {
      return false;
    }
    return !policy.rejectsName(file.basename);
  }

  /// Recursively yields the entries under [dir], skipping unreadable subtrees.
  ///
  /// [Directory.list] is a single-subscription stream that aborts the whole
  /// walk with a [FileSystemException] as soon as one descendant cannot be
  /// read. On Android `/storage/emulated/0/Android/data` and `/data` always
  /// raise, even with MANAGE_EXTERNAL_STORAGE, so one recursive walk of shared
  /// storage ended before yielding any file — the library stayed empty. Listing
  /// folder by folder keeps every accessible sibling.
  Stream<FileSystemEntity> _walk(Directory dir, String root) async* {
    final pending = <Directory>[dir];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final List<FileSystemEntity> children;
      try {
        children = await current.list(followLinks: followLinks).toList();
      } on FileSystemException {
        continue;
      }
      for (final child in children) {
        if (child is Directory) {
          if (_isInExcludedDir(child.path, root)) continue;
          pending.add(child);
        } else {
          yield child;
        }
      }
    }
  }

  /// Vérifie si un chemin contient un dossier exclu.
  ///
  /// Seuls les segments situés *sous* [root] sont examinés. Un dossier
  /// sélectionné par l'utilisateur peut lui-même vivre dans un répertoire
  /// nommé `tmp`, `cache`… ; filtrer ses ancêtres rejetait alors l'intégralité
  /// de la bibliothèque.
  bool _isInExcludedDir(String path, String root) {
    final pathParts = p.split(p.normalize(path));
    final rootParts = p.split(p.normalize(root));
    for (var i = rootParts.length; i < pathParts.length; i++) {
      final segment = pathParts[i].toLowerCase();
      if (segment.isEmpty) continue;
      if (segment.startsWith('.') ||
          policy.ignoredDirectories.contains(segment) ||
          (segment == 'android' &&
              i + 1 < pathParts.length &&
              {'data', 'obb'}.contains(pathParts[i + 1].toLowerCase()))) {
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
    if (audioExtensions.contains(ext)) return FileCategory.audio;
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

  /// Minimum duration (ms) a video must reach to be indexed. Short clips
  /// (ringtones, memes, screen recordings) are not movies or series, so the
  /// Watch scan skips them. `0` disables the duration gate (manga/music).
  final int minimumDurationMs;

  /// File-name signals that mark a candidate as *not* a movie/series (sample,
  /// trailer, featurette, bonus…). A matched name is rejected during
  /// discovery so the noise never reaches the library.
  final List<RegExp> excludedNamePatterns;

  final int? maximumDepth;
  final bool includeImages;

  const ScanPolicy({
    this.mode = LocalScanMode.videos,
    this.allowedExtensions = DiscoveryStage.videoExtensions,
    this.ignoredDirectories = _defaultIgnoredDirectories,
    this.ignoredPatterns = const [],
    this.minimumFileSize = 1,
    this.minimumDurationMs = 0,
    this.excludedNamePatterns = const [],
    this.maximumDepth,
    this.includeImages = false,
  });

  ScanPolicy.videos({
    this.ignoredDirectories = _defaultIgnoredDirectories,
    this.ignoredPatterns = const [],
    // A 0-byte stub is not a movie. 24 MB filters the thumbnails, voice notes
    // and tiny clips that share the video container with real films.
    this.minimumFileSize = 24 * 1024 * 1024,
    // Below ~4 minutes a file is a clip, not a movie or an episode.
    this.minimumDurationMs = 4 * 60 * 1000,
    this.maximumDepth,
  })  : mode = LocalScanMode.videos,
        allowedExtensions = DiscoveryStage.videoExtensions,
        includeImages = false,
        excludedNamePatterns = _videoNoisePatterns;

  const ScanPolicy.manga({
    this.ignoredDirectories = _defaultIgnoredDirectories,
    this.ignoredPatterns = const [],
    this.minimumFileSize = 1,
    this.minimumDurationMs = 0,
    this.excludedNamePatterns = const [],
    this.maximumDepth,
  })  : mode = LocalScanMode.manga,
        allowedExtensions = const {
          ...DiscoveryStage.mangaArchiveExtensions,
          ...DiscoveryStage.mangaPageExtensions,
        },
        includeImages = true;

  const ScanPolicy.music({
    this.ignoredDirectories = _defaultIgnoredDirectories,
    this.ignoredPatterns = const [],
    // Music files carry real audio well under a megabyte; 64 KB drops the
    // truncated/placeholder files without excluding legitimately tiny tracks.
    this.minimumFileSize = 64 * 1024,
    this.minimumDurationMs = 0,
    this.excludedNamePatterns = const [],
    this.maximumDepth,
  })  : mode = LocalScanMode.music,
        allowedExtensions = DiscoveryStage.audioExtensions,
        includeImages = false;

  /// True when [name] (a file basename) carries a signal that rules the file
  /// out as a movie/series entry.
  bool rejectsName(String name) {
    if (excludedNamePatterns.isEmpty) return false;
    final lower = name.toLowerCase();
    return excludedNamePatterns.any((pattern) => pattern.hasMatch(lower));
  }
}

const _defaultIgnoredDirectories = {
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
};

/// File-name markers that mean "extras", not a movie or an episode. The match
/// is anchored on a separator so a title legitimately containing the word
/// ("The Trailer Park Boys") is not rejected.
final _videoNoisePatterns = <RegExp>[
  RegExp(r'(^|[\s._\-\[(])(sample|trailer|teaser|featurette|behind[\s._-]?the'
      r'[\s._-]?scenes|deleted[\s._-]?scenes|bloopers?|outtakes?|interview|'
      r'extras?|bonus|promo|clip)([\s._\-\])]|$)'),
];

/// Fichier découvert sur le disque (pas encore analysé).
class DiscoveredFile {
  final String path;
  final int size;
  final int modifiedAt;
  final String extension;
  final String? analysisName;

  /// Duration in milliseconds when the platform knows it (MediaStore video
  /// rows). `null` on a plain filesystem walk, where the duration gate cannot
  /// be applied without opening the file.
  final int? durationMs;

  const DiscoveredFile({
    required this.path,
    required this.size,
    required this.modifiedAt,
    required this.extension,
    this.analysisName,
    this.durationMs,
  });

  String get basename => p.basename(path);

  FileCategory get category => DiscoveryStage.categoryOf(extension);
}

enum FileCategory { video, audio, archive, novel, image, unknown }
