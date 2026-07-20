// lib/modules/plugin/file_manager/models/file_item.dart

import 'dart:io';

/// Représentation légère d'un élément du système de fichiers.
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size; // bytes, 0 pour les dossiers
  final DateTime modified;
  final String? extension;

  const FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.extension,
  });

  factory FileItem.fromEntity(FileSystemEntity entity, FileStat stat) {
    final name = entity.path.split('/').last;
    return FileItem(
      name: name,
      path: entity.path,
      isDirectory: entity is Directory,
      size: stat.size < 0 ? 0 : stat.size,
      modified: stat.modified,
      extension: entity is File ? _ext(name) : null,
    );
  }

  static String? _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? null : name.substring(dot + 1).toLowerCase();
  }

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  bool operator ==(Object other) =>
      other is FileItem && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
