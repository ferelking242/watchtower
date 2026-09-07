// Adapted from flutter_netflix — poster_image.dart
// Movie.posterPath + TMDB URL → MManga.imageUrl (direct URL).
// Replaces Image.asset('netflix_symbol.png') with a dark placeholder.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class NfPosterImage extends StatelessWidget {
  const NfPosterImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.original  = false,
    this.backdrop  = false,
    this.fit       = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });

  final String?       imageUrl;
  final double?       width;
  final double?       height;
  final BorderRadius? borderRadius;
  final bool          original;
  final bool          backdrop;
  final BoxFit        fit;
  final Alignment     alignment;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl?.isNotEmpty ?? false) ? imageUrl! : null;
    final br  = borderRadius ?? BorderRadius.circular(8.0);

    if (url == null) return _placeholder(br);

    return CachedNetworkImage(
      imageUrl:     url,
      imageBuilder: (_, imageProvider) => ClipRRect(
        borderRadius: br,
        child: Image(
          image:     imageProvider,
          fit:       fit,
          width:     width,
          height:    height,
          alignment: alignment,
        ),
      ),
      placeholder: (_, __) => Skeletonizer(
        enabled: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: br,
            color:        Colors.grey[900],
          ),
          width:  width  ?? (original || backdrop ? double.infinity : 150.0),
          height: height ?? (original || backdrop ? 300.0 : 68.0),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(br),
    );
  }

  Widget _placeholder(BorderRadius br) => Container(
    width:  width  ?? 110.0,
    height: height ?? 220.0,
    decoration: BoxDecoration(
      borderRadius: br,
      color:        Colors.grey[900],
    ),
    child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 42),
  );
}
