import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_progress.dart';

void main() {
  group('manga chapter progress', () {
    test('prefers live page counts to stale persisted counts', () {
      final progress = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 34,
        isComplete: false,
        liveCompleted: 18,
        liveTotal: 36,
      );

      expect(progress.completedPages, 18);
      expect(progress.totalPages, 36);
      expect(progress.value, 0.5);
      expect(progress.isDeterminate, isTrue);
    });

    test('reports halfway through a 100-page chapter as 50 percent', () {
      final progress = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 100,
        isComplete: false,
        liveCompleted: 50,
        liveTotal: 100,
      );

      expect(mangaSeriesProgress([progress]), 0.5);
    });

    test('weights completed chapters by their page counts', () {
      final finished = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 36,
        isComplete: true,
      );
      final pending = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 24,
        isComplete: false,
      );

      expect(mangaSeriesProgress([finished, pending]), 0.6);
    });

    test('weights unequal chapters by pages rather than chapter count', () {
      final almostFinishedSmallChapter = mangaChapterProgress(
        storedCompleted: 9,
        storedTotal: 10,
        isComplete: false,
      );
      final untouchedLargeChapter = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 90,
        isComplete: false,
      );

      expect(
        mangaSeriesProgress([
          almostFinishedSmallChapter,
          untouchedLargeChapter,
        ]),
        0.09,
      );
    });

    test('falls back to chapter weighting while a page total is unknown', () {
      final known = mangaChapterProgress(
        storedCompleted: 36,
        storedTotal: 36,
        isComplete: true,
      );
      final unknown = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 1,
        isComplete: false,
      );

      // Page weighting is impossible here, but refusing a value left the
      // series header sweeping for the whole batch. One finished chapter out of
      // two is 50% of the series.
      expect(mangaSeriesProgress([known, unknown]), 0.5);
    });

    test('does not turn impossible stored counters into completed pages', () {
      final invalid = mangaChapterProgress(
        storedCompleted: 100,
        storedTotal: 36,
        isComplete: false,
      );

      expect(invalid.completedPages, 0);
      expect(invalid.value, 0);
      expect(mangaSeriesProgress([invalid]), 0);
    });

    test('drops a byte count leaked into the page total (the ~1M bug)', () {
      // A single downloaded page once surfaced as "1/1048576 pages" because the
      // stored total held bytes, not pages.
      final leaked = mangaChapterProgress(
        storedCompleted: 1,
        storedTotal: 1048576,
        isComplete: false,
      );

      expect(leaked.totalPages, 1);
      expect(leaked.isDeterminate, isFalse);
      expect(mangaSeriesProgress([leaked]), isNull);
    });

    test('drops an implausible stored total even when marked complete', () {
      final leaked = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 2097152,
        isComplete: true,
      );

      expect(leaked.totalPages, 1);
      expect(leaked.isDeterminate, isFalse);
    });

    test('ignores an implausible live total and keeps a sane stored one', () {
      final progress = mangaChapterProgress(
        storedCompleted: 5,
        storedTotal: 20,
        isComplete: false,
        liveCompleted: 5,
        liveTotal: 4194304,
      );

      expect(progress.totalPages, 20);
      expect(progress.completedPages, 5);
      expect(progress.isDeterminate, isTrue);
    });
  });

  group('series fallback', () {
    test('a batch with queued chapters still reports a percentage', () {
      // A bulk download queues every chapter with the 0/1 sentinel total, so
      // only the active chapter knows its page count. The header used to give
      // up entirely and sweep forever.
      final chapters = <MangaChapterProgress>[
        mangaChapterProgress(
          storedCompleted: 0,
          storedTotal: 40,
          isComplete: true,
        ),
        for (var i = 0; i < 5; i++)
          mangaChapterProgress(
            storedCompleted: 0,
            storedTotal: 1,
            isComplete: false,
          ),
      ];

      expect(mangaSeriesProgress(chapters), closeTo(1 / 6, 0.0001));
    });

    test('a batch of untouched chapters still has no percentage', () {
      // Nothing is known about any chapter's size yet, so 0% would be a guess.
      final chapters = [
        for (var i = 0; i < 4; i++)
          mangaChapterProgress(
            storedCompleted: 0,
            storedTotal: 1,
            isComplete: false,
          ),
      ];

      expect(mangaSeriesProgress(chapters), isNull);
    });

    test('page weighting still wins when every chapter knows its total', () {
      final chapters = [
        mangaChapterProgress(
          storedCompleted: 9,
          storedTotal: 10,
          isComplete: false,
        ),
        mangaChapterProgress(
          storedCompleted: 0,
          storedTotal: 90,
          isComplete: false,
        ),
      ];

      expect(mangaSeriesProgress(chapters), 0.09);
    });

    test('equal weighting clamps and averages finished items', () {
      expect(equalWeightedProgress([1.0, 0.0]), 0.5);
      expect(equalWeightedProgress([2.0, -1.0]), 0.5);
      expect(equalWeightedProgress(const []), isNull);
    });
  });

  group('indeterminate decision', () {
    test('a known denominator keeps the bar determinate while preparing', () {
      // Cold start: the row is `initializing` but its page/byte total is
      // already restored, so it must show that percentage, not sweep.
      expect(
        queueProgressIsIndeterminate(
          hasDeterminateFraction: true,
          isRetrievingMetadata: true,
          isPreparing: true,
          isMangaTransferWithoutTotal: true,
          isByteTransferWithoutTotal: true,
        ),
        isFalse,
      );
    });

    test('no denominator and no transfer state sweeps', () {
      expect(
        queueProgressIsIndeterminate(
          hasDeterminateFraction: false,
          isRetrievingMetadata: false,
          isPreparing: true,
          isMangaTransferWithoutTotal: false,
          isByteTransferWithoutTotal: false,
        ),
        isTrue,
      );
    });

    test('a running transfer with no denominator sweeps', () {
      expect(
        queueProgressIsIndeterminate(
          hasDeterminateFraction: false,
          isRetrievingMetadata: false,
          isPreparing: false,
          isMangaTransferWithoutTotal: true,
          isByteTransferWithoutTotal: false,
        ),
        isTrue,
      );
    });

    test('a settled row is determinate even without a denominator', () {
      expect(
        queueProgressIsIndeterminate(
          hasDeterminateFraction: false,
          isRetrievingMetadata: false,
          isPreparing: false,
          isMangaTransferWithoutTotal: false,
          isByteTransferWithoutTotal: false,
        ),
        isFalse,
      );
    });
  });
}
