// Adapted from flutter_netflix — netflix_bottom_sheet.dart
// Removed: BLoC, Movie model, TMDB images, lucide_icons, go_router.
// Adapted: MManga + Source, Play → pushToMangaReaderDetail,
//          Ma liste → Isar favorite toggle (bounce + haptic),
//          Partager → share_plus, description + genre chips added.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart'
    show pushToMangaReaderDetail;
import 'package:isar_community/isar.dart';
import 'nf_bottom_sheet_button.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfBottomSheet extends ConsumerStatefulWidget {
  const NfBottomSheet({
    super.key,
    required this.manga,
    required this.source,
  });

  final MManga manga;
  final Source source;

  @override
  ConsumerState<NfBottomSheet> createState() => _NfBottomSheetState();
}

class _NfBottomSheetState extends ConsumerState<NfBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _added = false;

  late final AnimationController _bounceCtrl;
  late final Animation<double>   _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    // Check if already favourited — mirror pushToMangaReaderDetail disambiguation
    final existing = _findExisting();
    if (existing?.favorite == true) _added = true;
  }

  /// Mirrors the sourceId-aware lookup used in pushToMangaReaderDetail so we
  /// always target the correct record when the same title exists for multiple
  /// sourceIds (e.g. different regions of the same extension).
  Manga? _findExisting() {
    final s = widget.source;
    final m = widget.manga;
    if (m.name == null || s.lang == null || s.name == null) return null;
    final candidates = isar.mangas
        .filter()
        .langEqualTo(s.lang)
        .nameEqualTo(m.name)
        .sourceEqualTo(s.name)
        .findAllSync();
    if (candidates.isEmpty) return null;
    return candidates.firstWhere(
      (e) => e.sourceId == null ? true : e.sourceId == s.id,
      orElse: () => candidates.first,
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Ma liste (Isar favorite toggle) ─────────────────────────────────────────

  void _toggleList() {
    HapticFeedback.mediumImpact();
    final m = widget.manga;
    final s = widget.source;

    // Guard against malformed extension data
    final name = m.name?.trim();
    final lang = s.lang;
    final src  = s.name;
    if (name == null || name.isEmpty || lang == null || src == null) {
      _bounceCtrl.forward(from: 0);
      return;
    }

    final existing = _findExisting();

    if (existing == null) {
      // Not in Isar yet — create and mark favourite
      final manga = Manga(
        imageUrl:    m.imageUrl,
        name:        name,
        genre:       m.genre?.map((e) => e.toString()).toList() ?? [],
        author:      m.author       ?? '',
        status:      m.status       ?? Status.unknown,
        description: m.description  ?? '',
        link:        m.link,
        source:      src,
        lang:        lang,
        lastUpdate:  0,
        itemType:    s.itemType,
        artist:      m.artist ?? '',
        sourceId:    s.id,
      );
      isar.writeTxnSync(() {
        isar.mangas.putSync(
          manga
            ..favorite  = true
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      });
      setState(() => _added = true);
    } else {
      // Toggle existing favourite flag (sourceId-disambiguated record)
      final newVal = !(existing.favorite ?? false);
      isar.writeTxnSync(() {
        isar.mangas.putSync(
          existing
            ..favorite  = newVal
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      });
      setState(() => _added = newVal);
    }

    _bounceCtrl.forward(from: 0);
  }

  // ── Partager ─────────────────────────────────────────────────────────────────

  void _share() {
    final link    = widget.manga.link ?? '';
    final baseUrl = widget.source.baseUrl ?? '';
    final url     = link.startsWith('http') ? link : '$baseUrl$link';
    SharePlus.instance.share(
      ShareParams(text: '${widget.manga.name ?? ''}\n$url'),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = widget.manga;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize:     MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Thumbnail + metadata row ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: NfPosterImage(
                      imageUrl: m.imageUrl,
                      width:    90.0,
                      height:   130.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.name ?? '',
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
                        // Description
                        if (m.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            m.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:    Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              height:   1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Genre / tag chips ────────────────────────────────────────────
            if (m.genre?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing:    6,
                  runSpacing: 6,
                  children: m.genre!.take(6).map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        border:       Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        g.toString(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Play button ──────────────────────────────────────────────────
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
                      getManga: m,
                      lang:     widget.source.lang!,
                      source:   widget.source.name!,
                      itemType: widget.source.itemType,
                      sourceId: widget.source.id,
                    );
                  },
                  icon:  const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lecture',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Action buttons row ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _bounceAnim,
                  child: NfBottomSheetButton(
                    icon:  _added
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    label: _added ? 'Ajouté' : 'Ma liste',
                    onTap: _toggleList,
                  ),
                ),
                NfBottomSheetButton(
                  icon:  Icons.share_rounded,
                  label: 'Partager',
                  onTap: _share,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
