import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/extensions/context.dart';

/// Content filter of the music home, in the Spotify shape: one "All" pill and
/// a "Music" capsule that unfolds into "Music | Following" once selected.
enum MusicHomeFilter { all, music, following }

class MusicFilterBar extends StatelessWidget {
  final MusicHomeFilter filter;
  final bool expanded;
  final ValueChanged<MusicHomeFilter> onSelected;

  const MusicFilterBar({
    super.key,
    required this.filter,
    required this.expanded,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupActive = filter != MusicHomeFilter.all;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: context.l10n.all,
          selected: filter == MusicHomeFilter.all,
          onTap: () => onSelected(MusicHomeFilter.all),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: groupActive
                ? cs.primary
                : cs.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                label: context.l10n.music,
                selected: filter == MusicHomeFilter.music,
                groupActive: groupActive,
                onTap: () => onSelected(MusicHomeFilter.music),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: expanded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1,
                            height: 18,
                            color: cs.onPrimary.withValues(alpha: 0.22),
                          ),
                          _Segment(
                            label: context.l10n.following,
                            selected: filter == MusicHomeFilter.following,
                            groupActive: groupActive,
                            onTap: () => onSelected(MusicHomeFilter.following),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : cs.surfaceContainerHigh.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool groupActive;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.groupActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = groupActive ? cs.onPrimary : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected
              ? foreground.withValues(alpha: groupActive ? 0.18 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? foreground
                  : foreground.withValues(alpha: groupActive ? 0.78 : 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
