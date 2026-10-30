/// Ordering offered by the Marketplace search filter menu.
enum MarketplaceSearchSort {
  /// Update-flagged first, then by rating, then A→Z. The default, and the
  /// order the catalogue rows already use.
  relevance,

  /// Most recently published first, undated entries last, ties broken A→Z.
  recent,

  /// Installed extensions first, then A→Z.
  installed,
}

/// Narrows [entries] to the ones the search filter menu asks for.
///
/// Pure and generic: the caller supplies the two predicates and the sort key,
/// so the rules can be unit-tested without building the whole search screen.
/// The input list is never mutated.
List<T> applyMarketplaceSearchFilters<T>({
  required List<T> entries,
  required MarketplaceSearchSort sort,
  required bool installedOnly,
  required bool withUpdatesOnly,
  required bool Function(T entry) isInstalled,
  required bool Function(T entry) hasUpdate,
  required String Function(T entry) nameOf,
  required int Function(T entry) addedAtMillis,
  required double Function(T entry) ratingOf,
}) {
  var list = entries;
  if (installedOnly) {
    list = list.where(isInstalled).toList();
  }
  if (withUpdatesOnly) {
    list = list.where(hasUpdate).toList();
  }
  if (identical(list, entries)) list = List<T>.of(list);

  int byName(T a, T b) =>
      nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());

  switch (sort) {
    case MarketplaceSearchSort.recent:
      list.sort((a, b) {
        final byDate = addedAtMillis(b).compareTo(addedAtMillis(a));
        return byDate != 0 ? byDate : byName(a, b);
      });
    case MarketplaceSearchSort.installed:
      list.sort((a, b) {
        final aInstalled = isInstalled(a);
        final bInstalled = isInstalled(b);
        if (aInstalled != bInstalled) return aInstalled ? -1 : 1;
        return byName(a, b);
      });
    case MarketplaceSearchSort.relevance:
      list.sort((a, b) {
        final aUpdate = hasUpdate(a);
        final bUpdate = hasUpdate(b);
        if (aUpdate != bUpdate) return aUpdate ? -1 : 1;
        final byRating = ratingOf(b).compareTo(ratingOf(a));
        return byRating != 0 ? byRating : byName(a, b);
      });
  }
  return list;
}
