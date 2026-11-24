import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';

class UniversalImage extends HookWidget {
  final String path;
  final double? height;
  final double? width;
  final double scale;
  final String? placeholder;
  final BoxFit? fit;
  const UniversalImage({
    required this.path,
    this.height,
    this.width,
    this.placeholder,
    this.fit,
    this.scale = 1,
    super.key,
  });

  static ImageProvider imageProvider(
    String path, {
    final double? height,
    final double? width,
    final double scale = 1,
  }) {
    if (path.startsWith("http")) {
      return CachedNetworkImageProvider(
        path,
        maxHeight: _cachePixels(height),
        maxWidth: _cachePixels(width),
        cacheKey: path,
        scale: scale,
      );
    } else if (path.startsWith("assets/")) {
      return AssetImage(path);
    } else if (Uri.tryParse(path) != null) {
      return FileImage(File(path), scale: scale);
    }
    return MemoryImage(base64Decode(path), scale: scale);
  }

  /// Cache dimensions must be finite positive pixels: callers routinely pass
  /// `double.infinity` (or a NaN from a bad layout ratio) to mean "fill", and
  /// `double.toInt()` throws `Unsupported operation: Infinity or NaN toInt`
  /// inside `build()`, which crashes the widget instead of the image.
  static int? _cachePixels(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value.round();
  }

  /// Same guard for the widget box: an infinite box makes the render object
  /// assert during layout.
  static double? _boxPixels(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (path.startsWith("http")) {
      return FadeInImage(
        image: CachedNetworkImageProvider(
          path,
          maxHeight: _cachePixels(height),
          maxWidth: _cachePixels(width),
          cacheKey: path,
          scale: scale,
        ),
        height: _boxPixels(height),
        width: _boxPixels(width),
        placeholder: AssetImage(placeholder ?? Assets.images.placeholder.path),
        imageErrorBuilder: (context, error, stackTrace) {
          return _placeholderWidget();
        },
        fit: fit,
      );
    } else if (Uri.tryParse(path) != null && !path.startsWith("assets")) {
      return Image.file(
        File(path),
        width: _boxPixels(width),
        height: _boxPixels(height),
        cacheWidth: _cachePixels(width),
        cacheHeight: _cachePixels(height),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholderWidget(),
      );
    } else if (path.startsWith("assets")) {
      return Image.asset(
        path,
        width: _boxPixels(width),
        height: _boxPixels(height),
        cacheWidth: _cachePixels(width),
        cacheHeight: _cachePixels(height),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholderWidget(),
      );
    }

    return Image.memory(
      base64Decode(path),
      width: _boxPixels(width),
      height: _boxPixels(height),
      cacheWidth: _cachePixels(width),
      cacheHeight: _cachePixels(height),
      scale: scale,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholderWidget(),
    );
  }

  Widget _placeholderWidget() {
    return Image.asset(
      placeholder ?? Assets.images.placeholder.path,
      width: _boxPixels(width),
      height: _boxPixels(height),
      cacheWidth: _cachePixels(width),
      cacheHeight: _cachePixels(height),
      scale: scale,
    );
  }
}
