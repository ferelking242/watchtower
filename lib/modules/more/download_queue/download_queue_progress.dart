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

/// Mean of [fractions] where every item counts equally.
///
/// This is the fallback used when a page/byte denominator is still missing for
/// some items (a chapter queued behind the active one has no page count yet).
/// Returning `null` in that case made the series header sweep left→right for
/// the whole batch, so a batch of 30 chapters never showed progress. Counting
/// items equally is coarser than page weighting but always honest: 0 finished
/// chapters *is* 0% of the series.
double? equalWeightedProgress(Iterable<double> fractions) {
  final values = fractions.toList(growable: false);
  if (values.isEmpty) return null;
  final sum = values.fold<double>(
    0,
    (total, value) => total + value.clamp(0.0, 1.0),
  );
  return (sum / values.length).clamp(0.0, 1.0).toDouble();
}

double? mangaSeriesProgress(Iterable<MangaChapterProgress> chapters) {
  final values = chapters.toList(growable: false);
  if (values.isEmpty) return null;

  if (values.every((chapter) => chapter.isDeterminate)) {
    final totalPages = values.fold<int>(
      0,
      (sum, chapter) => sum + chapter.totalPages,
    );
    if (totalPages > 0) {
      final completedPages = values.fold<int>(
        0,
        (sum, chapter) => sum + chapter.completedPages,
      );
      return (completedPages / totalPages).clamp(0.0, 1.0).toDouble();
    }
  }

  // At least one chapter still has no page total. Chapter weighting is only
  // meaningful when at least one chapter does know its size: a batch whose
  // chapters are all still queued has no percentage to show, and claiming 0%
  // would be a guess.
  if (!values.any((chapter) => chapter.isDeterminate)) return null;
  return equalWeightedProgress(values.map((chapter) => chapter.value));
}

/// Whether a queue row must animate an indeterminate bar.
///
/// A known denominator always wins. A row that is still preparing (page scan,
/// metadata fetch) but already knows its page or byte total keeps showing that
/// percentage instead of sweeping — otherwise a resumed chapter, whose stored
/// counters are restored before the scan, would animate left→right for the
/// whole scan and look stuck.
bool queueProgressIsIndeterminate({
  required bool hasDeterminateFraction,
  required bool isRetrievingMetadata,
  required bool isPreparing,
  required bool isMangaTransferWithoutTotal,
  required bool isByteTransferWithoutTotal,
}) {
  if (hasDeterminateFraction) return false;
  return isRetrievingMetadata ||
      isPreparing ||
      isMangaTransferWithoutTotal ||
      isByteTransferWithoutTotal;
}
