import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// Visual primitives copied from FlixQuest's app_ui_components.dart.
/// Data and navigation remain Watchtower-owned.
abstract final class AppUI {
  static const double phonePadding = 20;
  static const double tabletPadding = 28;
  static const double cardRadius = 14;
  static const double mediaGridCrossAxisSpacing = 12;
  static const double mediaGridTitleGap = 9;
  static const double mediaGridTitleHeight = 36;
  static const double posterAspectRatio = 2 / 3;

  static double pagePadding(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 700
        ? tabletPadding
        : phonePadding;
  }

  static int mediaGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 650) return 4;
    return 3;
  }

  static double mediaGridChildAspectRatio(BuildContext context) {
    final columns = mediaGridColumns(context);
    final gridWidth =
        MediaQuery.sizeOf(context).width -
        (pagePadding(context) * 2) -
        (mediaGridCrossAxisSpacing * (columns - 1));
    final itemWidth = gridWidth / columns;
    final itemHeight =
        (itemWidth / posterAspectRatio) +
        mediaGridTitleGap +
        mediaGridTitleHeight;
    return itemWidth / itemHeight;
  }

  static double horizontalCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 118;
    if (width >= 650) return 108;
    return ((width - (pagePadding(context) * 2) - 30) / 4).clamp(72.0, 100.0);
  }
}

/// The original FlixQuest swipe-and-crossfade carousel behavior.
class AppCrossfadeCarousel extends StatefulWidget {
  const AppCrossfadeCarousel({
    required this.itemCount,
    required this.itemBuilder,
    this.onItemTap,
    this.interval = const Duration(seconds: 7),
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemTap;
  final Duration interval;

  @override
  State<AppCrossfadeCarousel> createState() => _AppCrossfadeCarouselState();
}

class _AppCrossfadeCarouselState extends State<AppCrossfadeCarousel> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AppCrossfadeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.itemCount) _index = 0;
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.itemCount <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance(1));
  }

  void _advance(int direction) {
    if (!mounted || widget.itemCount <= 1) return;
    setState(() {
      _index = (_index + direction) % widget.itemCount;
      if (_index < 0) _index = widget.itemCount - 1;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(_index),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 120) return;
        _advance(velocity < 0 ? 1 : -1);
        _restartTimer();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 850),
        reverseDuration: const Duration(milliseconds: 650),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.025, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: widget.itemBuilder(context, _index),
        ),
      ),
    );
  }
}

class AppFeedOverlayHeader extends StatelessWidget {
  const AppFeedOverlayHeader({
    required this.title,
    required this.onSearchPressed,
    this.actionLabel,
    this.actionIcon,
    this.onActionPressed,
    this.utilityIcon,
    this.utilityTooltip,
    this.onUtilityPressed,
    super.key,
  });

  final String title;
  final VoidCallback? onSearchPressed;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;
  final IconData? utilityIcon;
  final String? utilityTooltip;
  final VoidCallback? onUtilityPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppUI.pagePadding(context) - 8,
              right: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onActionPressed != null)
                  TextButton.icon(
                    onPressed: onActionPressed,
                    icon: Icon(actionIcon, size: 19),
                    label: Text(actionLabel ?? ''),
                  ),
                if (onUtilityPressed != null)
                  IconButton(
                    tooltip: utilityTooltip,
                    onPressed: onUtilityPressed,
                    icon: Icon(utilityIcon),
                  ),
                IconButton(
                  onPressed: onSearchPressed,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppUI.pagePadding(context), 24, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class AppRatingBadge extends StatelessWidget {
  const AppRatingBadge({required this.rating, this.compact = false, super.key});

  final num? rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = rating == null
        ? '—'
        : rating! % 1 == 0
        ? rating!.toInt().toString()
        : rating!.toStringAsFixed(1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        child: Text(
          value,
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: compact ? 11 : 12,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class AppGenreTile extends StatelessWidget {
  const AppGenreTile({
    required this.label,
    required this.onTap,
    this.imageUrl,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              ExtendedImage.network(
                imageUrl!,
                fit: BoxFit.cover,
                cache: true,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.completed) {
                    return null;
                  }
                  return ColoredBox(color: colors.surfaceContainerHigh);
                },
              )
            else
              ColoredBox(color: colors.surfaceContainerHigh),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppShimmerBlock extends StatelessWidget {
  const AppShimmerBlock({this.radius = 14, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
