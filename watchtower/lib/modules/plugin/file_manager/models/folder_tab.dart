// lib/modules/plugin/file_manager/models/folder_tab.dart

import 'file_item.dart';

class FolderTab {
  final String label;
  String currentPath;
  List<FileItem> files;
  Set<String> selectedPaths;

  FolderTab({
    required this.label,
    required this.currentPath,
    this.files = const [],
    Set<String>? selectedPaths,
  }) : selectedPaths = selectedPaths ?? {};

  FolderTab copyWith({
    String? label,
    String? currentPath,
    List<FileItem>? files,
    Set<String>? selectedPaths,
  }) {
    return FolderTab(
      label: label ?? this.label,
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      selectedPaths: selectedPaths ?? Set.from(this.selectedPaths),
    );
  }
}
