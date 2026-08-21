// "Reprendre / Historique" — continue-watching row for the watch home screen.
// Data: Isar History stream (same source as the global History screen),
// filtered to the current extension, deduped per manga, most recent first.
// Tap a card → resume playback via chapter.pushToReaderView.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/modules/history/providers/isar_providers.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

class NfWatchHistoryRow extends ConsumerWidget {
  const NfWatchHistoryRow({super.key, required this.source});

  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyStream = ref.watch(getAllHistoryStreamProvider(
      itemType: source.itemType,
      search: '',
    ));

    return historyStream.when(
      data: (entries) {
        final items = _latestPerManga(entries);
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: nfRedColor),
                  SizedBox(width: 6),
                  Text(
                    'Historique',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 150.0,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 8, right: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _HistoryCard(entry: items[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Keeps only the most recent entry per manga, newest first, capped at 12.
  List<History> _latestPerManga(List<History> entries) {
    final byManga = <int, History>{};
    final sorted = [...entries]..sort((a, b) =>
        (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    for (final h in sorted) {
      final chapter = h.chapter.value;
      final manga = chapter?.manga.value;
      if (chapter == null || manga == null || manga.id == null) continue;
      // Only this extension's entries
      if (manga.source != source.name || manga.lang != source.lang) continue;
      if ((manga.sourceId ?? source.id) != source.id) continue;
      byManga.putIfAbsent(manga.id!, () => h);
    }
    return byManga.values.take(12).toList();
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.entry});

  final History entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = entry.chapter.value!;
    final manga = chapter.manga.value!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () => chapter.pushToReaderView(context),
        onLongPress: () => context.push('/manga-reader/detail', extra: manga.id),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Landscape thumbnail with resume overlay + progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    NfPosterImage(
                      imageUrl: manga.imageUrl,
                      backdrop: true,
                      borderRadius: BorderRadius.zero,
                      width: 150,
                      height: 84,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                    // Dark scrim for legibility
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Play badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                          border:
                              Border.all(color: Colors.white70, width: 1.2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    // Thin progress accent — partial progress indicator
                    if (_hasProgress(chapter.lastPageRead))
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: nfRedColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Title
              Text(
                manga.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              // Episode/chapter + time
              Text(
                '${chapter.name ?? ''}'
                '  ·  ${dateFormatHour(entry.date ?? '', context)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasProgress(String? lastPageRead) {
    final v = int.tryParse(lastPageRead ?? '') ?? 0;
    return v > 0;
  }
}
