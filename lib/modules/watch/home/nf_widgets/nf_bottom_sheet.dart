// Adapted from flutter_netflix — netflix_bottom_sheet.dart
// Removed: BLoC, Movie model, TMDB images, lucide_icons, go_router.
// Adapted: MManga + Source, Play → pushToMangaReaderDetail.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart'
    show pushToMangaReaderDetail;
import 'nf_bottom_sheet_button.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfBottomSheet extends ConsumerWidget {
  const NfBottomSheet({
    super.key,
    required this.manga,
    required this.source,
  });

  final MManga  manga;
  final Source  source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width:  40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Thumbnail + metadata row ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: NfPosterImage(
                      imageUrl: manga.imageUrl,
                      width:    90.0,
                      height:   130.0,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + close
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                manga.name ?? '',
                                style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close_rounded,
                                    size: 18, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        if (manga.link != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              manga.link!.length > 60
                                  ? '${manga.link!.substring(0, 60)}…'
                                  : manga.link!,
                              style: TextStyle(
                                  color:    Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Play button ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    pushToMangaReaderDetail(
                      ref:      ref,
                      context:  context,
                      getManga: manga,
                      lang:     source.lang!,
                      source:   source.name!,
                      itemType: source.itemType,
                      sourceId: source.id,
                    );
                  },
                  icon:  const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lecture',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Action buttons row ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NfBottomSheetButton(
                  icon:  Icons.add_rounded,
                  label: 'Ma liste',
                ),
                NfBottomSheetButton(
                  icon:  Icons.thumb_up_outlined,
                  label: 'J\'aime',
                ),
                NfBottomSheetButton(
                  icon:  Icons.share_rounded,
                  label: 'Partager',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
