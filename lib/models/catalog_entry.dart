import 'package:watchtower/models/catalog_taxonomy.dart';

/// The parts of a catalogue entry the shelf system needs.
///
/// Declaring this interface keeps the shelf logic testable without the
/// Marketplace screen's private entry type, and without pulling the whole
/// widget tree into a unit test.
abstract interface class CatalogEntryView {
  int get id;
  String get name;

  /// Explicit tags published in the index. May be empty for older indexes.
  List<String> get tags;

  /// The catalogue index the entry was published under (`itemType`).
  int get itemType;

  /// Declared language codes: the primary `lang` plus any `langs` list.
  List<String> get languages;

  /// Date the entry first appeared in the catalogue, when the index has it.
  DateTime? get addedAt;

  /// Adult content. The catalogue declares it, so shelves never have to guess.
  bool get isNsfw;

  /// Website the extension serves content from, when the index publishes one.
  ///
  /// Optional: older indexes omit `baseUrl`, in which case the card simply
  /// hides its "open website" affordance rather than guessing a domain.
  String? get siteUrl;

  /// Short description published by the index.
  ///
  /// Optional for the same reason as [siteUrl]; the card falls back to its
  /// generated summary when it is empty.
  String get description;
}

/// Tags an entry is shelved by.
///
/// A newer index carries an explicit `tags` list and that list wins. An older
/// index carries none, so the tags are completed from facts the entry already
/// has: the catalogue it lives in and the languages it declares. Nothing is
/// ever inferred from the extension's name, a domain, or a brand — that is the
/// substring matching this system replaces.
List<String> effectiveTags(CatalogEntryView entry) {
  final declared = CatalogTaxonomy.filterKnown(entry.tags);
  if (declared.isNotEmpty) {
    final merged = {...declared};
    // The catalogue index is a fact, so it always contributes its content tag
    // even when an entry's published tag list is incomplete.
    final fromIndex = CatalogTaxonomy.itemTypeToContent[entry.itemType];
    if (fromIndex != null) merged.add(fromIndex);
    for (final code in entry.languages) {
      final tag = CatalogTaxonomy.languageTagFor(code);
      if (tag != null) merged.add(tag);
    }
    return CatalogTaxonomy.orderTags(merged);
  }

  final derived = <String>{
    if (CatalogTaxonomy.itemTypeToContent[entry.itemType] != null)
      CatalogTaxonomy.itemTypeToContent[entry.itemType]!,
  };
  for (final code in entry.languages) {
    final tag = CatalogTaxonomy.languageTagFor(code);
    if (tag != null) derived.add(tag);
  }
  return CatalogTaxonomy.orderTags(derived);
}

/// How recently added an entry has to be to count as new.
///
/// Measured against the newest entry in the catalogue rather than the wall
/// clock: a catalogue that stops being updated must not turn its "Nouveautés"
/// shelf into an empty one, and the result must not depend on when the app
/// happens to be opened.
const Duration kCatalogNewWindow = Duration(days: 90);

/// Newest [addedAt] in a catalogue, or null when no entry declares one.
DateTime? newestAddedAt(Iterable<CatalogEntryView> entries) {
  DateTime? newest;
  for (final entry in entries) {
    final added = entry.addedAt;
    if (added == null) continue;
    if (newest == null || added.isAfter(newest)) newest = added;
  }
  return newest;
}

/// True when the entry was added within [kCatalogNewWindow] of [reference].
///
/// [reference] is the newest catalogue date, so this stays deterministic. An
/// entry with no date is never claimed as new.
bool isNewEntry(CatalogEntryView entry, DateTime? reference) {
  final added = entry.addedAt;
  if (added == null || reference == null) return false;
  return reference.difference(added) <= kCatalogNewWindow;
}
