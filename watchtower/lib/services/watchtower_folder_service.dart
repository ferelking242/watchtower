import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:permission_handler/permission_handler.dart';
  import 'package:watchtower/providers/storage_provider.dart';

  // ─────────────────────────────────────────────────────────────────────────────
  // Watchtower — dossier de téléchargement unique
  //
  // Structure Android:
  //   /storage/emulated/0/watchtower/
  //     └── download/
  // ─────────────────────────────────────────────────────────────────────────────

  class WatchtowerFolderService {
    static const mediaFolders = ['download'];

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
        final baseDirectory = await StorageProvider().getDefaultDirectory();
        if (baseDirectory == null) return;
        _baseDir = baseDirectory.path;

        for (final media in mediaFolders) {
          final dlPath = '$baseDir/$media';
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
      // Keep the old API compatible while all media now share one folder.
      return _downloadDirs['download'];
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
        'download' => '📁',
        _        => '📁',
      };
    }

    String get displayName {
      return switch (mediaType) {
        'download' => 'Téléchargements',
        _        => mediaType,
      };
    }
  }
  