import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/browse/marketplace_search_filter.dart';

class _Entry {
  _Entry(
    this.name, {
    this.installed = false,
    this.update = false,
    this.added = 0,
    this.rating = 0,
  });

  final String name;
  final bool installed;
  final bool update;
  final int added;
  final double rating;
}

List<_Entry> _apply(
  List<_Entry> entries, {
  MarketplaceSearchSort sort = MarketplaceSearchSort.relevance,
  bool installedOnly = false,
  bool withUpdatesOnly = false,
}) {
  return applyMarketplaceSearchFilters<_Entry>(
    entries: entries,
    sort: sort,
    installedOnly: installedOnly,
    withUpdatesOnly: withUpdatesOnly,
    isInstalled: (entry) => entry.installed,
    hasUpdate: (entry) => entry.update,
    nameOf: (entry) => entry.name,
    addedAtMillis: (entry) => entry.added,
    ratingOf: (entry) => entry.rating,
  );
}

List<String> _names(List<_Entry> entries) =>
    entries.map((entry) => entry.name).toList();

void main() {
  group('filters', () {
    test('installedOnly keeps only installed entries', () {
      final result = _apply([
        _Entry('A', installed: true),
        _Entry('B'),
        _Entry('C', installed: true),
      ], installedOnly: true);
      expect(_names(result), ['A', 'C']);
    });

    test('withUpdatesOnly keeps only entries with a pending update', () {
      final result = _apply([
        _Entry('A', update: true),
        _Entry('B'),
      ], withUpdatesOnly: true);
      expect(_names(result), ['A']);
    });

    test('both filters combined require installed and update', () {
      final result = _apply([
        _Entry('A', installed: true, update: true),
        _Entry('B', installed: true),
        _Entry('C', update: true),
      ], installedOnly: true, withUpdatesOnly: true);
      expect(_names(result), ['A']);
    });

    test('the input list is never mutated', () {
      final input = [_Entry('B'), _Entry('A')];
      final result = _apply(input, sort: MarketplaceSearchSort.recent);
      expect(_names(input), ['B', 'A']);
      expect(result, isNot(same(input)));
    });
  });

  group('relevance sort', () {
    test('update-flagged entries come first', () {
      final result = _apply([
        _Entry('A', rating: 5),
        _Entry('B', update: true, rating: 1),
      ]);
      expect(_names(result), ['B', 'A']);
    });

    test('then rating descending', () {
      final result = _apply([_Entry('A', rating: 2), _Entry('B', rating: 9)]);
      expect(_names(result), ['B', 'A']);
    });

    test('ties are broken case-insensitively A to Z', () {
      final result = _apply([_Entry('beta'), _Entry('Alpha')]);
      expect(_names(result), ['Alpha', 'beta']);
    });

    test('is a total order: the same input always yields the same output', () {
      final input = [
        _Entry('c', rating: 1),
        _Entry('a', rating: 1),
        _Entry('b', rating: 1),
      ];
      expect(_names(_apply(input)), _names(_apply(input)));
    });
  });

  group('recent sort', () {
    test('most recently added first', () {
      final result = _apply([
        _Entry('A', added: 100),
        _Entry('B', added: 300),
        _Entry('C', added: 200),
      ], sort: MarketplaceSearchSort.recent);
      expect(_names(result), ['B', 'C', 'A']);
    });

    test('undated entries sort last and by name among themselves', () {
      final result = _apply([
        _Entry('Zed'),
        _Entry('Ann', added: 50),
        _Entry('Bob'),
      ], sort: MarketplaceSearchSort.recent);
      expect(_names(result), ['Ann', 'Bob', 'Zed']);
    });
  });

  group('installed sort', () {
    test('installed entries come first, then A to Z', () {
      final result = _apply([
        _Entry('Ann'),
        _Entry('Zoe', installed: true),
        _Entry('Bob', installed: true),
      ], sort: MarketplaceSearchSort.installed);
      expect(_names(result), ['Bob', 'Zoe', 'Ann']);
    });
  });

  test('an empty catalogue yields an empty list for every sort', () {
    for (final sort in MarketplaceSearchSort.values) {
      expect(_apply(const [], sort: sort), isEmpty);
    }
  });
}
