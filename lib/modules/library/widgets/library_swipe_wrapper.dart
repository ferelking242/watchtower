import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/services/library_swipe_actions.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Wraps a library entry so the configured left/right swipe actions run.
///
/// Defaults, per the "Comportement" settings: a rightward swipe marks the entry
/// as read and the opposite swipe marks its first unread chapter. "Aucun(e)"
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
      await runLibrarySwipeAction(ref, manga, action, context: context);
      // No manual `ref.invalidate` here: the action writes through Isar, and
      // both providers below are `.watch()` streams that re-emit on that write.
      // Invalidating them forced a teardown/re-subscription of the whole
      // library stream — i.e. a synchronous read of every chapter plus a full
      // re-sort on the UI isolate — on every swipe.
    }

    return Dismissible(
      key: ValueKey('library-swipe-${manga.id}-${manga.itemType.name}'),
      direction: _directionFor(leftAction, rightAction),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (direction) async {
        // `startToEnd` is a swipe towards the right edge, `endToStart` towards
        // the left one. The configured "right" action must therefore run on a
        // rightward swipe — the mapping used to be the other way round.
        final action = direction == DismissDirection.startToEnd
            ? rightAction
            : leftAction;
        await run(action);
        // Never actually dismiss: the action is the whole point.
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        action: rightAction,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        action: leftAction,
      ),
      child: child,
    );
  }

  static DismissDirection _directionFor(int left, int right) {
    final leftEnabled = left != 2;
    final rightEnabled = right != 2;
    if (leftEnabled && rightEnabled) return DismissDirection.horizontal;
    // `startToEnd` is the rightward swipe and drives the *right* action, so a
    // left-only configuration must expose `endToStart` (and vice versa). These
    // were swapped, which made a lone enabled side run the disabled one.
    if (leftEnabled) return DismissDirection.endToStart;
    if (rightEnabled) return DismissDirection.startToEnd;
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
        ? librarySwipeActionLabel(context.l10n, action)
        : '';
    final icon = switch (action) {
      0 || 1 => Icons.done_all,
      3 => Icons.library_add,
      4 => Icons.download,
      5 => Icons.share,
      6 => Icons.link,
      7 => Icons.library_add_check_outlined,
      8 => Icons.remove_done,
      9 => Icons.delete_outline,
      _ => Icons.check,
    };
    // The background sits behind the card, so the icon/text must mirror the
    // swipe direction to stay on the leading edge of the gesture.
    final mirrored = alignment == Alignment.centerRight;
    final destructive = action == 7 || action == 9;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: destructive
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: mirrored ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Icon(
            icon,
            size: 18,
            color: destructive
                ? Theme.of(context).colorScheme.onErrorContainer
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: destructive
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
