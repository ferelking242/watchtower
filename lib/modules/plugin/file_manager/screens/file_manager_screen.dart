// lib/modules/plugin/file_manager/screens/file_manager_screen.dart
// Écran principal du gestionnaire de fichiers — adapté de NFile pour Watchtower.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import 'package:watchtower/core/icon_fonts/broken_icons.dart';

import '../models/file_filter_type.dart';
import '../models/file_item.dart';
import '../providers/file_manager_provider.dart';
import '../utils/file_utils.dart';
import '../widgets/address_bar.dart';
import '../widgets/file_item_widget.dart';
import '../widgets/selection_action_bar.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  final String? initialPath;
  const FileManagerScreen({super.key, this.initialPath});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(fileManagerProvider.notifier);
      final path = widget.initialPath ?? _defaultPath();
      notifier.loadDirectory(path);
    });
  }

  String _defaultPath() {
    if (Platform.isAndroid) return '/storage/emulated/0';
    if (Platform.isIOS) {
      // iOS: Documents directory via path_provider not available here;
      // fall back to a safe root.
      return '/';
    }
    return Platform.environment['HOME'] ?? '/';
  }

  // ── File tap handler ───────────────────────────────────────────────────────

  Future<void> _onTap(FileItem file) async {
    final state = ref.read(fileManagerProvider);
    final notifier = ref.read(fileManagerProvider.notifier);

    if (state.hasSelection) {
      notifier.toggleSelection(file.path);
      return;
    }

    if (file.isDirectory) {
      notifier.loadDirectory(file.path);
      return;
    }

    final kind = FileUtils.kindOf(file.extension);
    switch (kind) {
      case FileKind.image:
        final dir = p.dirname(file.path);
        final images = state.currentFiles
            .where((f) => !f.isDirectory && FileUtils.isImage(f.extension))
            .map((f) => f.path)
            .toList();
        if (context.mounted) {
          context.push('/fileManagerImage',
              extra: (file.path, images));
        }
        break;
      case FileKind.pdf:
      case FileKind.document:
      case FileKind.code:
        if (context.mounted) {
          context.push('/fileManagerDocument', extra: file.path);
        }
        break;
      case FileKind.archive:
        if (context.mounted) {
          context.push('/fileManagerArchive', extra: file.path);
        }
        break;
      case FileKind.video:
      case FileKind.audio:
      default:
        await OpenFile.open(file.path);
        break;
    }
  }

  void _onLongPress(FileItem file) {
    ref.read(fileManagerProvider.notifier).toggleSelection(file.path);
  }

  // ── Create folder/file dialog ──────────────────────────────────────────────

  Future<void> _showCreateDialog({required bool isFolder}) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFolder ? 'Nouveau dossier' : 'Nouveau fichier'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isFolder ? 'nom_dossier' : 'fichier.txt',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Créer')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      final err = isFolder
          ? await ref.read(fileManagerProvider.notifier).createFolder(result.trim())
          : await ref.read(fileManagerProvider.notifier).createFile(result.trim());
      if (err != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  // ── Rename dialog ──────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(FileItem file) async {
    final ctrl = TextEditingController(text: file.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      final err = await ref
          .read(fileManagerProvider.notifier)
          .renameFile(file.path, result.trim());
      if (err != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  // ── Sort menu ──────────────────────────────────────────────────────────────

  void _showSortMenu(BuildContext ctx) {
    final notifier = ref.read(fileManagerProvider.notifier);
    final current = ref.read(fileManagerProvider).sortType;
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Trier par',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...SortType.values.map((s) => ListTile(
                  title: Text(s.label),
                  trailing: current == s
                      ? Icon(Icons.check_rounded,
                          color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    notifier.setSortType(s);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileManagerProvider);
    final notifier = ref.read(fileManagerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canGoBack = state.activeTab.currentPath != _defaultPath() &&
            state.activeTab.currentPath != '/';
        if (canGoBack) {
          await notifier.goBack();
        } else {
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, state, notifier, cs),
        body: Column(
          children: [
            // ── Tabs ────────────────────────────────────────────────────────
            if (state.tabs.length > 1)
              _TabBar(state: state, notifier: notifier),

            // ── Address bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: AddressBar(
                currentPath: state.currentPath,
                onNavigate: (path) => notifier.loadDirectory(path),
              ),
            ),

            // ── Filter chips ─────────────────────────────────────────────────
            _FilterChips(state: state, notifier: notifier),

            // ── Selection bar ────────────────────────────────────────────────
            if (state.hasSelection)
              const SelectionActionBar(),

            // ── Error ────────────────────────────────────────────────────────
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.error!,
                    style: TextStyle(color: cs.error, fontSize: 13)),
              ),

            // ── Content ──────────────────────────────────────────────────────
            Expanded(child: _buildContent(context, state, notifier)),
          ],
        ),
        floatingActionButton: state.hasSelection
            ? null
            : FloatingActionButton(
                mini: true,
                onPressed: () => _showCreateDialog(isFolder: true),
                child: const Icon(Icons.create_new_folder_outlined),
              ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, FileManagerState state,
      FileManagerNotifier notifier, ColorScheme cs) {
    final folderName = p.basename(state.currentPath);
    return AppBar(
      title: Text(
        folderName.isEmpty ? 'Fichiers' : folderName,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          final canGoUp = state.currentPath != _defaultPath() &&
              state.currentPath != '/';
          if (canGoUp) {
            await notifier.goBack();
          } else {
            if (context.mounted) context.pop();
          }
        },
      ),
      actions: [
        // Toggle hidden files
        IconButton(
          icon: Icon(
            state.showHiddenFiles
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            size: 22,
          ),
          tooltip: state.showHiddenFiles ? 'Masquer cachés' : 'Montrer cachés',
          onPressed: notifier.toggleHiddenFiles,
        ),
        // Sort
        IconButton(
          icon: const Icon(Icons.sort_rounded, size: 22),
          tooltip: 'Trier',
          onPressed: () => _showSortMenu(context),
        ),
        // Grid / List toggle
        IconButton(
          icon: Icon(
            state.isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
            size: 22,
          ),
          tooltip: state.isGridView ? 'Vue liste' : 'Vue grille',
          onPressed: notifier.toggleView,
        ),
        // More menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 22),
          onSelected: (v) {
            if (v == 'new_file') _showCreateDialog(isFolder: false);
            if (v == 'new_tab') notifier.addTab();
            if (v == 'refresh') notifier.refresh();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'new_file',
                child: Text('Nouveau fichier')),
            const PopupMenuItem(
                value: 'new_tab',
                child: Text('Nouvel onglet')),
            const PopupMenuItem(
                value: 'refresh',
                child: Text('Actualiser')),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, FileManagerState state,
      FileManagerNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final files = state.filteredFiles;

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.folder, size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('Dossier vide',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45))),
          ],
        ),
      );
    }

    if (state.isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.8,
        ),
        itemCount: files.length,
        itemBuilder: (_, i) {
          final file = files[i];
          return FileGridItem(
            file: file,
            isSelected: state.selectedPaths.contains(file.path),
            onTap: () => _onTap(file),
            onLongPress: () => _onLongPress(file),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: files.length,
      itemBuilder: (_, i) {
        final file = files[i];
        return FileListItem(
          file: file,
          isSelected: state.selectedPaths.contains(file.path),
          onTap: () => _onTap(file),
          onLongPress: () => _onLongPress(file),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (v) {
              if (v == 'rename') _showRenameDialog(file);
              if (v == 'copy') {
                notifier.toggleSelection(file.path);
                notifier.copySelected();
                notifier.clearSelection();
              }
              if (v == 'cut') {
                notifier.toggleSelection(file.path);
                notifier.cutSelected();
                notifier.clearSelection();
              }
              if (v == 'delete') {
                notifier.toggleSelection(file.path);
                notifier.deleteSelected();
              }
              if (v == 'open_with') OpenFile.open(file.path);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renommer')),
              const PopupMenuItem(value: 'copy', child: Text('Copier')),
              const PopupMenuItem(value: 'cut', child: Text('Couper')),
              if (!file.isDirectory)
                const PopupMenuItem(
                    value: 'open_with', child: Text('Ouvrir avec…')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final FileManagerState state;
  final FileManagerNotifier notifier;
  const _TabBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: state.tabs.length,
        itemBuilder: (_, i) {
          final tab = state.tabs[i];
          final isActive = i == state.activeTabIndex;
          return GestureDetector(
            onTap: () => notifier.setActiveTab(i),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? cs.primaryContainer : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? cs.onPrimaryContainer
                          : cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (state.tabs.length > 1) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => notifier.closeTab(i),
                      child: Icon(Icons.close_rounded,
                          size: 14,
                          color: isActive
                              ? cs.onPrimaryContainer
                              : cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final FileManagerState state;
  final FileManagerNotifier notifier;
  const _FilterChips({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: FileFilterType.values.map((f) {
          final isSelected = state.filterType == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => notifier.setFilter(f),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}
