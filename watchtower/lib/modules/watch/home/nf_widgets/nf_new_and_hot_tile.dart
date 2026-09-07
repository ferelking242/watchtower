// Adapted from flutter_netflix — new_and_hot_tile.dart
// Removed: BLoC, Movie model, TMDB dates/episodes, lucide_icons, intl.
// Adapted: MManga, manga.imageUrl as backdrop, manga.name as title.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart'
    show pushToMangaReaderDetail;
import 'nf_new_and_hot_tile_action.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfNewAndHotTile extends ConsumerWidget {
  const NfNewAndHotTile({
    super.key,
    required this.manga,
    required this.source,
  });

  final MManga manga;
  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;

    void openDetail() => pushToMangaReaderDetail(
          ref:      ref,
          context:  context,
          getManga: manga,
          lang:     source.lang!,
          source:   source.name!,
          itemType: source.itemType,
          sourceId: source.id,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Backdrop image ────────────────────────────────────────────────
          GestureDetector(
            onTap: openDetail,
            child: NfPosterImage(
              imageUrl:     manga.imageUrl,
              backdrop:     true,
              borderRadius: BorderRadius.zero,
              width:        width,
              height:       width * 0.56,
              fit:          BoxFit.cover,
              alignment:    Alignment.topCenter,
            ),
          ),

          const SizedBox(height: 12.0),

          // ── Title + action buttons ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Expanded(
                  child: Text(
                    manga.name ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   18.0,
                      color:      Colors.white,
                    ),
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NfNewAndHotTileAction(
                      icon:  Icons.add_rounded,
                      label: 'Ma liste',
                    ),
                    NfNewAndHotTileAction(
                      icon:  Icons.play_circle_outline_rounded,
                      label: 'Lecture',
                      onTap: openDetail,
                    ),
                    NfNewAndHotTileAction(
                      icon:  Icons.info_outline_rounded,
                      label: 'Info',
                      onTap: openDetail,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8.0),

          // ── Genre tags (static placeholder — extensions don't provide genres) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              children: const [
                _GenreChip('Action'),
                _GenreChip('Tendances'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small genre chip ──────────────────────────────────────────────────────────

class _GenreChip extends StatelessWidget {
  const _GenreChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color:    Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }
}
