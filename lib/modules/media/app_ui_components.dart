import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/utils/cached_network.dart';

/// Device tier used by every responsive helper in [AppUI].
enum AppDeviceKind { phone, tablet, desktop, tv }

/// Shared visual primitives for the media, watch and discovery surfaces.
/// Data and navigation remain Watchtower-owned.
abstract final class AppUI {
  static const double phonePadding = 20;
  static const double tabletPadding = 28;
  static const double desktopPadding = 44;
  static const double tvPadding = 64;
  static const double cardRadius = 14;
  static const double mediaGridCrossAxisSpacing = 12;
  static const double mediaGridTitleGap = 9;
  static const double mediaGridTitleHeight = 36;
  static const double posterAspectRatio = 2 / 3;

  /// Device tier from the layout width. Android TV renders its 10-foot UI
  /// at 960–1920dp wide; the `tv` tier starts at 1600dp where bigger padding
  /// and rail scaling genuinely help readability across the room.
  static AppDeviceKind device(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1600) return AppDeviceKind.tv;
    if (width >= 1024) return AppDeviceKind.desktop;
    if (width >= 600) return AppDeviceKind.tablet;
    return AppDeviceKind.phone;
  }

  static bool isPhone(BuildContext context) =>
      device(context) == AppDeviceKind.phone;

  static bool isTablet(BuildContext context) =>
      device(context) == AppDeviceKind.tablet;

  static bool isDesktop(BuildContext context) =>
      device(context) == AppDeviceKind.desktop;

  static bool isTv(BuildContext context) => device(context) == AppDeviceKind.tv;

  /// Desktop + TV: wider rails, more grid columns, larger paddings.
  static bool isLargeScreen(BuildContext context) {
    final kind = device(context);
    return kind == AppDeviceKind.desktop || kind == AppDeviceKind.tv;
  }

  static double pagePadding(BuildContext context) => switch (device(context)) {
    AppDeviceKind.tv => tvPadding,
    AppDeviceKind.desktop => desktopPadding,
    AppDeviceKind.tablet => tabletPadding,
    AppDeviceKind.phone => phonePadding,
  };

  static int mediaGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 2000) return 8;
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
    if (width >= 1400) return 138;
    if (width >= 900) return 118;
    if (width >= 650) return 108;
    return ((width - (pagePadding(context) * 2) - 30) / 4).clamp(72.0, 100.0);
  }

  /// 16:9 landscape rail cards (ScrollingLandscapeMovies and friends).
  static double landscapeCardWidth(BuildContext context) =>
      switch (device(context)) {
        AppDeviceKind.tv => 300,
        AppDeviceKind.desktop => 268,
        AppDeviceKind.tablet => 252,
        AppDeviceKind.phone => 238,
      };

  /// Ranked poster rails: card width plus the matching rail height.
  static double rankedCardWidth(BuildContext context) =>
      switch (device(context)) {
        AppDeviceKind.tv => 148,
        AppDeviceKind.desktop => 128,
        AppDeviceKind.tablet => 118,
        AppDeviceKind.phone => 110,
      };

  static double rankedRailHeight(BuildContext context) =>
      rankedCardWidth(context) * 1.5 + 28;
}

