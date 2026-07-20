// lib/modules/plugin/file_manager/providers/file_manager_provider.dart
// Gestionnaire d'état Riverpod pour le File Manager (adapté de NFile).

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../models/file_filter_type.dart';
import '../models/folder_tab.dart';
import '../utils/file_utils.dart';

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class FileManagerState {
  final List<FolderTab> tabs;
  final int activeTabIndex;
  final bool isLoading;
  final String? error;
  final bool isGridView;
  final SortType sortType;
  final FileFilterType filterType;
  final bool showHiddenFiles;
  final List<String>? clipboardPaths;
  final bool isCut;
  final double storageUsedBytes;
  final double storageTotalBytes;

  const FileManagerState({
    required this.tabs,
    this.activeTabIndex = 0,
    this.isLoading = false,
    this.error,
    this.isGridView = false,
    this.sortType = SortType.nameAsc,
    this.filterType = FileFilterType.all,
    this.showHiddenFiles = false,
    this.clipboardPaths,
    this.isCut = false,
    this.storageUsedBytes = 0,
    this.storageTotalBytes = 0,
  });

  FolderTab get activeTab => tabs[activeTabIndex];

  String get currentPath => activeTab.currentPath;
  List<FileItem> get currentFiles => activeTab.files;
  Set<String> get selectedPaths => activeTab.selectedPaths;
  bool get hasSelection => activeTab.selectedPaths.isNotEmpty;

  List<FileItem> get filteredFiles {
    final files = currentFiles;
    final filtered = filterType == FileFilterType.all
        ? files
        : files.where((f) {
            if (f.isDirectory) return filterType == FileFilterType.all;
            switch (filterType) {
              case FileFilterType.images:
                return FileUtils.isImage(f.extension);
              case FileFilterType.videos:
                return FileUtils.isVideo(f.extension);
              case FileFilterType.audio:
                return FileUtils.isAudio(f.extension);
              case FileFilterType.archives:
                return FileUtils.isArchive(f.extension);
              case FileFilterType.documents:
                return FileUtils.isDocument(f.extension) ||
                    FileUtils.isPdf(f.extension);
              default:
                return true;
            }
          }).toList();

    return _sortFiles(filtered);
  }

  List<FileItem> _sortFiles(List<FileItem> files) {
    final dirs = files.where((f) => f.isDirectory).toList();
    final fls = files.where((f) => !f.isDirectory).toList();

    int cmp(FileItem a, FileItem b) {
      switch (sortType) {
        case SortType.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortType.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortType.dateAsc:
          return a.modified.compareTo(b.modified);
        case SortType.dateDesc:
          return b.modified.compareTo(a.modified);
        case SortType.sizeAsc:
          return a.size.compareTo(b.size);
        case SortType.sizeDesc:
          return b.size.compareTo(a.size);
      }
    }

    dirs.sort(cmp);
    fls.sort(cmp);
    return [...dirs, ...fls];
  }

  FileManagerState copyWith({
    List<FolderTab>? tabs,
    int? activeTabIndex,
    bool? isLoading,
    String? Function()? error,
    bool? isGridView,
    SortType? sortType,
    FileFilterType? filterType,
    bool? showHiddenFiles,
    List<String>? Function()? clipboardPaths,
    bool? isCut,
    double? storageUsedBytes,
    double? storageTotalBytes,
  }) {
    return FileManagerState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      isGridView: isGridView ?? this.isGridView,
      sortType: sortType ?? this.sortType,
      filterType: filterType ?? this.filterType,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      clipboardPaths:
          clipboardPaths != null ? clipboardPaths() : this.clipboardPaths,
      isCut: isCut ?? this.isCut,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
      storageTotalBytes: storageTotalBytes ?? this.storageTotalBytes,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FileManagerNotifier extends Notifier<FileManagerState> {
  @override
  FileManagerState build() {
    Future.microtask(_init);
    return FileManagerState(
      tabs: [
        FolderTab(
          label: '1',
          currentPath: _defaultPath(),
        ),
      ],
    );
  }

  static String _defaultPath() {
    if (Platform.isAndroid) return '/storage/emulated/0';
    if (Platform.isLinux || Platform.isMacOS) {
      return Platform.environment['HOME'] ?? '/';
    }
    if (Platform.isWindows) return 'C:\\';
    return '/';
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadPreferences();
    await loadDirectory(state.currentPath);
    await _loadStorageInfo();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isGridView: prefs.getBool('fm_grid_view') ?? false,
      sortType: SortType.values[prefs.getInt('fm_sort_type') ?? 0],
      showHiddenFiles: prefs.getBool('fm_show_hidden') ?? false,
    );
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fm_grid_view', state.isGridView);
    await prefs.setInt('fm_sort_type', state.sortType.index);
    await prefs.setBool('fm_show_hidden', state.showHiddenFiles);
  }

  Future<void> _loadStorageInfo() async {
    try {
      if (Platform.isAndroid) {
        final stat = await FileStat.stat('/storage/emulated/0');
        // Storage info via stat isn't accurate on Android; use a fallback
        state = state.copyWith(
          storageUsedBytes: 0,
          storageTotalBytes: 0,
        );
      }
    } catch (_) {}
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> loadDirectory(String path, {int? tabIndex}) async {
    final idx = tabIndex ?? state.activeTabIndex;
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final dir = Directory(path);
      final entities = await dir.list().toList();

      final items = await Future.wait(
        entities
            .where((e) {
              final name = e.path.split('/').last;
              if (!state.showHiddenFiles && name.startsWith('.')) return false;
              return true;
            })
            .map((e) async {
              try {
                final stat = await e.stat();
                return FileItem.fromEntity(e, stat);
              } catch (_) {
                return null;
              }
            }),
      );

      final validItems = items.whereType<FileItem>().toList();

      final newTabs = List<FolderTab>.from(state.tabs);
      newTabs[idx] = newTabs[idx].copyWith(
        currentPath: path,
        files: validItems,
        selectedPaths: {},
      );

      state = state.copyWith(
        tabs: newTabs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString(),
      );
    }
  }

  Future<void> goBack() async {
    final current = state.currentPath;
    final parent = p.dirname(current);
    if (parent == current) return; // déjà à la racine
    await loadDirectory(parent);
  }

  bool get canGoBack {
    final current = state.currentPath;
    return p.dirname(current) != current;
  }

  Future<void> refresh() => loadDirectory(state.currentPath);

  // ── Onglets ───────────────────────────────────────────────────────────────

  void setActiveTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    state = state.copyWith(activeTabIndex: index);
    loadDirectory(state.tabs[index].currentPath, tabIndex: index);
  }

  void addTab() {
    final newTab = FolderTab(
      label: '${state.tabs.length + 1}',
      currentPath: _defaultPath(),
    );
    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: newTabs,
      activeTabIndex: newTabs.length - 1,
    );
    loadDirectory(_defaultPath(), tabIndex: newTabs.length - 1);
  }

  void closeTab(int index) {
    if (state.tabs.length <= 1) return;
    final newTabs = List<FolderTab>.from(state.tabs)..removeAt(index);
    final newIndex = (state.activeTabIndex >= newTabs.length)
        ? newTabs.length - 1
        : state.activeTabIndex;
    state = state.copyWith(
      tabs: newTabs,
      activeTabIndex: newIndex,
    );
  }

  // ── Sélection ─────────────────────────────────────────────────────────────

  void toggleSelection(String path) {
    final newTabs = List<FolderTab>.from(state.tabs);
    final tab = newTabs[state.activeTabIndex];
    final sel = Set<String>.from(tab.selectedPaths);
    if (sel.contains(path)) {
      sel.remove(path);
    } else {
      sel.add(path);
    }
    newTabs[state.activeTabIndex] = tab.copyWith(selectedPaths: sel);
    state = state.copyWith(tabs: newTabs);
  }

  void selectAll() {
    final newTabs = List<FolderTab>.from(state.tabs);
    final tab = newTabs[state.activeTabIndex];
    final sel = tab.files.map((f) => f.path).toSet();
    newTabs[state.activeTabIndex] = tab.copyWith(selectedPaths: sel);
    state = state.copyWith(tabs: newTabs);
  }

  void clearSelection() {
    final newTabs = List<FolderTab>.from(state.tabs);
    final tab = newTabs[state.activeTabIndex];
    newTabs[state.activeTabIndex] = tab.copyWith(selectedPaths: {});
    state = state.copyWith(tabs: newTabs);
  }

  // ── Presse-papiers ───────────────────────────────────────────────────────

  void copySelected() {
    final paths = state.selectedPaths.toList();
    if (paths.isEmpty) return;
    state = state.copyWith(
      clipboardPaths: () => paths,
      isCut: false,
    );
    clearSelection();
  }

  void cutSelected() {
    final paths = state.selectedPaths.toList();
    if (paths.isEmpty) return;
    state = state.copyWith(
      clipboardPaths: () => paths,
      isCut: true,
    );
    clearSelection();
  }

  Future<String?> pasteHere() async {
    final clipboard = state.clipboardPaths;
    if (clipboard == null || clipboard.isEmpty) return null;
    final dest = state.currentPath;

    state = state.copyWith(isLoading: true);
    try {
      for (final src in clipboard) {
        final name = p.basename(src);
        final destPath = p.join(dest, name);

        final entity = FileSystemEntity.typeSync(src) ==
                FileSystemEntityType.directory
            ? Directory(src)
            : File(src);

        if (entity is File) {
          await entity.copy(destPath);
          if (state.isCut) await entity.delete();
        } else if (entity is Directory) {
          await _copyDirectory(entity, Directory(destPath));
          if (state.isCut) await entity.delete(recursive: true);
        }
      }
      state = state.copyWith(
        clipboardPaths: () => null,
        isLoading: false,
      );
      await refresh();
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString();
    }
  }

  Future<void> _copyDirectory(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list()) {
      final destChild = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(destChild);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(destChild));
      }
    }
  }

  // ── Opérations ────────────────────────────────────────────────────────────

  Future<String?> deleteSelected({bool permanently = false}) async {
    final paths = state.selectedPaths.toList();
    if (paths.isEmpty) return null;
    state = state.copyWith(isLoading: true);
    try {
      for (final path in paths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }
      clearSelection();
      state = state.copyWith(isLoading: false);
      await refresh();
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString();
    }
  }

  Future<String?> renameFile(String path, String newName) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      final parent = p.dirname(path);
      final newPath = p.join(parent, newName);

      if (type == FileSystemEntityType.directory) {
        await Directory(path).rename(newPath);
      } else {
        await File(path).rename(newPath);
      }
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> createFolder(String name) async {
    try {
      final path = p.join(state.currentPath, name);
      await Directory(path).create(recursive: true);
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> createFile(String name) async {
    try {
      final path = p.join(state.currentPath, name);
      await File(path).create(recursive: true);
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── UI settings ──────────────────────────────────────────────────────────

  void toggleView() {
    state = state.copyWith(isGridView: !state.isGridView);
    _savePreferences();
  }

  void setSortType(SortType sort) {
    state = state.copyWith(sortType: sort);
    _savePreferences();
  }

  void setFilter(FileFilterType filter) {
    state = state.copyWith(filterType: filter);
  }

  void toggleHiddenFiles() {
    state = state.copyWith(showHiddenFiles: !state.showHiddenFiles);
    _savePreferences();
    refresh();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final fileManagerProvider =
    NotifierProvider<FileManagerNotifier, FileManagerState>(
  FileManagerNotifier.new,
);
