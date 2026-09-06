// Adapted from flutter_netflix — movie_box.dart
// Removed: BLoC, Movie model, TMDB URL, netflix_symbol asset, laughs counter.
// Added: MManga + Source, title overlay at bottom, tap → NfBottomSheet or direct nav.
import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'nf_bottom_sheet.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfMovieBox extends StatelessWidget {
  const NfMovieBox({
    super.key,
    required this.manga,
    required this.source,
    this.padding,
    this.fill = false,
  });

  final MManga      manga;
  final Source      source;
  final EdgeInsets? padding;
  final bool        fill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () => showModalBottomSheet(
          context:           context,
          useRootNavigator:  true,
          backgroundColor:   nfBottomSheetColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
          ),
          builder: (ctx) => NfBottomSheet(manga: manga, source: source),
        ),
        child: SizedBox(
          width:  110.0,
          height: 220.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              fill
                  ? Positioned.fill(
                      child: NfPosterImage(
                        imageUrl: manga.imageUrl,
                        width:    110.0,
                        height:   220.0,
                      ),
                    )
                  : NfPosterImage(
                      imageUrl: manga.imageUrl,
                      width:    110.0,
                      height:   220.0,
                    ),

              // Bottom gradient + title — "tu rajoute juste le nom dessus"
              Positioned(
                bottom: 0,
                left:   0,
                right:  0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8.0),
                    ),
                    gradient: LinearGradient(
                      begin:  Alignment.bottomCenter,
                      end:    Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 7),
                  child: Text(
                    manga.name ?? '',
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   11.5,
                      fontWeight: FontWeight.w700,
                      height:     1.25,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
