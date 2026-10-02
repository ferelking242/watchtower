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
}