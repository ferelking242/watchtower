import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';

Widget cachedNetworkImage({
  Map<String, String>? headers,
  required String imageUrl,
  required double? width,
  required double? height,
  required BoxFit? fit,
  AlignmentGeometry? alignment,
  bool useCustomNetworkImage = true,
  Widget errorWidget = const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.white38),
}) {
  if (kIsWeb) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment ?? Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }
  return ExtendedImage(
    image: useCustomNetworkImage
        ? CustomExtendedNetworkImageProvider(imageUrl, headers: headers)
        : ExtendedNetworkImageProvider(imageUrl, headers: headers),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    mode: ExtendedImageMode.none,
    handleLoadingProgress: true,
    loadStateChanged: (state) {
      if (state.extendedImageLoadState == LoadState.loading) {
        return const _SkeletonShimmer();
      }
      if (state.extendedImageLoadState == LoadState.failed) {
        return errorWidget;
      }
      return null;
    },
  );
}

Widget cachedCompressedNetworkImage({
  Map<String, String>? headers,
  required String imageUrl,
  required double? width,
  required double? height,
  required BoxFit? fit,
  AlignmentGeometry? alignment,
  bool useCustomNetworkImage = true,
  Widget errorWidget = const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.white38),
  int maxBytes = 5 << 10,
}) {
  if (kIsWeb) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment ?? Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }
  return ExtendedImage(
    image: ExtendedResizeImage(
      useCustomNetworkImage
          ? CustomExtendedNetworkImageProvider(imageUrl, headers: headers)
          : ExtendedNetworkImageProvider(imageUrl, headers: headers),
      maxBytes: maxBytes,
    ),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    mode: ExtendedImageMode.none,
    handleLoadingProgress: true,
    clearMemoryCacheWhenDispose: true,
    loadStateChanged: (state) {
      if (state.extendedImageLoadState == LoadState.loading) {
        return const _SkeletonShimmer();
      }
      if (state.extendedImageLoadState == LoadState.failed) {
        return errorWidget;
      }
      return null;
    },
  );
}

class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer();

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const _dark = Color(0xFF1A1A2E);
  static const _light = Color(0xFF3A3A5C);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        color: Color.lerp(_dark, _light, _anim.value),
      ),
    );
  }
}
