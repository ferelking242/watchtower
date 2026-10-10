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

    test('does not claim a percentage while any page total is unknown', () {
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

      expect(mangaSeriesProgress([known, unknown]), isNull);
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
  });
}
