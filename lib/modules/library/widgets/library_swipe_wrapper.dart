import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/services/library_swipe_actions.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';

/// Wraps a library entry so the configured left/right swipe actions run.
///
/// Mirrors Mihon's "Comportement" settings: the left swipe defaults to
/// "Marquer le chapitre" and the right one to "Marquer comme lu". "Aucun(e)"
/// disables the gesture for that side. The card is never dismissed — the swipe
/// fires the action and snaps back, so the entry stays visible.
class LibrarySwipeWrapper extends ConsumerWidget {
  const LibrarySwipeWrapper({
    super.key,
    required this.manga,
    required this.child,
  });

  final Manga manga;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftAction = ref.watch(librarySwipeLeftProvider);
    final rightAction = ref.watch(librarySwipeRightProvider);

    Future<void> run(int action) async {
      await runLibrarySwipeAction(ref, manga, action);
      if (!context.mounted) return;
      // Re-read Isar so the card reflects the new read/library state.
      ref.invalidate(
        getAllMangaStreamProvider(categoryId: null, itemType: manga.itemType),
      );
      ref.invalidate(
        getAllMangaWithoutCategoriesStreamProvider(itemType: manga.itemType),
      );
    }

    return Dismissible(
      key: ValueKey('library-swipe-${manga.id}-${manga.itemType.name}'),
      direction: _directionFor(leftAction, rightAction),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd
            ? leftAction
            : rightAction;
        await run(action);
        // Never actually dismiss: the action is the whole point.
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        action: leftAction,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        action: rightAction,
      ),
      child: child,
    );
  }

  static DismissDirection _directionFor(int left, int right) {
    final leftEnabled = left != 2;
    final rightEnabled = right != 2;
    if (leftEnabled && rightEnabled) return DismissDirection.horizontal;
    if (leftEnabled) return DismissDirection.startToEnd;
    if (rightEnabled) return DismissDirection.endToStart;
    return DismissDirection.none;
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.alignment, required this.action});

  final Alignment alignment;
  final int action;

  @override
  Widget build(BuildContext context) {
    final label = action >= 0 && action < kLibrarySwipeActions.length
        ? kLibrarySwipeActions[action]
        : '';
    final icon = switch (action) {
      0 || 1 => Icons.done_all,
      3 => Icons.library_add,
      4 => Icons.download,
      5 => Icons.share,
      _ => Icons.check,
    };
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