@immutable
class AppLoadingColors {
  const AppLoadingColors({
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const dark = AppLoadingColors(
    shimmerBase: Color(0xFF292D31),
    shimmerHighlight: Color(0xFF30353A),
  );

  static const light = AppLoadingColors(
    shimmerBase: Color(0xFFE9EBEE),
    shimmerHighlight: Color(0xFFEFF1F3),
  );

  final Color shimmerBase;
  final Color shimmerHighlight;

  static AppLoadingColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Shared swipe-and-crossfade carousel behavior.
class AppCrossfadeCarousel extends StatefulWidget {
  const AppCrossfadeCarousel({
    required this.itemCount,
    required this.itemBuilder,
    this.onItemTap,
    this.interval = const Duration(seconds: 7),
    this.clipRadius = 24,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemTap;
  final Duration interval;

  /// Corner radius of the clip. Set to 0 to disable clipping entirely so
  /// hero decorations (e.g. the bottom-edge notch) may overhang the bounds.
  final double clipRadius;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.clipRadius),
        clipBehavior: widget.clipRadius <= 0 ? Clip.none : Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
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
            if (widget.itemCount > 1)
              Positioned(
                right: 18,
                bottom: 16,
                child: IgnorePointer(
                  child: _CarouselDots(count: widget.itemCount, index: _index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final visibleCount = count.clamp(1, 7).toInt();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var dot = 0; dot < visibleCount; dot++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(right: dot == visibleCount - 1 ? 0 : 5),
                width: dot == index % visibleCount ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: dot == index % visibleCount
                      ? Colors.white
                      : Colors.white.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
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
                  icon: const Icon(Broken.search_normal),
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
            TextButton.icon(
              onPressed: onAction,
              icon: Text(
                actionLabel == 'View all' || actionLabel == 'All >'
                    ? 'All'
                    : actionLabel!,
              ),
              label: const Icon(Broken.arrow_right_3, size: 17),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

/// Cinematic hero play button with a notch (half-circle cut) carved out of
/// the hero's bottom edge, in the style of the French-Stream home hero: the
/// image continues behind a circular cut-out and a ringed play disc sits in
/// it, straddling the hero's bottom border.
///
/// Wrap it inside a [Stack] that is allowed to paint outside its bounds
/// (e.g. the hero of a feed) — the widget itself only draws the ring + icon.
class AppHeroPlayButton extends StatelessWidget {
  const AppHeroPlayButton({required this.onTap, this.size = 62, super.key});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: .55),
            border: Border.all(
              color: Colors.white.withValues(alpha: .85),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * .52,
          ),
        ),
      ),
    );
  }
}

/// A circular cut-out ("notch") that visually bites into the bottom edge of
/// a hero image. Paint it at the bottom-center of the hero stack: it draws
/// the page background over the image inside the circle and a thin arc of
/// the ring color around it, producing the half-circle carved effect.
class AppHeroNotch extends StatelessWidget {
  const AppHeroNotch({
    required this.backgroundColor,
    this.radius = 34,
    this.ringColor = Colors.white,
    super.key,
  });

  final Color backgroundColor;
  final double radius;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NotchPainter(bg: backgroundColor, ring: ringColor),
      ),
    );
  }
}

class _NotchPainter extends CustomPainter {
  _NotchPainter({required this.bg, required this.ring});

  final Color bg;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = ring.withValues(alpha: .85);
    canvas.drawCircle(center, radius, ringPaint);

    final bgPaint = Paint()..color = bg;
    canvas.drawCircle(center, radius - 1.6, bgPaint);
  }

  @override
  bool shouldRepaint(_NotchPainter oldDelegate) =>
      oldDelegate.bg != bg || oldDelegate.ring != ring;
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
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageUrl;

  /// Leading icon shown with the label (e.g. a provider logo).
  final IconData? icon;

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
              cachedNetworkImage(
                imageUrl: imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget: ColoredBox(color: colors.surfaceContainerHigh),
              )
            else
              ColoredBox(
                color: colors.surfaceContainerHigh,
                child: Center(
                  child: Icon(
                    Broken.video,
                    color: Colors.white.withValues(alpha: .42),
                    size: 27,
                  ),
                ),
              ),
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
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                    const SizedBox(width: 6),
                  ],
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
                    Broken.arrow_right_3,
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

