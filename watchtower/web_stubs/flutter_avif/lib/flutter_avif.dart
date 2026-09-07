// Web stub for flutter_avif — AVIF images displayed as unsupported on Flutter Web.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

class AvifImage extends StatelessWidget {
  final ImageProvider image;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const AvifImage({super.key, required this.image, this.width, this.height, this.fit});

  factory AvifImage.file(File file, {
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
    double scale = 1.0,
  }) =>
      AvifImage(
        key: key,
        image: FileImage(file, scale: scale),
        width: width,
        height: height,
        fit: fit,
      );

  factory AvifImage.asset(String name, {
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
  }) =>
      AvifImage(
        key: key,
        image: AssetImage(name),
        width: width,
        height: height,
        fit: fit,
      );

  factory AvifImage.network(String src, {
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
  }) =>
      AvifImage(
        key: key,
        image: NetworkImage(src),
        width: width,
        height: height,
        fit: fit,
      );

  factory AvifImage.memory(Uint8List bytes, {
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
  }) =>
      AvifImage(
        key: key,
        image: MemoryImage(bytes),
        width: width,
        height: height,
        fit: fit,
      );

  @override
  Widget build(BuildContext context) => Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
      );
}

class FileAvifImage extends FileImage {
  FileAvifImage(super.file);
}
