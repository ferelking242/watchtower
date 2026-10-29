import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_rows.dart';

Manga _manga(int id, {required String source, String? name}) {
  return Manga(
    id: id,
    source: source,
    author: '',
    artist: '',
    genre: const [],
    imageUrl: '',
    lang: 'en',
    link: '',
    name: name ?? 'Series $id',
    status: Status.ongoing,
    description: '',
    sourceId: 0,
  );
}

Download _download({
  required int id,
  required int mangaId,
  required String source,
  bool complete = false,
  String status = 'downloading',
}) {
  final chapter = Chapter(id: id, mangaId: mangaId, name: 'Chapter $id');
  chapter.manga.value = _manga(mangaId, source: source);
  final download = Download(
    id: id,
    succeeded: complete ? 1 : 0,
    failed: 0,
    total: 1,
    isDownload: complete,
    isStartDownload: true,
    status: status,
  );
  download.chapter.value = chapter;
  return download;
}

void main() {
  group('flattenDownloadQueue', () {
    test('flattens source → series → chapter into lazy rows', () {
      final rows = flattenDownloadQueue(
        entries: [
          _download(id: 1, mangaId: 10, source: 'alpha'),
          _download(id: 2, mangaId: 10, source: 'alpha'),
          _download(id: 3, mangaId: 20, source: 'beta'),
        ],
      );

      expect(rows.whereType<DownloadSourceHeaderRow>().map((r) => r.source), [
        'alpha',
        'beta',
      ]);
      // One series header for manga 10, and the lone manga 20 stays flat.
      expect(rows.whereType<DownloadSeriesHeaderRow>().length, 1);
      expect(rows.whereType<DownloadEntryRow>().length, 3);
      expect(rows.first, isA<DownloadSourceHeaderRow>());
    });

    test('handles 250+ downloads without nesting every row in one parent', () {
      final entries = <Download>[
        for (var i = 0; i < 250; i++)
          _download(id: i + 1, mangaId: 1, source: 'bulk'),
      ];

      final rows = flattenDownloadQueue(entries: entries);

      // 1 source header + 1 series header + 250 chapter rows.
      expect(rows.length, 252);
      expect(rows.whereType<DownloadEntryRow>().length, 250);
    });

    test('collapsing a source hides its series and chapters', () {
      final rows = flattenDownloadQueue(
        entries: [
          _download(id: 1, mangaId: 10, source: 'alpha'),
          _download(id: 2, mangaId: 10, source: 'alpha'),
        ],
        collapsedSources: {'alpha'},
      );

      expect(rows.length, 1);
      expect(rows.single, isA<DownloadSourceHeaderRow>());
    });

    test('collapsing a series hides only its chapters', () {
      final rows = flattenDownloadQueue(
        entries: [
          _download(id: 1, mangaId: 10, source: 'alpha'),
          _download(id: 2, mangaId: 10, source: 'alpha'),
        ],
        collapsedSeries: {'manga:10'},
      );

      expect(rows.whereType<DownloadEntryRow>(), isEmpty);
      expect(rows.whereType<DownloadSeriesHeaderRow>().length, 1);
    });

    test('finished downloads never keep an empty source section', () {
      final rows = flattenDownloadQueue(
        entries: [
          _download(id: 1, mangaId: 10, source: 'alpha', complete: true),
          _download(id: 2, mangaId: 20, source: 'beta'),
        ],
      );

      expect(rows.whereType<DownloadSourceHeaderRow>().map((r) => r.source), [
        'beta',
      ]);
    });

    test('preferred source order is honoured, new sources appended', () {
      final rows = flattenDownloadQueue(
        entries: [
          _download(id: 1, mangaId: 10, source: 'alpha'),
          _download(id: 2, mangaId: 20, source: 'beta'),
          _download(id: 3, mangaId: 30, source: 'gamma'),
        ],
        preferredSourceOrder: ['gamma', 'alpha'],
      );

      expect(rows.whereType<DownloadSourceHeaderRow>().map((r) => r.source), [
        'gamma',
        'alpha',
        'beta',
      ]);
    });
  });

  group('reorderDownloadSources', () {
    test('moving the first source below the second swaps them', () {
      // rows: [src a (0)], [child], [child], [src b (3)]
      final order = reorderDownloadSources(
        sources: ['a', 'b'],
        headerRows: [0, 3],
        draggedRow: 0,
        dropRow: 3,
      );
      expect(order, ['b', 'a']);
    });

    test('moving a source back to the top is honoured', () {
      final order = reorderDownloadSources(
        sources: ['a', 'b', 'c'],
        headerRows: [0, 4, 9],
        draggedRow: 9,
        dropRow: 0,
      );
      expect(order, ['c', 'a', 'b']);
    });

    test('dropping a source onto itself keeps the order', () {
      final order = reorderDownloadSources(
        sources: ['a', 'b'],
        headerRows: [0, 3],
        draggedRow: 0,
        dropRow: 1,
      );
      expect(order, ['a', 'b']);
    });

    test('a non-header drag row leaves the order untouched', () {
      final order = reorderDownloadSources(
        sources: ['a', 'b'],
        headerRows: [0, 3],
        draggedRow: 1,
        dropRow: 4,
      );
      expect(order, ['a', 'b']);
    });
  });
}
