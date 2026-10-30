import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/media/widgets/bulk_enqueue_controller.dart';
import 'package:watchtower/modules/media/widgets/catalog_bulk_download_sheet.dart';
import 'package:watchtower/utils/cover_url.dart';

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
      expect(
        mosaicGrid('https://x/mozaique_listing.jpg'),
        (columns: 3, rows: 3),
      );
      expect(mosaicGrid('https://x/mozaique_full.jpg'), (columns: 10, rows: 10));
    });

    test('is null for a single-frame picture', () {
      expect(mosaicGrid('https://x/xn_10_t.jpg'), isNull);
      expect(mosaicGrid(null), isNull);
    });
  });

  group('seasonOf', () {
    test('extracts a padded season marker', () {
      expect(seasonOf('S1 E04'), 'S01');
      expect(seasonOf('Alice S02 E12'), 'S02');
      expect(seasonOf('saison 3 ep 1'), isNull);
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
}
