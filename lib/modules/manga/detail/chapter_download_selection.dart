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