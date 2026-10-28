import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/others.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/manga/reader/widgets/circular_progress_indicator_animate_rotate.dart';

class ImageViewVertical extends ConsumerStatefulWidget {
  final UChapDataPreload data;
  final Function(UChapDataPreload data) onLongPressData;
  final bool isHorizontal;

  final Function(bool) failedToLoadImage;

  const ImageViewVertical({
    super.key,
    required this.data,
    required this.onLongPressData,
    required this.failedToLoadImage,
    required this.isHorizontal,
  });

  @override
  ConsumerState<ImageViewVertical> createState() => _ImageViewVerticalState();
}

class _ImageViewVerticalState extends ConsumerState<ImageViewVertical> {
  UChapDataPreload get data => widget.data;
  bool get isHorizontal => widget.isHorizontal;
  Function(bool) get failedToLoadImage => widget.failedToLoadImage;
  Function(UChapDataPreload) get onLongPressData => widget.onLongPressData;

  /// True once the loaded image is wider than tall. Drives the "Pages" wide
  /// page options (panorama / split / rotate).
  bool _isWide = false;

  /// Natural width/height ratio of the loaded page, captured on first load.
  double _aspect = 1.0;

  // ── Per-page tracking so we don't spam the log on every loading-tick.
  // Keyed by (chapter URL + page index) so a chapter swap resets state.
  static final Set<String> _loggedLoaded = <String>{};
  static final Set<String> _loggedFailed = <String>{};

  String _key() {
    final chap = data.chapter?.url ?? data.chapter?.name ?? '?';
    return '$chap#${data.index ?? -1}';
  }

  String _label() {
    final n = (data.index ?? 0) + 1;
    final chapName = data.chapter?.name ?? '';
    return 'page $n${chapName.isEmpty ? '' : ' ($chapName)'}';
  }

  void _logLoaded() {
    final k = _key();
    if (_loggedLoaded.add(k)) {
      _loggedFailed.remove(k); // any subsequent retry that succeeds clears err
      AppLogger.log(
        'manga ${_label()} chargée',
        tag: LogTag.page,
        logLevel: LogLevel.debug,
      );
    }
  }

  void _logFailed() {
    final k = _key();
    if (_loggedFailed.add(k)) {
      _loggedLoaded.remove(k);
      AppLogger.log(
        'manga ${_label()} ÉCHEC — retry proposé à l\'utilisateur',
        tag: LogTag.page,
        logLevel: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);
    final panorama = ref.watch(panoramaImagesProvider);
    final splitWide = ref.watch(splitWidePagesProvider);
    final rotateWide = ref.watch(rotateWidePagesProvider);

    // "Rogner les bordures" is handled by the crop-image pipeline, which
    // replaces [data.cropImage]. Wide-page handling below only applies when the
    // page really is wider than tall and the user asked for it.
    Widget imageWidget = ExtendedImage(
      colorBlendMode: colorBlendMode,
      color: color,
      image: data.getImageProvider(ref, true),
      filterQuality: FilterQuality.medium,
      handleLoadingProgress: true,
      fit: rotateWide && _isWide
          ? BoxFit.contain
          : getBoxFit(ref.watch(scaleTypeStateProvider)),
      enableLoadState: true,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.completed) {
          failedToLoadImage(false);
          _logLoaded();
          final rawSize = state.extendedImageInfo?.image;
          if (rawSize != null) {
            final isWide = rawSize.width > rawSize.height;
            final aspect = rawSize.width / rawSize.height;
            if (isWide != _isWide && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isWide = isWide);
              });
            }
            _aspect = aspect;
            if (data.loadedHeight == null) {
              final screenWidth = isHorizontal
                  ? context.width(0.8)
                  : MediaQuery.of(context).size.width;
              data.loadedWidth = screenWidth;
              data.loadedHeight = screenWidth / aspect;
            }
          }
        }
        final placeholderHeight = data.loadedHeight ?? context.height(0.8);
        final placeholderWidth = isHorizontal
            ? (data.loadedWidth ?? context.width(0.8))
            : null;
        if (state.extendedImageLoadState == LoadState.loading) {
          final ImageChunkEvent? loadingProgress = state.loadingProgress;
          final double progress = loadingProgress?.expectedTotalBytes != null
              ? loadingProgress!.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
              : 0;
          return Container(
            color: Colors.black,
            height: placeholderHeight,
            width: placeholderWidth,
            child: CircularProgressIndicatorAnimateRotate(progress: progress),
          );
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          failedToLoadImage(true);
          _logFailed();
          return Container(
            color: Colors.black,
            height: placeholderHeight,
            width: placeholderWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.l10n.image_loading_error,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onLongPress: () {
                      state.reLoadImage();
                      failedToLoadImage(false);
                    },
                    onTap: () {
                      state.reLoadImage();
                      failedToLoadImage(false);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Text(context.l10n.retry),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return null;
      },
    );
    return applyReaderColorFilter(
      GestureDetector(
        onLongPress: () => onLongPressData.call(data),
        child: isHorizontal
            ? imageWidget
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (data.index == 0)
                    SizedBox(height: MediaQuery.of(context).padding.top),
                  _maybeWide(imageWidget, panorama, splitWide, rotateWide),
                ],
              ),
      ),
      ref,
    );
  }

  /// Applies the "Pages" wide-image options when the loaded page is wider than
  /// tall: split into two stacked halves, rotate to fit, or let the user pan
  /// horizontally. Falls back to the plain image otherwise.
  Widget _maybeWide(
    Widget image,
    bool panorama,
    bool splitWide,
    bool rotateWide,
  ) {
    if (!_isWide) return image;
    final screenW = MediaQuery.of(context).size.width;
    if (splitWide) {
      return Column(
        children: [
          _half(image, Alignment.centerLeft, screenW),
          _half(image, Alignment.centerRight, screenW),
        ],
      );
    }
    if (rotateWide) return RotatedBox(quarterTurns: 1, child: image);
    if (panorama && !isHorizontal) {
      // Twice-wide canvas so the spread can be dragged sideways while still
      // filling the viewport height.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: screenW * _aspect, child: image),
      );
    }
    return image;
  }

  Widget _half(Widget image, Alignment alignment, double screenW) {
    return ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.5,
        child: SizedBox(width: screenW * 2, child: image),
      ),
    );
  }
}