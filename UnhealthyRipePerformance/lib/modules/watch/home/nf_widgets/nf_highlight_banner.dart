// Adapted from flutter_netflix — highlight_movie.dart
// Removed: BLoC, Movie model, LogoImage (TMDB API), lucide_icons.
// Replaced: MManga for data, manga.name as big title, manga.imageUrl as backdrop.
import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'nf_genre.dart';
import 'nf_new_and_hot_tile_action.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfHighlightBanner extends StatelessWidget {
  const NfHighlightBanner({
    super.key,
    required this.manga,
    this.onPlayTap,
    this.onMyListTap,
    this.genres = const [],
  });

  final MManga       manga;
  final VoidCallback? onPlayTap;
  final VoidCallback? onMyListTap;
  final List<String>  genres;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // ── Backdrop image ──────────────────────────────────────────────────
        Container(
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end:   const Alignment(0.0, 0.2),
              colors: [
                Colors.black,
                Colors.black.withValues(alpha: 0.92),
                Colors.black.withValues(alpha: 0.80),
                Colors.transparent,
              ],
            ),
          ),
          child: NfPosterImage(
            imageUrl:     manga.imageUrl,
            original:     true,
            borderRadius: BorderRadius.zero,
            width:        width,
            height:       width + (width * .6),
            alignment:    Alignment.topCenter,
          ),
        ),

        // ── Overlaid content at the bottom ──────────────────────────────────
        Positioned(
          bottom: 0.0,
          width:  width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38.0, vertical: 16.0),
            child: Column(
              children: [
                // Title — replaces LogoImage (no TMDB logo API in Watchtower)
                Text(
                  manga.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   28,
                    fontWeight: FontWeight.w900,
                    height:     1.15,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                  ),
                ),
                const SizedBox(height: 8.0),

                // Genre dots
                if (genres.isNotEmpty) ...[
                  NfGenre(genres: genres, color: nfRedColor),
                  const SizedBox(height: 12.0),
                ],

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NfNewAndHotTileAction(
                      icon:  Icons.add_rounded,
                      label: 'Ma liste',
                      onTap: onMyListTap,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding:         const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 6.0),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: onPlayTap,
                      icon:  const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Lecture',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    NfNewAndHotTileAction(
                      icon:  Icons.info_outline_rounded,
                      label: 'Info',
                      onTap: onPlayTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
