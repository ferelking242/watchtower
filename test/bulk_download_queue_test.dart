import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/media/widgets/bulk_enqueue_controller.dart';
import 'package:watchtower/modules/media/widgets/catalog_bulk_download_sheet.dart';
import 'package:watchtower/utils/cover_url.dart';

BulkDownloadItem _item(int? estimatedBytesPerVideo, {int videos = 1}) {
  return BulkDownloadItem(
    item: MManga(name: 'Video'),
    detail: MManga(name: 'Video'),
    chapters: [
      for (var i = 0; i < videos; i++)
        MChapter(name: 'Episode ${i + 1}', url: 'https://example.com/$i'),
    ],
    estimatedBytesPerVideo: estimatedBytesPerVideo,
  );
}

void main() {
  group('normalizeCoverUrl', () {
    test('rewrites XNXX mosaic sprite sheets to the single-frame still', () {
      expect(
        normalizeCoverUrl('https://cdn.xnxx.com/x/ab/mozaique_listing.jpg'),
        'https://cdn.xnxx.com/x/ab/xn_10_t.jpg',
      );
      expect(
        normalizeCoverUrl('https://cdn.xnxx.com/x/ab/mozaique_full.jpg'),
        'https://cdn.xnxx.com/x/ab/xn_10_t.jpg',
      );
    });

    test('leaves normal pictures and empty values untouched', () {
      const single = 'https://cdn.xnxx.com/x/ab/xn_10_t.jpg';
      expect(normalizeCoverUrl(single), single);
      expect(normalizeCoverUrl(null), isNull);
      expect(normalizeCoverUrl('  '), '  ');
    });
  });

  group('mosaicGrid', () {
    test('reports the grid geometry of known sprite sheets', () {
      expect(mosaicGrid('https://x/mozaique_listing.jpg'), (
        columns: 3,
        rows: 3,
      ));
      expect(mosaicGrid('https://x/mozaique_full.jpg'), (
        columns: 10,
        rows: 10,
      ));
    });

    test('is null for a single-frame picture', () {
      expect(mosaicGrid('https://x/xn_10_t.jpg'), isNull);
      expect(mosaicGrid(null), isNull);
    });
  });

  group('seasonOf', () {
    test('extracts a season marker as a display label', () {
      expect(seasonOf('S1 E04'), 'Saison 1');
      expect(seasonOf('Alice S02 E12'), 'Saison 2');
      expect(seasonOf('Season 3 Ep 1'), 'Saison 3');
    });

    test('matches the French "saison" marker too', () {
      expect(seasonOf('saison 3 ep 1'), 'Saison 3');
    });

    test('returns null when the episode carries no season', () {
      expect(seasonOf('Episode 12'), isNull);
      expect(seasonOf(null), isNull);
    });
  });

  group('BulkEnqueueController', () {
    test('waits while paused and resumes on demand', () async {
      final controller = BulkEnqueueController(total: 2);
      controller.setPaused(true);
      var released = false;
      final turn = controller.waitTurn().then((value) => released = value);
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      controller.setPaused(false);
      expect(await turn, isTrue);
      expect(released, isTrue);
    });

    test('cancel releases a paused worker and reports no more turns', () async {
      final controller = BulkEnqueueController(total: 2);
      controller.setPaused(true);
      final turn = controller.waitTurn();
      controller.cancel();
      expect(await turn, isFalse);
      expect(controller.cancelled, isTrue);
    });

    test('accumulates counters and progress', () {
      final controller = BulkEnqueueController(total: 4);
      controller.report(queued: 2);
      controller.report(failed: 1);
      expect(controller.done, 3);
      expect(controller.queued, 2);
      expect(controller.failed, 1);
      expect(controller.progress, closeTo(0.75, 0.001));
      expect(controller.remaining, 1);
    });
  });

  group('BulkDownloadPlan size summary', () {
    const mb = 1024 * 1024;

    test('sums the selected video sizes without rounding', () {
      final plan = BulkDownloadPlan(
        items: [_item(30 * mb), _item(70 * mb), _item(20 * mb)],
      );

      expect(plan.totalVideos, 3);
      expect(plan.totalEstimatedBytes, 120 * mb);
      expect(plan.unestimatedVideos, 0);
      expect(plan.estimatedSizeSummary, contains('120.0MB'));
    });

    test('multiplies series estimates and reports unknown video sizes', () {
      final plan = BulkDownloadPlan(
        items: [_item(25 * mb, videos: 2), _item(null)],
      );

      expect(plan.totalVideos, 3);
      expect(plan.totalEstimatedBytes, 50 * mb);
      expect(plan.unestimatedVideos, 1);
      expect(plan.estimatedSizeSummary, contains('estimation partielle'));
    });
  });
}
