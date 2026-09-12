import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
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
    String? _lastError;
    final Map<String, String> _downloadDirs = {};

    String? get baseDir => _baseDir;
    bool get initialized => _initialized;
    String? get lastError => _lastError;

    Future<bool> requestPermissions() async {
      if (Platform.isAndroid) {
        // A shared public folder needs one of these permissions, not both.
        // StorageProvider also knows how to use an app-scoped directory when
        // the user declines, so a denial must not disable downloads.
        await StorageProvider().requestPermission();
      }
      await initialize();
      return _initialized;
    }

    Future<bool> hasPermissions() async {
      if (!Platform.isAndroid) return true;
      // The fallback directory is usable without either Android permission.
      // Keep this method useful to callers without making the Download Manager
      // appear disabled after a user declines the optional shared-folder
      // permission.
      if (await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted) {
        return true;
      }
      await initialize();
      return _initialized;
    }

    Future<void> initialize() async {
      if (_initialized) return;
      _lastError = null;
      try {
        final baseDirectory = await StorageProvider().getDefaultDirectory();
        if (baseDirectory == null) {
          _lastError = 'No writable storage directory is available.';
          return;
        }
        _baseDir = baseDirectory.path;

        for (final media in mediaFolders) {
          final dlPath = path.join(baseDirectory.path, media);
          final directory = Directory(dlPath);
          await directory.create(recursive: true);
          if (!await directory.exists()) {
            throw FileSystemException('Directory was not created', dlPath);
          }
          _downloadDirs[media] = dlPath;
        }
        _initialized = true;
      } catch (error) {
        _downloadDirs.clear();
        _lastError = error.toString();
        // Non-blocking: callers can render an actionable error while the
        // queue remains available and can retry initialization later.
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
  