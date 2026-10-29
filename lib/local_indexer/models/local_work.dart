import 'package:watchtower/local_indexer/models/local_indexed_item.dart';

/// A logical work assembled from the indexed files that share a canonical key
/// and season. The Smart Library lists works, not raw files, so movies and
/// series read like a real library: one poster, an episode count and the
/// episode numbers that are missing between the ones on disk.
class LocalWork {
  final String canonicalKey;
  final String title;
  final LocalMediaKind kind;
  final int? season;

  /// Files belonging to this work, ordered by season then episode.
  final List<LocalIndexedItem> files;

  const LocalWork({
    required this.canonicalKey,
    required this.title,
    required this.kind,
    required this.files,
    this.season,
  });

  bool get isSeries =>
      kind == LocalMediaKind.series || kind == LocalMediaKind.anime;

  /// A single-file movie (or an unclassified one) has nothing to number.
  bool get isMovie => !isSeries;

  int get fileCount => files.length;

  int get totalSize => files.fold(0, (sum, f) => sum + f.fileSize);

  List<int> get _episodeNumbers =>
      files.map((f) => f.episode).whereType<int>().where((e) => e > 0).toList()
        ..sort();

  /// Episode numbers present on disk, ascending.
  List<int> get episodes => _episodeNumbers;

  int? get lastEpisode => _episodeNumbers.isEmpty ? null : _episodeNumbers.last;

  /// Numbers absent between the first and the last indexed episode. An empty
  /// list means the season is contiguous as far as the index can tell.
  List<int> get missingEpisodes {
    final present = _episodeNumbers.toSet();
    if (present.length < 2) return const [];
    final first = present.reduce((a, b) => a < b ? a : b);
    final last = present.reduce((a, b) => a > b ? a : b);
    // A single file named "E1200" must not invent 1199 holes.
    if (last - first > 500) return const [];
    return [
      for (var e = first; e <= last; e++)
        if (!present.contains(e)) e,
    ];
  }

  /// Episode label for the card subtitle, e.g. "12 épisodes" or "Film".
  String get episodeLabel {
    if (!isSeries) return '';
    final count = episodes.isEmpty ? fileCount : episodes.length;
    return '$count';
  }

  /// Groups indexed files into works.
  ///
  /// Series are split per season so "S01" and "S02" become separate entries
  /// with their own gap analysis; movies stay whole.
  static List<LocalWork> group(List<LocalIndexedItem> items) {
    final buckets = <String, List<LocalIndexedItem>>{};
    for (final item in items) {
      final seasonKey =
          item.kind == LocalMediaKind.series ||
              item.kind == LocalMediaKind.anime
          ? 's${item.season ?? 1}'
          : 'film';
      buckets
          .putIfAbsent(
            '${item.kind.name}:${item.canonicalKey}:$seasonKey',
            () => [],
          )
          .add(item);
    }

    final works = <LocalWork>[];
    for (final entry in buckets.entries) {
      final files = entry.value.toList()
        ..sort((a, b) {
          final sa = a.season ?? 0;
          final sb = b.season ?? 0;
          if (sa != sb) return sa.compareTo(sb);
          return (a.episode ?? 0).compareTo(b.episode ?? 0);
        });
      final first = files.first;
      works.add(
        LocalWork(
          canonicalKey: first.canonicalKey,
          title: first.title,
          kind: first.kind,
          season: first.kind == LocalMediaKind.movie
              ? null
              : (first.season ?? 1),
          files: files,
        ),
      );
    }

    works.sort((a, b) {
      final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (c != 0) return c;
      return (a.season ?? 0).compareTo(b.season ?? 0);
    });
    return works;
  }
}
