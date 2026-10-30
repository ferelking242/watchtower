import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Full-screen pinch-to-zoom viewer for a single still.
///
/// Shared by the watch detail poster, the comment artwork and any other place
/// that wants to inspect an image. It exists so the behaviour is defined once
/// instead of being re-tuned at every call site, and it improves on the plain
/// `PhotoView` dialog in three ways:
///
///  * double-tap walks contained → covered → **1:1** → contained. The 1:1 step
///    matters for extension artwork: XNXX stills are 600x337 on the card but
///    2080x1170 on the hero rendition, and a scale capped at the viewport
///    never shows that native detail.
///  * the pinch ceiling is 8x the covered scale instead of 5x.
///  * the caption bar carries the title plus a close control, so a TV remote
///    (which has no pinch and no tap-outside) can still leave the viewer.
Future<void> showZoomableImage(
  BuildContext context, {
  required ImageProvider imageProvider,
  String? title,
  String? heroTag,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    barrierDismissible: true,
    useSafeArea: false,
    builder: (_) => ZoomableImageViewer(
      imageProvider: imageProvider,
      title: title,
      heroTag: heroTag,
    ),
  );
}

/// The widget behind [showZoomableImage]; public so a screen can embed it
/// directly (a gallery page, a split view) instead of pushing a dialog.
class ZoomableImageViewer extends StatefulWidget {
  const ZoomableImageViewer({
    super.key,
    required this.imageProvider,
    this.title,
    this.heroTag,
    this.backgroundDecoration = const BoxDecoration(color: Colors.black),
  });

  final ImageProvider imageProvider;
  final String? title;

  /// When set, the artwork flies in from the card that opened the viewer.
  final String? heroTag;

  final BoxDecoration backgroundDecoration;

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer> {
  final PhotoViewController _controller = PhotoViewController();
  final PhotoViewScaleStateController _scaleController =
      PhotoViewScaleStateController();

  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Double-tap cycle. `covering` fills the viewport, `originalSize` is the
  /// 1:1 pixel rendition — the step that actually reveals detail.
  PhotoViewScaleState _nextScaleState(PhotoViewScaleState actual) {
    switch (actual) {
      case PhotoViewScaleState.initial:
        return PhotoViewScaleState.covering;
      case PhotoViewScaleState.covering:
        return PhotoViewScaleState.originalSize;
      case PhotoViewScaleState.originalSize:
      case PhotoViewScaleState.zoomedIn:
      case PhotoViewScaleState.zoomedOut:
        return PhotoViewScaleState.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget image = PhotoView(
      imageProvider: widget.imageProvider,
      backgroundDecoration: widget.backgroundDecoration,
      controller: _controller,
      scaleStateController: _scaleController,
      scaleStateCycle: _nextScaleState,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 8,
      initialScale: PhotoViewComputedScale.contained,
      scaleStateChangedCallback: (state) {
        final zoomed = state != PhotoViewScaleState.initial;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      },
      loadingBuilder: (context, event) => _ZoomLoading(event: event),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white38,
          size: 48,
        ),
      ),
    );

    final heroTag = widget.heroTag;
    if (heroTag != null) {
      image = Hero(tag: heroTag, child: image);
    }

    return GestureDetector(
      // Tapping the surround dismisses. A double tap is claimed by PhotoView,
      // so this only fires for a genuine single tap.
      onTap: () => Navigator.of(context).maybePop(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ZoomTopBar(
              title: widget.title,
              showReset: _zoomed,
              onReset: () {
                _scaleController.scaleState = PhotoViewScaleState.initial;
              },
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomTopBar extends StatelessWidget {
  const _ZoomTopBar({
    required this.title,
    required this.showReset,
    required this.onReset,
    required this.onClose,
  });

  final String? title;
  final bool showReset;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _ZoomAction(
              icon: Icons.close_rounded,
              tooltip: 'Fermer',
              onTap: onClose,
            ),
            if (label != null && label.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            if (showReset)
              _ZoomAction(
                icon: Icons.zoom_out_map_rounded,
                tooltip: 'Taille réelle',
                onTap: onReset,
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomAction extends StatelessWidget {
  const _ZoomAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _ZoomLoading extends StatelessWidget {
  const _ZoomLoading({required this.event});

  final ImageChunkEvent? event;

  @override
  Widget build(BuildContext context) {
    final expected = event?.expectedTotalBytes;
    final loaded = event?.cumulativeBytesLoaded;
    final progress = (expected != null && expected > 0 && loaded != null)
        ? (loaded / expected).clamp(0.0, 1.0)
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            Text(
              '${(progress * 100).round()} %',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
