import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_grouping.dart';

void main() {
  group('download queue grouping', () {
    const downloads = <({String series, bool complete, String name})>[
      (series: 'black-clover', complete: true, name: 'Chapter 1'),
      (series: 'black-clover', complete: false, name: 'Chapter 2'),
      (series: 'one-piece', complete: true, name: 'Chapter 10'),
    ];

    test('completed siblings disappear while active chapters remain', () {
      final groups = groupIncompleteDownloads(
        downloads,
        keyFor: (download) => download.series,
        isComplete: (download) => download.complete,
      );

      expect(groups.keys, ['black-clover']);
      expect(groups['black-clover']!.map((download) => download.name), [
        'Chapter 2',
      ]);
      expect(shouldShowDownloadGroupHeader(groups['black-clover']!), isFalse);
    });

    test('a group disappears when its last active download completes', () {
      final groups = groupIncompleteDownloads(
        downloads.map(
          (download) =>
              (series: download.series, complete: true, name: download.name),
        ),
        keyFor: (download) => download.series,
        isComplete: (download) => download.complete,
      );

      expect(groups, isEmpty);
    });

    test('a header is shown only when there are multiple active downloads', () {
      expect(shouldShowDownloadGroupHeader(['Chapter 1']), isFalse);
      expect(shouldShowDownloadGroupHeader(['Chapter 1', 'Chapter 2']), isTrue);
    });
  });

  group('orderByPriorityDescending', () {
    test('keeps the chapter order for a long equal-priority queue', () {
      // A 30-chapter queue: `List.sort` is not stable past 32 elements, so a
      // naive priority sort started it at chapter 21 instead of chapter 1.
      final chapters = List.generate(30, (i) => i + 1);
      final ordered = orderByPriorityDescending(
        chapters,
        priorityOf: (_) => 0,
      );
      expect(ordered, chapters);
    });

    test('puts higher priorities first and keeps ties in input order', () {
      final items = List.generate(40, (i) => i + 1);
      final ordered = orderByPriorityDescending(
        items,
        priorityOf: (chapter) => chapter % 10 == 0 ? 1 : 0,
      );
      // The four "priority" chapters lead, in their original relative order…
      expect(ordered.take(4), [10, 20, 30, 40]);
      // …then the rest, still ascending.
      expect(ordered.skip(4), items.where((c) => c % 10 != 0));
    });

    test('is stable for a shuffled list of equal keys', () {
      final items = List.generate(50, (i) => 'ch$i');
      final ordered = orderByPriorityDescending(items, priorityOf: (_) => 0);
      expect(ordered, items);
    });
  });

  group('compareChapterLabels', () {
    test('orders numbers numerically, not lexicographically', () {
      expect(compareChapterLabels('Chapitre 2', 'Chapitre 10'), lessThan(0));
      expect(compareChapterLabels('Chapitre 23', 'Chapitre 3'), greaterThan(0));
    });

    test('sorts a whole queue from chapter 1 upward', () {
      final names = [
        'Chapitre 23',
        'Chapitre 10',
        'Chapitre 2',
        'Chapitre 1',
        'Chapitre 3',
      ];
      names.sort(compareChapterLabels);
      expect(names, [
        'Chapitre 1',
        'Chapitre 2',
        'Chapitre 3',
        'Chapitre 10',
        'Chapitre 23',
      ]);
    });

    test('handles decimal chapter numbers', () {
      expect(compareChapterLabels('Chapitre 2.5', 'Chapitre 3'), lessThan(0));
      expect(compareChapterLabels('Chapitre 10', 'Chapitre 9.5'), greaterThan(0));
    });

    test('falls back to the label when there is no number', () {
      expect(compareChapterLabels('Bonus', 'Chapitre 1'), greaterThan(0));
      expect(compareChapterLabels('Bonus', 'Bonus'), 0);
      expect(compareChapterLabels(null, 'Chapitre 1'), greaterThan(0));
      expect(compareChapterLabels('Chapitre 1', null), lessThan(0));
    });
  });
}
