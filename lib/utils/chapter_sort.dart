import 'package:watchtower/models/chapter.dart';

/// Shared chapter ordering for the detail page and the reader.
///
/// The Isar `mangaId` query returns chapters in insertion order, which is the
/// order the extension happened to publish them in — not the reading order.
/// Both screens used to sort that raw list differently (and the reader applied
/// the display sort to a reversed list), so "next chapter" could jump from 50
/// back to 49. Keeping one comparator here makes every screen agree.

double _chapterNumber(String mangaTitle, Chapter chapter) {
  final name = (chapter.name ?? '').toLowerCase();
  final title = mangaTitle.toLowerCase();
  final withoutTitle = title.isEmpty ? name : name.replaceAll(title, '');
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(withoutTitle);
  if (match == null) return double.negativeInfinity;
  return double.tryParse(match.group(1)!.replaceAll(',', '.')) ??
      double.negativeInfinity;
}

int _compareNumbers(String mangaTitle, Chapter a, Chapter b) {
  final an = _chapterNumber(mangaTitle, a);
  final bn = _chapterNumber(mangaTitle, b);
  if (an == bn) {
    final ad = int.tryParse(a.dateUpload ?? '') ?? 0;
    final bd = int.tryParse(b.dateUpload ?? '') ?? 0;
    return ad.compareTo(bd);
  }
  return an.compareTo(bn);
}

/// Sorts [input] according to the user's chapter sort preference.
///
/// `sortIndex`: 0 = scanlator, 1 = chapter number (default), 2 = upload date,
/// 3 = name. [reverse] flips the final order (the reader uses it to keep its
/// newest-first convention).
List<Chapter> sortChapters(
  List<Chapter> input, {
  required int sortIndex,
  required bool reverse,
  required String mangaTitle,
}) {
  final chapters = List<Chapter>.of(input);
  switch (sortIndex) {
    case 0:
      chapters.sort((a, b) {
        final scanlator = (a.scanlator ?? '').compareTo(b.scanlator ?? '');
        if (scanlator != 0) return scanlator;
        return _compareNumbers(mangaTitle, a, b);
      });
      break;
    case 2:
      chapters.sort((a, b) {
        final ad = int.tryParse(a.dateUpload ?? '');
        final bd = int.tryParse(b.dateUpload ?? '');
        if (ad == null || bd == null) {
          return _compareNumbers(mangaTitle, a, b);
        }
        final byDate = ad.compareTo(bd);
        return byDate != 0 ? byDate : _compareNumbers(mangaTitle, a, b);
      });
      break;
    case 3:
      chapters.sort((a, b) {
        final byName = (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        );
        return byName != 0 ? byName : _compareNumbers(mangaTitle, a, b);
      });
      break;
    default:
      chapters.sort((a, b) => _compareNumbers(mangaTitle, a, b));
  }
  if (reverse) return chapters.reversed.toList(growable: false);
  return chapters;
}
