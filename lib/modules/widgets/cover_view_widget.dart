import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class CoverViewWidget extends StatelessWidget {
  final List<Widget> children;
  final bool? isLongPressed;
  final ImageProvider? image;
  final bool isComfortableGrid;
  final Widget? bottomTextWidget;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  const CoverViewWidget({
    super.key,
    required this.children,
    this.isComfortableGrid = false,
    this.bottomTextWidget,
    required this.onTap,
    this.image,
    this.onLongPress,
    this.isLongPressed,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Expanded(
            child: Material(
              borderRadius: BorderRadius.circular(5),
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                onSecondaryTap: onSecondaryTap,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Container(
                  color: isLongPressed != null && isLongPressed!
                      ? context.primaryColor.withValues(alpha: 0.4)
                      : Colors.transparent,
                  child: image == null
                      ? isComfortableGrid
                            ? Column(children: [...children, bottomTextWidget!])
                            : Stack(children: children)
                      : kIsWeb
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            const CoverShimmer(),
                            Positioned.fill(
                              child: Image(
                                image: image!,
                                fit: BoxFit.cover,
                                frameBuilder: (context, child, frame, sync) =>
                                    sync || frame != null
                                    ? child
                                    : const SizedBox.shrink(),
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            Stack(children: children),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            const CoverShimmer(),
                            Image(
                              image: image!,
                              fit: BoxFit.cover,
                              frameBuilder: (context, child, frame, sync) =>
                                  sync || frame != null
                                  ? child
                                  : const SizedBox.shrink(),
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            Stack(children: children),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (isComfortableGrid) bottomTextWidget!,
        ],
      ),
    );
  }
}

/// Shimmer painted under every library cover until its first frame lands.
class CoverShimmer extends StatelessWidget {
  const CoverShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF24282C) : const Color(0xFFE9EBEE),
      highlightColor: isDark
          ? const Color(0xFF30353A)
          : const Color(0xFFF4F6F8),
      child: const ColoredBox(color: Colors.white),
    );
  }
}
