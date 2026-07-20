// lib/modules/plugin/file_manager/widgets/selection_action_bar.dart
// Barre d'actions pour la multi-sélection de fichiers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import '../providers/file_manager_provider.dart';

class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileManagerProvider);
    final notifier = ref.read(fileManagerProvider.notifier);
    final count = state.selectedPaths.length;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Count
            GestureDetector(
              onTap: notifier.clearSelection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$count sélectionné${count > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Copy
            _ActionBtn(
              icon: Broken.copy,
              tooltip: 'Copier',
              onTap: notifier.copySelected,
            ),
            // Cut
            _ActionBtn(
              icon: Icons.content_cut_rounded,
              tooltip: 'Couper',
              onTap: notifier.cutSelected,
            ),
            // Share
            _ActionBtn(
              icon: Broken.share,
              tooltip: 'Partager',
              onTap: () => _shareSelected(context, state.selectedPaths.toList()),
            ),
            // Delete
            _ActionBtn(
              icon: Broken.trash,
              tooltip: 'Supprimer',
              accent: cs.error,
              onTap: () => _confirmDelete(context, ref, count),
            ),
            // More
            _ActionBtn(
              icon: Icons.more_vert_rounded,
              tooltip: 'Plus',
              onTap: () => _showMoreOptions(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSelected(
      BuildContext context, List<String> paths) async {
    final xFiles = paths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int count) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $count élément${count > 1 ? 's' : ''} ?'),
        content: const Text(
            'Cette action est irréversible. Les éléments seront supprimés définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await ref
                  .read(fileManagerProvider.notifier)
                  .deleteSelected();
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur : $error')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(fileManagerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Tout sélectionner'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.selectAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.deselect_rounded),
              title: const Text('Tout désélectionner'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.clearSelection();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? accent;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon,
            size: 22,
            color: accent ?? Theme.of(context).colorScheme.onSurface),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
