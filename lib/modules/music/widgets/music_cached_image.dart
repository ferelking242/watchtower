import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

class MusicCachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final BoxFit fit;

  const MusicCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.placeholder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: cs.surfaceContainerHigh,
        child: Center(
          child: placeholder ??
              Icon(Icons.music_note_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
        ),
      );
    }

    return ExtendedImage.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cache: true,
      loadStateChanged: (state) {
        return switch (state.extendedImageLoadState) {
          LoadState.loading => Container(
              width: width,
              height: height,
              color: cs.surfaceContainerHigh,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          LoadState.failed => Container(
              width: width,
              height: height,
              color: cs.surfaceContainerHigh,
              child: Center(
                child: placeholder ??
                    Icon(Icons.music_note_rounded,
                        color: cs.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          _ => null,
        };
      },
    );
  }
}
