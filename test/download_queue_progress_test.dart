import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_progress.dart';

void main() {
  group('manga chapter progress', () {
    test('prefers live page counts to stale persisted counts', () {
      final progress = mangaChapterProgress(
        storedCompleted: 0,
        storedTotal: 36,
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

    test('averages chapter progress so one of two finished is 50 percent', () {
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

      expect(mangaSeriesProgress([finished, pending]), 0.5);
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
