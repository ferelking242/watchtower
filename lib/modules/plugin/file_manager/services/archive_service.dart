// lib/modules/plugin/file_manager/services/archive_service.dart
// Service d'archivage — adapté de NFile, utilise le package `archive` de WT.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  // ── Création ──────────────────────────────────────────────────────────────

  /// Crée une archive ZIP depuis une liste de chemins.
  static Future<void> createZip({
    required List<String> sourcePaths,
    required String destPath,
  }) async {
    await compute(_createZipIsolate, {
      'sources': sourcePaths,
      'dest': destPath,
    });
  }

  static void _createZipIsolate(Map<String, dynamic> args) {
    final sources = (args['sources'] as List).cast<String>();
    final dest = args['dest'] as String;

    final encoder = ZipFileEncoder();
    encoder.create(dest);

    for (final src in sources) {
      final type = FileSystemEntity.typeSync(src);
      if (type == FileSystemEntityType.directory) {
        encoder.addDirectory(Directory(src));
      } else if (type == FileSystemEntityType.file) {
        encoder.addFile(File(src));
      }
    }
    encoder.close();
  }

  // ── Extraction ────────────────────────────────────────────────────────────

  /// Extrait une archive ZIP dans un dossier destination.
  static Future<void> extractZip({
    required String archivePath,
    required String destDir,
  }) async {
    await compute(_extractZipIsolate, {
      'archive': archivePath,
      'dest': destDir,
    });
  }

  static void _extractZipIsolate(Map<String, dynamic> args) {
    final archivePath = args['archive'] as String;
    final destDir = args['dest'] as String;
    extractFileToDisk(archivePath, destDir);
  }

  /// Extrait un TAR.GZ dans un dossier destination.
  static Future<void> extractTarGz({
    required String archivePath,
    required String destDir,
  }) async {
    await compute(_extractTarGzIsolate, {
      'archive': archivePath,
      'dest': destDir,
    });
  }

  static void _extractTarGzIsolate(Map<String, dynamic> args) {
    final archivePath = args['archive'] as String;
    final destDir = args['dest'] as String;

    final bytes = File(archivePath).readAsBytesSync();
    final ungzipped = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(ungzipped);

    for (final file in archive) {
      final filePath = p.join(destDir, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(filePath).createSync(recursive: true);
      }
    }
  }

  // ── Lecture ───────────────────────────────────────────────────────────────

  /// Retourne la liste des fichiers dans une archive ZIP (lecture seule).
  static Future<List<ArchiveEntry>> listZipEntries(String archivePath) async {
    return compute(_listZipIsolate, archivePath);
  }

  static List<ArchiveEntry> _listZipIsolate(String archivePath) {
    final bytes = File(archivePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    return archive.files
        .map((f) => ArchiveEntry(
              name: f.name,
              isFile: f.isFile,
              size: f.size,
              compressedSize: f.size,
            ))
        .toList();
  }

  // ── Détection ─────────────────────────────────────────────────────────────

  static bool isSupported(String ext) => {
    'zip', 'tar', 'gz', 'tgz', 'cbz', 'cbr',
  }.contains(ext.toLowerCase());

  static bool canExtract(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return isSupported(ext);
  }
}

/// Entrée dans une archive.
class ArchiveEntry {
  final String name;
  final bool isFile;
  final int size;
  final int compressedSize;

  const ArchiveEntry({
    required this.name,
    required this.isFile,
    required this.size,
    required this.compressedSize,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
