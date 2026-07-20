// lib/modules/plugin/file_manager/utils/file_utils.dart
// Utilitaires de détection de type de fichier pour le gestionnaire.

import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

/// Catégorie d'un fichier selon son extension.
enum FileKind { folder, image, video, audio, archive, pdf, document, code, apk, unknown }

class FileUtils {
  // ── Détection de type ─────────────────────────────────────────────────────

  static FileKind kindOf(String? ext) {
    if (ext == null) return FileKind.unknown;
    final e = ext.toLowerCase();
    if (_images.contains(e))    return FileKind.image;
    if (_videos.contains(e))    return FileKind.video;
    if (_audios.contains(e))    return FileKind.audio;
    if (_archives.contains(e))  return FileKind.archive;
    if (e == 'pdf')             return FileKind.pdf;
    if (_docs.contains(e))      return FileKind.document;
    if (_code.contains(e))      return FileKind.code;
    if (e == 'apk')             return FileKind.apk;
    return FileKind.unknown;
  }

  static bool isImage(String? ext) => kindOf(ext) == FileKind.image;
  static bool isVideo(String? ext) => kindOf(ext) == FileKind.video;
  static bool isAudio(String? ext) => kindOf(ext) == FileKind.audio;
  static bool isArchive(String? ext) => kindOf(ext) == FileKind.archive;
  static bool isPdf(String? ext)    => kindOf(ext) == FileKind.pdf;
  static bool isDocument(String? ext) => kindOf(ext) == FileKind.document || kindOf(ext) == FileKind.code;
  static bool isMarkdown(String? ext) => ext == 'md' || ext == 'markdown';

  // ── Icône ────────────────────────────────────────────────────────────────

  static IconData iconOf(String? ext, {bool isDirectory = false}) {
    if (isDirectory) return Broken.folder;
    switch (kindOf(ext)) {
      case FileKind.image:    return Broken.image;
      case FileKind.video:    return Broken.video_square;
      case FileKind.audio:    return Broken.music;
      case FileKind.archive:  return Broken.zip_file;
      case FileKind.pdf:      return Broken.book;
      case FileKind.document: return Broken.document;
      case FileKind.code:     return Broken.code;
      case FileKind.apk:      return Icons.android_rounded;
      default:                return Broken.document;
    }
  }

  static Color colorOf(String? ext, {bool isDirectory = false}) {
    if (isDirectory) return const Color(0xFFFFA726);
    switch (kindOf(ext)) {
      case FileKind.image:    return const Color(0xFF26A69A);
      case FileKind.video:    return const Color(0xFF5C6BC0);
      case FileKind.audio:    return const Color(0xFFEC407A);
      case FileKind.archive:  return const Color(0xFF8D6E63);
      case FileKind.pdf:      return const Color(0xFFEF5350);
      case FileKind.document: return const Color(0xFF42A5F5);
      case FileKind.code:     return const Color(0xFF66BB6A);
      case FileKind.apk:      return const Color(0xFF4CAF50);
      default:                return const Color(0xFF9E9E9E);
    }
  }

  // ── Formatage taille ─────────────────────────────────────────────────────

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ── Sets d'extensions ─────────────────────────────────────────────────────

  static const _images = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg',
    'heic', 'heif', 'avif', 'tiff', 'tif', 'ico',
  };

  static const _videos = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    'm4v', 'mpg', 'mpeg', '3gp', 'ts', 'm2ts', 'vob',
  };

  static const _audios = {
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a', 'wma',
    'opus', 'aiff', 'ape', 'alac',
  };

  static const _archives = {
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
    'lz4', 'zst', 'tar.gz', 'tgz', 'tar.bz2', 'tar.xz',
    'cbz', 'cbr',
  };

  static const _docs = {
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'odt', 'ods', 'odp', 'rtf', 'txt', 'md', 'markdown',
    'html', 'htm', 'xml', 'json', 'csv',
  };

  static const _code = {
    'dart', 'py', 'js', 'ts', 'kt', 'java', 'swift',
    'c', 'cpp', 'h', 'rs', 'go', 'rb', 'php', 'sh',
    'yaml', 'yml', 'toml', 'ini', 'conf', 'sql',
  };
}
