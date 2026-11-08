import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';

Source? getSource(
  String lang,
  String name,
  int? sourceId, {
  bool installedOnly = false,
}) {
  try {
    // Query with indexed filters (id / lang+name) instead of loading the whole
    // source collection: this runs on the UI thread from `headersProvider` for
    // every visible card, and `findAllSync().where(...)` made it O(sources).
    Iterable<Source> candidates;
    if (sourceId != null) {
      candidates = isar.sources.filter().idEqualTo(sourceId).findAllSync();
    } else {
      candidates = isar.sources
          .filter()
          .langEqualTo(lang)
          .nameEqualTo(name)
          .findAllSync();
    }
    bool matches(Source element) =>
        element.sourceCode != null &&
        (sourceId != null ||
            element.name?.toLowerCase() == name.toLowerCase()) &&
        (!installedOnly ||
            ((element.isActive ?? false) && (element.isAdded ?? false)));

    final match = candidates.where(matches).firstOrNull;
    if (match != null) return match;

    // Case-insensitive fallback for the rare source whose stored name differs
    // in case from the requested one (the indexed filter above is exact).
    if (sourceId == null) {
      final fallback = isar.sources
          .filter()
          .langEqualTo(lang)
          .findAllSync()
          .where(matches)
          .firstOrNull;
      if (fallback != null) return fallback;
    }
    return null;
  } catch (_) {
    return null;
  }
}