class AppHeroShimmer extends StatelessWidget {
  const AppHeroShimmer({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return SizedBox(
      height: height,
      child: Shimmer.fromColors(
        baseColor: colors.shimmerBase,
        highlightColor: colors.shimmerHighlight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.shimmerBase),
            Positioned(
              top: 12,
              left: AppUI.phonePadding,
              right: AppUI.phonePadding,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _ShimmerBlock(
                      width: 30,
                      height: 30,
                      color: colors.shimmerBase,
                      radius: 15,
                    ),
                    const Spacer(),
                    _ShimmerBlock(
                      width: 76,
                      height: 38,
                      color: colors.shimmerBase,
                      radius: 20,
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBlock(
                      width: 40,
                      height: 40,
                      color: colors.shimmerBase,
                      radius: 20,
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBlock(
                      width: 40,
                      height: 40,
                      color: colors.shimmerBase,
                      radius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppUI.phonePadding,
              right: AppUI.phonePadding,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBlock(
                    width: 210,
                    height: 30,
                    color: colors.shimmerBase,
                  ),
                  const SizedBox(height: 10),
                  _ShimmerBlock(
                    width: 150,
                    height: 14,
                    color: colors.shimmerBase,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _ShimmerBlock(
                        width: 112,
                        height: 44,
                        color: colors.shimmerBase,
                      ),
                      const SizedBox(width: 12),
                      _ShimmerBlock(
                        width: 112,
                        height: 44,
                        color: colors.shimmerBase,
                      ),
                    ],
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

class AppMediaRowShimmer extends StatelessWidget {
  const AppMediaRowShimmer({this.itemWidth, super.key});

  final double? itemWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    final cardWidth = itemWidth ?? AppUI.horizontalCardWidth(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => SizedBox(
          width: cardWidth,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: _ShimmerBlock(
                  width: cardWidth,
                  height: double.infinity,
                  color: colors.shimmerBase,
                  radius: AppUI.cardRadius,
                ),
              ),
              const SizedBox(height: 10),
              _ShimmerBlock(
                width: cardWidth * .82,
                height: 13,
                color: colors.shimmerBase,
              ),
              const SizedBox(height: 6),
              _ShimmerBlock(
                width: cardWidth * .55,
                height: 11,
                color: colors.shimmerBase,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppMediaGridShimmer extends StatelessWidget {
  const AppMediaGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    final columns = AppUI.mediaGridColumns(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          12,
          AppUI.pagePadding(context),
          24,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
          crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
          mainAxisSpacing: 16,
        ),
        itemCount: columns * 4,
        itemBuilder: (_, __) => Column(
          children: [
            AspectRatio(
              aspectRatio: AppUI.posterAspectRatio,
              child: _ShimmerBlock(
                width: double.infinity,
                height: double.infinity,
                color: colors.shimmerBase,
                radius: AppUI.cardRadius,
              ),
            ),
            const SizedBox(height: AppUI.mediaGridTitleGap),
            SizedBox(
              height: AppUI.mediaGridTitleHeight,
              child: Column(
                children: [
                  FractionallySizedBox(
                    widthFactor: .84,
                    child: _ShimmerBlock(
                      width: double.infinity,
                      height: 13,
                      color: colors.shimmerBase,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ShimmerBlock(
                    width: 54,
                    height: 11,
                    color: colors.shimmerBase,
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

class AppGenreGridShimmer extends StatelessWidget {
  const AppGenreGridShimmer({this.isTv = false, super.key});

  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: isTv ? 'TV genres' : 'Genres',
          actionLabel: 'All >',
        ),
        SizedBox(
          height: 164,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisExtent: 154,
              mainAxisSpacing: 12,
            ),
            itemCount: 8,
            itemBuilder: (_, __) => const AppGenreTileShimmer(),
          ),
        ),
      ],
    );
  }
}

class AppGenreTileShimmer extends StatelessWidget {
  const AppGenreTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.shimmerBase),
            Positioned(
              left: 12,
              bottom: 10,
              child: _ShimmerBlock(
                width: 82,
                height: 13,
                color: colors.shimmerBase,
                radius: 6,
              ),
            ),
            Positioned(
              right: 10,
              bottom: 9,
              child: _ShimmerBlock(
                width: 18,
                height: 18,
                color: colors.shimmerBase,
                radius: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppStreamingServicesShimmer extends StatelessWidget {
  const AppStreamingServicesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Streaming services'),
        SizedBox(
          height: 132,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 2,
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const AppStreamingServiceTileShimmer(),
          ),
        ),
      ],
    );
  }
}

class AppStreamingServiceTileShimmer extends StatelessWidget {
  const AppStreamingServiceTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return SizedBox(
      width: 96,
      child: Shimmer.fromColors(
        baseColor: colors.shimmerBase,
        highlightColor: colors.shimmerHighlight,
        child: Column(
          children: [
            _ShimmerBlock(
              width: 88,
              height: 88,
              color: colors.shimmerBase,
              radius: 22,
            ),
            const SizedBox(height: 8),
            _ShimmerBlock(
              width: 72,
              height: 11,
              color: colors.shimmerBase,
              radius: 6,
            ),
            const SizedBox(height: 6),
            _ShimmerBlock(
              width: 48,
              height: 10,
              color: colors.shimmerBase,
              radius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class AppLandscapeRowShimmer extends StatelessWidget {
  const AppLandscapeRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SizedBox(
          width: 238,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBlock(
                width: 238,
                height: 124,
                color: colors.shimmerBase,
                radius: AppUI.cardRadius,
              ),
              const SizedBox(height: 9),
              _ShimmerBlock(width: 180, height: 12, color: colors.shimmerBase),
            ],
          ),
        ),
      ),
    );
  }
}

class AppRankedRowShimmer extends StatelessWidget {
  const AppRankedRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ShimmerBlock(
                      width: 110,
                      height: double.infinity,
                      color: colors.shimmerBase,
                      radius: 12,
                    ),
                    Positioned(
                      left: 4,
                      bottom: -4,
                      child: _ShimmerBlock(
                        width: 30,
                        height: 52,
                        color: colors.shimmerHighlight,
                        radius: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _ShimmerBlock(width: 84, height: 11, color: colors.shimmerBase),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBannerRowShimmer extends StatelessWidget {
  const AppBannerRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppLoadingColors.of(context);
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            index == 0 ? 0 : 12,
            AppUI.pagePadding(context),
            0,
          ),
          child: AspectRatio(
            aspectRatio: 2.05,
            child: Shimmer.fromColors(
              baseColor: colors.shimmerBase,
              highlightColor: colors.shimmerHighlight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ShimmerBlock(
                    width: double.infinity,
                    height: double.infinity,
                    color: colors.shimmerBase,
                    radius: 18,
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: _ShimmerBlock(
                      width: 140,
                      height: 14,
                      color: colors.shimmerBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Broken.video,
                  size: 52,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MediaHomeLoading extends StatelessWidget {
  const MediaHomeLoading({
    required this.isSeries,
    this.onSearchPressed,
    this.onLiveTVPressed,
    this.onBookmarksPressed,
    this.onRefresh,
    super.key,
  });

  final bool isSeries;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTVPressed;
  final VoidCallback? onBookmarksPressed;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = isSeries ? 'Series' : 'Movies';
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFeedOverlayHeader(
              title: title,
              onSearchPressed: onSearchPressed,
              actionLabel: 'Live TV',
              actionIcon: Broken.radio,
              onActionPressed: onLiveTVPressed,
              utilityIcon: Broken.bookmark,
              utilityTooltip: 'Bookmarks',
              onUtilityPressed: onBookmarksPressed,
            ),
            AppHeroShimmer(
              height: (MediaQuery.sizeOf(context).height * .48).clamp(
                410.0,
                500.0,
              ),
            ),
            for (final sectionTitle in const [
              'Popular',
              'Trending this week',
              'Top rated',
            ]) ...[
              AppSectionHeader(title: sectionTitle, actionLabel: 'All >'),
              SizedBox(
                height: AppUI.horizontalCardWidth(context) * 1.5 + 46,
                child: const AppMediaRowShimmer(),
              ),
            ],
            for (final sectionTitle
                in isSeries
                    ? const ['Airing today', 'On the air']
                    : const ['Now playing', 'Upcoming']) ...[
              AppSectionHeader(title: sectionTitle, actionLabel: 'All >'),
              const SizedBox(height: 158, child: AppLandscapeRowShimmer()),
            ],
            if (!isSeries) ...[
              const AppSectionHeader(title: 'Top 10 cette semaine'),
              const SizedBox(height: 208, child: AppRankedRowShimmer()),
              const AppSectionHeader(title: 'À découvrir'),
              const SizedBox(height: 172, child: AppLandscapeRowShimmer()),
              const AppSectionHeader(title: 'À voir ce soir'),
              const AppBannerRowShimmer(),
            ],
            AppGenreGridShimmer(isTv: isSeries),
            if (!isSeries) const AppStreamingServicesShimmer(),
            const SizedBox(height: 112),
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
    final colors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Focusable pressable wrapper: catalogue cards become reachable with the
/// D-pad / remote on Android TV, and a focus ring marks the highlighted
/// card. On touch devices it behaves exactly like a GestureDetector.
/// The ring is drawn with `foregroundDecoration`, so it never shifts layout.
class TvPressable extends StatefulWidget {
  const TvPressable({
    required this.child,
    this.onTap,
    this.borderRadius = 14,
    this.focusScale = 1.03,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  /// Grow factor while focused; pass 1.0 to keep the size untouched.
  final double focusScale;

  @override
  State<TvPressable> createState() => _TvPressableState();
}

class _TvPressableState extends State<TvPressable> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'TvPressable');

  static const _activateKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  ];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final onTap = widget.onTap;
    if (onTap == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (_activateKeys.contains(event.logicalKey)) {
        onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) return widget.child;
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: focused ? widget.focusScale : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: focused ? accent : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: .40),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : const [],
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}
