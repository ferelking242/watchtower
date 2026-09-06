import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:permission_handler/permission_handler.dart';

  // ─────────────────────────────────────────────────────────────────────────────
  // Watchtower — dossiers de téléchargement structurés
  //
  // Structure Android:
  //   /storage/emulated/0/Watchtower/
  //     ├── video/downloads/
  //     ├── music/downloads/
  //     ├── manga/downloads/
  //     └── novels/downloads/
  // ─────────────────────────────────────────────────────────────────────────────

  class WatchtowerFolderService {
    static const _androidBase = '/storage/emulated/0/Watchtower';
    static const mediaFolders = ['video', 'music', 'manga', 'novels'];

    static WatchtowerFolderService? _instance;
    static WatchtowerFolderService get instance =>
        _instance ??= WatchtowerFolderService._();
    WatchtowerFolderService._();

    bool _initialized = false;
    String? _baseDir;
    final Map<String, String> _downloadDirs = {};

    String? get baseDir => _baseDir;
    bool get initialized => _initialized;

    Future<bool> requestPermissions() async {
      if (!Platform.isAndroid) return true;
      final results = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
      return results.values.every((s) => s.isGranted || s.isLimited);
    }

    Future<bool> hasPermissions() async {
      if (!Platform.isAndroid) return true;
      return await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
    }

    Future<void> initialize() async {
      if (_initialized) return;
      try {
        final useExternal = Platform.isAndroid && await hasPermissions();
        String base;
        if (useExternal) {
          base = _androidBase;
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          // On iOS the documents dir IS the app root — appending /Watchtower
          // would create a nested Documents/Watchtower/ that doesn't match
          // StorageProvider.getDirectory() which returns the documents dir directly.
          base = Platform.isIOS ? appDir.path : '${appDir.path}/Watchtower';
        }
        _baseDir = base;

        for (final media in mediaFolders) {
          final dlPath = '$base/$media/downloads';
          await Directory(dlPath).create(recursive: true);
          _downloadDirs[media] = dlPath;
        }
        _initialized = true;
      } catch (_) {
        // Non-bloquant — ne jamais crasher l'app au démarrage
      }
    }

    Future<String?> getDownloadDir(String mediaType) async {
      if (!_initialized) await initialize();
      return _downloadDirs[mediaType.toLowerCase()];
    }

    Future<List<WatchtowerFolderInfo>> getFolderInfoList() async {
      if (!_initialized) await initialize();
      final result = <WatchtowerFolderInfo>[];
      for (final media in mediaFolders) {
        final dlPath = _downloadDirs[media];
        if (dlPath == null) continue;
        final dir = Directory(dlPath);
        int fileCount = 0;
        int totalBytes = 0;
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              fileCount++;
              try { totalBytes += await entity.length(); } catch (_) {}
            }
          }
        }
        result.add(WatchtowerFolderInfo(
          mediaType: media,
          downloadPath: dlPath,
          fileCount: fileCount,
          sizeBytes: totalBytes,
          exists: await dir.exists(),
        ));
      }
      return result;
    }
  }

  class WatchtowerFolderInfo {
    final String mediaType;
    final String downloadPath;
    final int fileCount;
    final int sizeBytes;
    final bool exists;

    const WatchtowerFolderInfo({
      required this.mediaType,
      required this.downloadPath,
      required this.fileCount,
      required this.sizeBytes,
      required this.exists,
    });

    String get formattedSize {
      if (sizeBytes == 0) return '0 B';
      const units = ['B', 'KB', 'MB', 'GB'];
      int idx = 0;
      double val = sizeBytes.toDouble();
      while (val >= 1024 && idx < units.length - 1) {
        val /= 1024;
        idx++;
      }
      return '${val.toStringAsFixed(idx == 0 ? 0 : 1)} ${units[idx]}';
    }

    String get iconLabel {
      return switch (mediaType) {
        'video'  => '🎬',
        'music'  => '🎵',
        'manga'  => '📖',
        'novels' => '📚',
        _        => '📁',
      };
    }

    String get displayName {
      return switch (mediaType) {
        'video'  => 'Vidéo',
        'music'  => 'Musique',
        'manga'  => 'Manga',
        'novels' => 'Romans',
        _        => mediaType,
      };
    }
  }
  