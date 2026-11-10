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
List<T> orderByPriorityDescending<T>(
  List<T> items, {
  required int Function(T item) priorityOf,
}) {
  final indexed = <(int, T)>[
    for (var i = 0; i < items.length; i++) (i, items[i]),
  ];
  indexed.sort((a, b) {
    final byPriority = priorityOf(b.$2).compareTo(priorityOf(a.$2));
    return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
