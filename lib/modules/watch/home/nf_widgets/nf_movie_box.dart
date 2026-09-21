// Adapted from flutter_netflix — movie_box.dart
// Removed: BLoC, Movie model, TMDB URL, netflix_symbol asset, laughs counter.
// Added: MManga + Source, title below the poster, tap → NfBottomSheet or direct nav.
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
    this.compact = false,
    this.cardStyle,
  });

  final MManga manga;
  final Source source;
  final EdgeInsets? padding;
  final bool fill;
  final bool compact;
  final String? cardStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          backgroundColor: nfBottomSheetColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
          ),
          builder: (ctx) => NfBottomSheet(manga: manga, source: source),
        ),
        child: SizedBox(
          width: compact ? 100.0 : 118.0,
          height: compact ? 185.0 : 218.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 100.0 : 118.0,
                height: compact ? 150.0 : 178.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NfPosterImage(
                    imageUrl: manga.imageUrl,
                    width: compact ? 100.0 : 118.0,
                    height: compact ? 150.0 : 178.0,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                manga.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
