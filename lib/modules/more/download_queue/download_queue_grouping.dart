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
