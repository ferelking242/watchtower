/// Selects the next chapters to queue without indexing past the available list.
///
/// With no read chapter, the existing quick-download behavior starts at the
/// first chapter. A one-chapter series also keeps that behavior even if read.
List<T> selectChaptersToDownload<T>({
  required List<T> chapters,
  required int lastReadIndex,
  required int limit,
}) {
  if (chapters.isEmpty || limit <= 0) return const [];
  if (lastReadIndex < 0 || chapters.length == 1) {
    return [chapters.first];
  }

  final startIndex = lastReadIndex + 1;
  if (startIndex >= chapters.length) return const [];
  return chapters.skip(startIndex).take(limit).toList(growable: false);
}

/// Maps a sliver item index (which includes the chapter header at index 0) to
/// a chapter index. Returns null when a lazy list invokes its builder with a
/// stale index after the chapter list has shrunk.
int? chapterIndexForListItem({
  required int itemIndex,
  required int chapterCount,
  required bool reverse,
}) {
  final index = itemIndex - 1;
  if (index < 0 || index >= chapterCount) return null;
  return reverse ? chapterCount - index - 1 : index;
}
