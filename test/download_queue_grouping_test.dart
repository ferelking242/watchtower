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
      expect(groups['black-clover']!.map((download) => download.name),
          ['Chapter 2']);
      expect(shouldShowDownloadGroupHeader(groups['black-clover']!), isFalse);
    });

    test('a group disappears when its last active download completes', () {
      final groups = groupIncompleteDownloads(
        downloads.map((download) => (series: download.series, complete: true, name: download.name)),
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
}
