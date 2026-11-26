import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/utils/chapter_sort.dart';

Chapter _chapter(String name, {String? scanlator, String? date}) => Chapter(
  mangaId: 1,
  name: name,
  scanlator: scanlator ?? '',
  dateUpload: date ?? '',
);

void main() {
  test('sorts chapter numbers instead of insertion order', () {
    final input = [
      _chapter('Chapter 49'),
      _chapter('Chapter 51'),
      _chapter('Chapter 50'),
    ];

    final descending = sortChapters(
      input,
      sortIndex: 1,
      reverse: true,
      mangaTitle: 'Title',
    );

    expect(descending.map((c) => c.name), [
      'Chapter 51',
      'Chapter 50',
      'Chapter 49',
    ]);
  });

  test('keeps decimal chapter numbers in order', () {
    final input = [
      _chapter('Chapter 44.5'),
      _chapter('Chapter 45'),
      _chapter('Chapter 44'),
    ];

    final ascending = sortChapters(
      input,
      sortIndex: 1,
      reverse: false,
      mangaTitle: 'Title',
    );

    expect(ascending.map((c) => c.name), [
      'Chapter 44',
      'Chapter 44.5',
      'Chapter 45',
    ]);
  });

  test('scanlator sort still groups by scanlator then number', () {
    final input = [
      _chapter('Chapter 2', scanlator: 'B'),
      _chapter('Chapter 1', scanlator: 'B'),
      _chapter('Chapter 3', scanlator: 'A'),
    ];

    final sorted = sortChapters(
      input,
      sortIndex: 0,
      reverse: false,
      mangaTitle: 'Title',
    );

    expect(sorted.map((c) => '${c.scanlator}${c.name!.split(' ').last}'), [
      'A3',
      'B1',
      'B2',
    ]);
  });
}
