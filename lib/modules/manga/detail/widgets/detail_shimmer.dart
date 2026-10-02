import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer building blocks used by the manga/anime detail screen.
//
// The goal is a *detailed* skeleton: the real layout is drawn with grey blocks
// that sweep with a light gradient until the real data/image arrives, instead
// of a flat pulsing rectangle.
// ─────────────────────────────────────────────────────────────────────────────

class DetailShimmer {
  DetailShimmer._();

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color baseColor(BuildContext context) => isLight(context)
      ? const Color(0xFFE1E4EA)
      : const Color(0xFF23232B);

  static Color highlightColor(BuildContext context) => isLight(context)
      ? const Color(0xFFF7F8FB)
      : const Color(0xFF37373F);
}

/// A single shimmering block (text line, chip, cover placeholder…).
class DetailShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  const DetailShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: DetailShimmer.baseColor(context),
      highlightColor: DetailShimmer.highlightColor(context),
      period: const Duration(milliseconds: 1300),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        alignment: child == null ? null : Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// Detailed skeleton for the hero (cover + back drop) area: a big cover block
/// plus the title/author/status lines and the action row underneath.
class DetailHeroShimmer extends StatelessWidget {
  final double height;
  final bool compact;

  const DetailHeroShimmer({
    super.key,
    this.height = 300,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: DetailShimmer.baseColor(context),
      highlightColor: DetailShimmer.highlightColor(context),
      period: const Duration(milliseconds: 1300),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(13, compact ? 24 : 60, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cover
                Container(
                  width: 98,
                  height: 148,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title (2 lines)
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 16,
                        width: 140,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 14),
                      // Author
                      Container(
                        height: 11,
                        width: 110,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      // Status + source
                      Container(
                        height: 11,
                        width: 170,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action row (Favoris / Webview / Trackers)
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Description lines
            Container(height: 10, width: double.infinity, color: Colors.white),
            const SizedBox(height: 6),
            Container(height: 10, width: 220, color: Colors.white),
            const SizedBox(height: 12),
            // Tabs
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Container(
                    height: 12,
                    width: i == 0 ? 74 : 56,
                    color: Colors.white,
                  ),
                  if (i < 2) const SizedBox(width: 22),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Image with a detailed shimmer placeholder while it loads.
///
/// Works with any [ImageProvider] (network, memory, extended network …),
/// fades the image in once decoded and falls back to a placeholder on error.
class DetailShimmerImage extends StatelessWidget {
  final ImageProvider? imageProvider;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context)? errorBuilder;

  /// Optional wrapper applied to the decoded image only (for example an
  /// overlay/scrim). The placeholder is rendered on its own so the skeleton
  /// is never dimmed by that overlay.
  final Widget Function(BuildContext context, Widget image)? loadedBuilder;
  final Duration fadeDuration;

  const DetailShimmerImage({
    super.key,
    required this.imageProvider,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholderBuilder,
    this.errorBuilder,
    this.loadedBuilder,
    this.fadeDuration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;
    final placeholder =
        placeholderBuilder?.call(context) ??
        DetailShimmerBox(width: width, height: height, radius: 6);

    Widget content;
    if (provider == null) {
      content = placeholder;
    } else {
      content = Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final loaded = loadedBuilder?.call(context, child) ?? child;
          if (wasSynchronouslyLoaded) return loaded;
          return AnimatedSwitcher(
            duration: fadeDuration,
            child: frame != null
                ? KeyedSubtree(key: const ValueKey('image'), child: loaded)
                : KeyedSubtree(
                    key: const ValueKey('placeholder'),
                    child: placeholder,
                  ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            errorBuilder?.call(context) ??
            Container(
              width: width,
              height: height,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Broken.image,
                size: 28,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
      );
    }

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}
