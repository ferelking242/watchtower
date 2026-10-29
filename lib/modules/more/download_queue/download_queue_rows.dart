import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/more/download_queue/download_queue_grouping.dart';

/// One flat row of the download queue.
///
/// The source → series → chapter tree is expanded once into a flat list so the
/// queue can be rendered with a lazy list that builds only the rows on screen.
/// The nested-`Column` build this replaces laid out every card — and every
/// cover image — at once, which froze scrolling and crashed the app once a few
/// hundred downloads were queued.
sealed class DownloadQueueRow {
  const DownloadQueueRow();
}

class DownloadSourceHeaderRow extends DownloadQueueRow {
  final String source;
  final List<Download> items;

  const DownloadSourceHeaderRow(this.source, this.items);
}

class DownloadSeriesHeaderRow extends DownloadQueueRow {
  final String seriesKey;
  final List<Download> items;
  final List<Download> unfinishedItems;

  const DownloadSeriesHeaderRow(
    this.seriesKey,
    this.items,
    this.unfinishedItems,
  );
}

class DownloadEntryRow extends DownloadQueueRow {
  final Download download;
  final bool isSeriesChild;
  final bool isLastChild;

  const DownloadEntryRow(
    this.download, {
    this.isSeriesChild = false,
    this.isLastChild = false,
  });
}

/// The source an entry belongs to (extension name, or `autre` when unknown).
String downloadSourceOf(Download download) =>
    download.chapter.value?.manga.value?.source ?? 'autre';

/// Groups [entries] by extension, dropping extensions whose entries are all
/// finished — a completed download must not keep an empty section visible.
Map<String, List<Download>> groupDownloadsBySource(Iterable<Download> entries) {
  final groups = <String, List<Download>>{};
  for (final download in entries) {
    groups.putIfAbsent(downloadSourceOf(download), () => []).add(download);
  }
  groups.removeWhere(
    (_, downloads) =>
        downloads.every((download) => download.isDownload == true),
  );
  return groups;
}

/// Returns the source keys in [preferredOrder] first, then any source that is
/// not listed yet appended in first-seen order.
List<String> orderDownloadSources(
  Iterable<String> sources, {
  List<String> preferredOrder = const [],
}) {
  final all = sources.toList(growable: false);
  final result = <String>[];
  for (final source in preferredOrder) {
    if (all.contains(source) && !result.contains(source)) result.add(source);
  }
  for (final source in all) {
    if (!result.contains(source)) result.add(source);
  }
  return result;
}

/// Groups a source's entries into series, keyed by the parent item id so that
/// every chapter of the same manga/anime shares one header.
Map<String, List<Download>> groupDownloadsBySeries(Iterable<Download> items) {
  final groups = <String, List<Download>>{};
  for (final download in items) {
    final chapter = download.chapter.value;
    final manga = chapter?.manga.value;
    final mangaId = manga?.id ?? chapter?.mangaId;
    final itemId = download.id ?? chapter?.id ?? identityHashCode(download);
    final key = mangaId != null ? 'manga:$mangaId' : 'chapter:$itemId';
    groups.putIfAbsent(key, () => []).add(download);
  }
  return groups;
}

/// Flattens sources → series → chapters into the exact rows to render.
///
/// O(entries) with list allocation only — no widget is created here, which is
/// what lets the queue stay responsive with hundreds of thousands of entries.
List<DownloadQueueRow> flattenDownloadQueue({
  required Iterable<Download> entries,
  Set<String> collapsedSources = const {},
  Set<String> collapsedSeries = const {},
  List<String> preferredSourceOrder = const [],
}) {
  final groups = groupDownloadsBySource(entries);
  final sources = orderDownloadSources(
    groups.keys,
    preferredOrder: preferredSourceOrder,
  );
  final rows = <DownloadQueueRow>[];
  for (final source in sources) {
    final items = groups[source]!;
    rows.add(DownloadSourceHeaderRow(source, items));
    if (collapsedSources.contains(source)) continue;
    for (final group in groupDownloadsBySeries(items).entries) {
      final unfinished = group.value
          .where((download) => download.isDownload != true)
          .toList(growable: false);
      if (!shouldShowDownloadGroupHeader(unfinished)) {
        if (unfinished.isNotEmpty) {
          rows.add(DownloadEntryRow(unfinished.single));
        }
        continue;
      }
      rows.add(DownloadSeriesHeaderRow(group.key, group.value, unfinished));
      if (collapsedSeries.contains(group.key)) continue;
      for (var i = 0; i < unfinished.length; i++) {
        rows.add(
          DownloadEntryRow(
            unfinished[i],
            isSeriesChild: true,
            isLastChild: i == unfinished.length - 1,
          ),
        );
      }
    }
  }
  return rows;
}

/// Computes the new source order after a drag in the flattened queue.
///
/// [headerRows] holds the row index of each source header, aligned with
/// [sources]. Only source headers are draggable, so [draggedRow] is always a
/// header row; [dropRow] is the adjusted insertion index reported by the
/// reorderable list (it already accounts for the dragged row being removed).
List<String> reorderDownloadSources({
  required List<String> sources,
  required List<int> headerRows,
  required int draggedRow,
  required int dropRow,
}) {
  final oldIndex = headerRows.indexOf(draggedRow);
  if (oldIndex < 0 || sources.isEmpty) return List<String>.from(sources);

  // Header positions once the dragged row is removed from the list.
  final remaining = <int>[
    for (var i = 0; i < headerRows.length; i++)
      if (i != oldIndex) headerRows[i] - (headerRows[i] > draggedRow ? 1 : 0),
  ];
  final newIndex = remaining.where((row) => row < dropRow).length;
  if (newIndex == oldIndex) return List<String>.from(sources);

  final result = List<String>.from(sources);
  final moved = result.removeAt(oldIndex);
  result.insert(newIndex, moved);
  return result;
}
