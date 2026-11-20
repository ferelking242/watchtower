/// Groups unfinished downloads by a caller-provided key.
///
/// Completed records stay in storage for the library, but should not keep
/// active queue groups visible.
Map<K, List<T>> groupIncompleteDownloads<T, K>(
  Iterable<T> downloads, {
  required K Function(T download) keyFor,
  required bool Function(T download) isComplete,
}) {
  final groups = <K, List<T>>{};
  for (final download in downloads) {
    if (isComplete(download)) continue;
    (groups[keyFor(download)] ??= <T>[]).add(download);
  }
  return groups;
}

bool shouldShowDownloadGroupHeader<T>(List<T> downloads) =>
    downloads.length > 1;

/// Orders [items] by descending priority, keeping the input order for ties.
///
/// `List.sort` is not stable past 32 elements, so sorting a 30-chapter queue by
/// priority alone shuffled the equal-priority rows and started it at chapter 21
/// instead of chapter 1. Decorating each item with its original index and
/// breaking ties on it restores the FIFO (chapter) order.
///
/// [compare] adds an explicit tie-break (the queue passes a natural chapter
/// order), because the "original index" is only meaningful when the caller's
/// list is already ordered — an Isar `findAllSync()` returns rows in storage
/// order, which is not chapter order.
List<T> orderByPriorityDescending<T>(
  List<T> items, {
  required int Function(T item) priorityOf,
  int Function(T a, T b)? compare,
}) {
  final indexed = <(int, T)>[
    for (var i = 0; i < items.length; i++) (i, items[i]),
  ];
  indexed.sort((a, b) {
    final byPriority = priorityOf(b.$2).compareTo(priorityOf(a.$2));
    if (byPriority != 0) return byPriority;
    final custom = compare?.call(a.$2, b.$2) ?? 0;
    return custom != 0 ? custom : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

/// Natural (human) ordering of two chapter/episode labels.
///
/// Compares the first number found in each label numerically so `Chapitre 2`
/// sorts before `Chapitre 10`, and falls back to a case-insensitive string
/// comparison when a label carries no number. Downloads are dispatched in
/// ascending order, so a freshly queued manga starts at chapter 1 instead of
/// whichever row Isar happens to return first.
///
/// The pattern is a top-level `final`: this is the comparator of a sort, so it
/// runs O(n log n) times and used to recompile the RegExp on every comparison.
final _chapterNumberPattern = RegExp(r'\d+(?:[.,]\d+)?');

int compareChapterLabels(String? a, String? b) {
  final left = (a ?? '').trim();
  final right = (b ?? '').trim();
  if (left.isEmpty && right.isEmpty) return 0;
  if (left.isEmpty) return 1;
  if (right.isEmpty) return -1;
  final leftNumber = double.tryParse(
    _chapterNumberPattern.firstMatch(left)?.group(0)?.replaceAll(',', '.') ??
        '',
  );
  final rightNumber = double.tryParse(
    _chapterNumberPattern.firstMatch(right)?.group(0)?.replaceAll(',', '.') ??
        '',
  );
  if (leftNumber != null && rightNumber != null) {
    final byNumber = leftNumber.compareTo(rightNumber);
    if (byNumber != 0) return byNumber;
  } else if (leftNumber != null) {
    return -1;
  } else if (rightNumber != null) {
    return 1;
  }
  return left.toLowerCase().compareTo(right.toLowerCase());
}
