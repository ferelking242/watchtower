import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/manga/detail/chapter_download_selection.dart';

void main() {
  group('selectChaptersToDownload', () {
    final chapters = List<int>.generate(59, (index) => index);

    test('caps the requested range at the last available chapter', () {
      final selected = selectChaptersToDownload(
        chapters: chapters,
        lastReadIndex: 37,
        limit: 25,
      );

      expect(selected, List<int>.generate(21, (index) => index + 38));
      expect(selected, isNot(contains(62)));
    });

    test('returns no chapters when the last read chapter is the last item', () {
      expect(
        selectChaptersToDownload(
          chapters: chapters,
          lastReadIndex: chapters.length - 1,
          limit: 25,
        ),
        isEmpty,
      );
    });

    test('starts at the first chapter if nothing has been read', () {
      expect(
        selectChaptersToDownload(
          chapters: chapters,
          lastReadIndex: -1,
          limit: 25,
        ),
        [chapters.first],
      );
    });

    test('handles empty lists and non-positive limits', () {
      expect(
        selectChaptersToDownload(
          chapters: <int>[],
          lastReadIndex: -1,
          limit: 25,
        ),
        isEmpty,
      );
      expect(
        selectChaptersToDownload(
          chapters: chapters,
          lastReadIndex: 10,
          limit: 0,
        ),
        isEmpty,
      );
    });
  });

  group('chapterIndexForListItem', () {
    test('returns null for a stale sliver index after the list shrinks', () {
      expect(
        chapterIndexForListItem(
          itemIndex: 63,
          chapterCount: 59,
          reverse: false,
        ),
        isNull,
      );
    });

    test('maps the header and reversed chapter indices safely', () {
      expect(
        chapterIndexForListItem(
          itemIndex: 0,
          chapterCount: 59,
          reverse: false,
        ),
        isNull,
      );
      expect(
        chapterIndexForListItem(
          itemIndex: 1,
          chapterCount: 59,
          reverse: true,
        ),
        58,
      );
      expect(
        chapterIndexForListItem(
          itemIndex: 59,
          chapterCount: 59,
          reverse: true,
        ),
        0,
      );
    });
  });
}
