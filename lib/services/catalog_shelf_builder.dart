import 'package:watchtower/models/catalog_entry.dart';
import 'package:watchtower/models/catalog_shelf.dart';

/// A shelf resolved against a catalogue: the spec plus its matching entries.
class CatalogShelfContent<T extends CatalogEntryView> {
  final CatalogShelfSpec spec;
  final List<T> entries;

  const CatalogShelfContent({required this.spec, required this.entries});

  bool get isEmpty => entries.isEmpty;
  int get length => entries.length;
}

/// Resolves shelf specs against a catalogue.
///
/// Tag lists are computed once per entry and reused by every shelf, so a
/// catalogue of a few thousand entries is scanned a fixed number of times
/// rather than once per shelf per rebuild.
class CatalogShelfBuilder<T extends CatalogEntryView> {
  final List<T> entries;
  final DateTime? newestAdded;
  final Map<int, List<String>> _tags;
  final Map<int, bool> _isNew;

  factory CatalogShelfBuilder(Iterable<T> entries) {
    final list = List<T>.unmodifiable(entries);
    final newest = newestAddedAt(list);
    return CatalogShelfBuilder._(
      list,
      newest,
      {for (final entry in list) entry.id: effectiveTags(entry)},
      {for (final entry in list) entry.id: isNewEntry(entry, newest)},
    );
  }

  CatalogShelfBuilder._(
    this.entries,
    this.newestAdded,
    this._tags,
    this._isNew,
  );

  /// Tags an entry is shelved by, already canonicalised.
  List<String> tagsOf(CatalogEntryView entry) =>
      _tags[entry.id] ?? const <String>[];

  bool isNew(CatalogEntryView entry) => _isNew[entry.id] ?? false;

  /// Entries matching [spec], ordered by its [CatalogSort], then capped.
  ///
  /// The sort is total (name, then id), so the same catalogue always yields the
  /// same order — no shelf reshuffles between two rebuilds.
  List<T> entriesFor(
    CatalogShelfSpec spec, {
    int? limit,
    bool showNsfw = false,
  }) {
    final matched = <T>[];
    for (final entry in entries) {
      final tags = tagsOf(entry);
      if (spec.matches(
        tags,
        isNew: isNew(entry),
        isNsfw: entry.isNsfw,
        // The user's opt-in is the only thing that can widen eligibility, and
        // only for a shelf that declares itself adult-facing.
        allowNsfw: showNsfw,
      )) {
        matched.add(entry);
      }
    }
    matched.sort((a, b) => spec.compare(a, b, tagsOf(a), tagsOf(b)));
    if (limit == null || matched.length <= limit) return matched;
    return matched.sublist(0, limit);
  }

  /// Every shelf that actually has enough entries to be worth showing.
  ///
  /// A shelf below its `minEntries` is dropped rather than rendered as an
  /// almost-empty row, which is what the previous layout did.
  List<CatalogShelfContent<T>> shelves(
    Iterable<CatalogShelfSpec> specs, {
    int? limitPerShelf,
    bool showNsfw = false,
  }) {
    final result = <CatalogShelfContent<T>>[];
    final seenSignatures = <String>{};
    for (final spec in specs) {
      final matched = entriesFor(
        spec,
        limit: limitPerShelf,
        showNsfw: showNsfw,
      );
      if (matched.length < spec.minEntries) continue;
      // Two shelves whose first cards are the same would read as a duplicate.
      // Identity of the first four entries is enough to catch that, while still
      // letting a broad shelf legitimately overlap a narrower one.
      final signature = matched.take(4).map((entry) => entry.id).join(',');
      if (spec.minEntries > 1 && !seenSignatures.add(signature)) continue;
      result.add(CatalogShelfContent(spec: spec, entries: matched));
    }
    return result;
  }
}
