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
  Widget errorWidget = const Icon(Icons.error, size: 50),
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
  Widget errorWidget = const Icon(Icons.error, size: 50),
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
      if (state.extendedImageLoadState == LoadState.failed) {
        return errorWidget;
      }
      return null;
    },
  );
}
