// lib/modules/plugin/file_manager/widgets/file_item_widget.dart
// Widget d'un élément de fichier ou dossier dans la liste/grille.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import '../models/file_item.dart';
import '../providers/file_manager_provider.dart';
import '../utils/file_utils.dart';

// ── Item liste ────────────────────────────────────────────────────────────────

class FileListItem extends ConsumerWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      fileManagerProvider.select((s) => s.selectedPaths.contains(item.path)),
    );
    final hasSelection = ref.watch(
      fileManagerProvider.select((s) => s.hasSelection),
    );

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = FileUtils.colorOf(item.extension, isDirectory: item.isDirectory);
    final icon = FileUtils.iconOf(item.extension, isDirectory: item.isDirectory);

    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.30)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: hasSelection ? () => ref.read(fileManagerProvider.notifier).toggleSelection(item.path) : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Selection indicator or icon
              Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _buildThumbnail(item, icon, color),
                  ),
                  if (selected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Name + metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isDirectory
                          ? _formatDate(item.modified)
                          : '${item.formattedSize} · ${_formatDate(item.modified)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(FileItem item, IconData fallback, Color color) {
    if (!item.isDirectory && FileUtils.isImage(item.extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(item.path),
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallback, color: color, size: 22),
        ),
      );
    }
    return Icon(fallback, color: color, size: 22);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ── Item grille ───────────────────────────────────────────────────────────────

class FileGridItem extends ConsumerWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileGridItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      fileManagerProvider.select((s) => s.selectedPaths.contains(item.path)),
    );
    final hasSelection = ref.watch(
      fileManagerProvider.select((s) => s.hasSelection),
    );

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = FileUtils.colorOf(item.extension, isDirectory: item.isDirectory);
    final icon = FileUtils.iconOf(item.extension, isDirectory: item.isDirectory);

    return GestureDetector(
      onTap: hasSelection
          ? () => ref.read(fileManagerProvider.notifier).toggleSelection(item.path)
          : onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.45)
              : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Thumbnail or icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildThumbnail(item, icon, color),
                ),
                if (selected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            if (!item.isDirectory)
              Text(
                item.formattedSize,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(FileItem item, IconData fallback, Color color) {
    if (!item.isDirectory && FileUtils.isImage(item.extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(item.path),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallback, color: color, size: 28),
        ),
      );
    }
    return Icon(fallback, color: color, size: 28);
  }
}
