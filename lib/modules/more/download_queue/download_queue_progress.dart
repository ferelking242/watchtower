import 'package:watchtower/services/download_manager/download_size.dart';

class MangaChapterProgress {
  const MangaChapterProgress({
    required this.completedPages,
    required this.totalPages,
    required this.value,
    required this.isDeterminate,
  });

  final int completedPages;
  final int totalPages;
  final double value;
  final bool isDeterminate;
}

MangaChapterProgress mangaChapterProgress({
  required int? storedCompleted,
  required int? storedTotal,
  required bool isComplete,
  int? liveCompleted,
  int? liveTotal,
}) {
  // A byte count or a stale counter can leak into the persisted page counters
  // (an old manga row stored `succeeded/total` in bytes), which surfaced as an
  // impossible "1/1048576 pages" — a million. Drop anything that cannot be a
  // real page count before it reaches the UI.
  final trustedStoredTotal = trustedMangaPageCount(storedTotal);
  final trustedLiveTotal = trustedMangaPageCount(liveTotal);
  final hasLivePageTotal = trustedLiveTotal != null && trustedLiveTotal > 1;
  final rawTotal = hasLivePageTotal ? trustedLiveTotal : (trustedStoredTotal ?? 0);
  final total = rawTotal > 0 ? rawTotal : 1;

  if (isComplete) {
    return MangaChapterProgress(
      completedPages: total,
      totalPages: total,
      value: 1,
      isDeterminate: total > 1,
    );
  }

  if (total <= 1) {
    return MangaChapterProgress(
      completedPages: 0,
      totalPages: total,
      value: 0,
      isDeterminate: false,
    );
  }

  final candidate = hasLivePageTotal
      ? (liveCompleted ?? 0)
      : (storedCompleted ?? 0);
  final completed = candidate >= 0 && candidate <= total ? candidate : 0;

  return MangaChapterProgress(
    completedPages: completed,
    totalPages: total,
    value: completed / total,
    isDeterminate: true,
  );
}

double? mangaSeriesProgress(Iterable<MangaChapterProgress> chapters) {
  final values = chapters.toList(growable: false);
  if (values.isEmpty || values.any((chapter) => !chapter.isDeterminate)) {
    return null;
  }

  final totalPages = values.fold<int>(
    0,
    (sum, chapter) => sum + chapter.totalPages,
  );
  if (totalPages <= 0) return null;

  final completedPages = values.fold<int>(
    0,
    (sum, chapter) => sum + chapter.completedPages,
  );
  return (completedPages / totalPages).clamp(0.0, 1.0).toDouble();
}
