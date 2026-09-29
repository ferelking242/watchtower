// ignore_for_file: public_member_api_docs, invalid_use_of_protected_member

import 'dart:async';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';
import 'package:meta/meta.dart';

// ── MockQuery ────────────────────────────────────────────────────────────────
//
// A live query: when [_changeStream] and [_liveData] are provided, re-reads
// the collection on every mutation instead of emitting a static snapshot.

class MockQuery<T> extends Query<T> {
  @override
  final Isar isar;

  final List<T> _data;
  final Stream<void>? _changeStream;
  final List<T> Function()? _liveData;

  MockQuery(this.isar,
      [this._data = const [], this._changeStream, this._liveData]);

  @override Future<T?> findFirst() => Future.value(_data.firstOrNull);
  @override T? findFirstSync() => _data.firstOrNull;
  @override Future<List<T>> findAll() => Future.value(List<T>.from(_data));
  @override List<T> findAllSync() => List<T>.from(_data);

  @override
  @protected
  Future<R?> aggregate<R>(AggregationOp op) {
    if (op == AggregationOp.count) return Future.value(_data.length as R?);
    if (op == AggregationOp.isEmpty)
      return Future.value((_data.isEmpty ? 1 : 0) as R?);
    return Future.value(null);
  }

  @override
  @protected
  R? aggregateSync<R>(AggregationOp op) {
    if (op == AggregationOp.count) return _data.length as R?;
    if (op == AggregationOp.isEmpty) return (_data.isEmpty ? 1 : 0) as R?;
    return null;
  }

  @override Future<bool> deleteFirst() => Future.value(false);
  @override bool deleteFirstSync() => false;
  @override Future<int> deleteAll() => Future.value(0);
  @override int deleteAllSync() => 0;

  /// Live-reactive stream: emits the current snapshot first (when
  /// [fireImmediately] is true) then re-emits whenever the collection changes.
  @override
  Stream<List<T>> watch({bool fireImmediately = false}) {
    if (_changeStream != null && _liveData != null) {
      return _watchLive(fireImmediately);
    }
    if (fireImmediately) return Stream.value(List<T>.from(_data));
    return const Stream.empty();
  }

  Stream<List<T>> _watchLive(bool fireImmediately) async* {
    if (fireImmediately) yield _liveData!();
    yield* _changeStream!.map((_) => _liveData!());
  }

  @override
  Stream<void> watchLazy({bool fireImmediately = false}) {
    if (_changeStream != null) {
      return _watchLazyLive(fireImmediately);
    }
    if (fireImmediately) return Stream.value(null);
    return const Stream.empty();
  }

  Stream<void> _watchLazyLive(bool fireImmediately) async* {
    if (fireImmediately) yield null;
    yield* _changeStream!;
  }

  @override
  Future<R> exportJsonRaw<R>(R Function(Uint8List) callback) =>
      Future.value(callback(Uint8List(0)));
  @override
  R exportJsonRawSync<R>(R Function(Uint8List) callback) =>
      callback(Uint8List(0));
}

// ── MockIsarCollection ───────────────────────────────────────────────────────

class MockIsarCollection<OBJ> extends IsarCollection<OBJ> {
  final MockIsar _mockIsar;
  final Map<int, OBJ> _store = {};

  /// Broadcast stream that fires whenever [_store] is mutated.
  final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// Debounce flag: collapse multiple synchronous writes into one notification.
  bool _pendingNotify = false;

  MockIsarCollection(this._mockIsar);

  void seed(int id, OBJ obj) {
    _store[id] = obj;
    // No broadcast on seed — seeding happens before listeners attach.
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Extract the Isar `id` field from an object via dynamic access.
  int? _idOf(OBJ obj) {
    try {
      final dynamic d = obj;
      final dynamic raw = d.id;
      if (raw is int) return raw;
    } catch (_) {}
    return null;
  }

  /// Batch all writes within the same microtask into a single notification,
  /// preventing excessive stream re-emissions (and UI rebuilds) when many
  /// sources are added in a tight loop.
  void _notify() {
    if (_pendingNotify) return;
    _pendingNotify = true;
    Future.microtask(() {
      _pendingNotify = false;
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  // ── identity ───────────────────────────────────────────────────────────────

  @override Isar get isar => _mockIsar;
  @override String get name => 'mock';
  @override CollectionSchema<OBJ> get schema =>
      throw UnsupportedError('Web mock: schema not available');

  // ── reads ──────────────────────────────────────────────────────────────────

  @override Future<OBJ?> get(int id) => Future.value(_store[id]);
  @override OBJ? getSync(int id) => _store[id];
  @override Future<OBJ?> getByIndex(String indexName, List<Object?> key) =>
      Future.value(null);
  @override OBJ? getByIndexSync(String indexName, List<Object?> key) => null;

  @override Future<List<OBJ?>> getAll(List<int> ids) =>
      Future.value(ids.map((id) => _store[id]).toList());
  @override List<OBJ?> getAllSync(List<int> ids) =>
      ids.map((id) => _store[id]).toList();
  @override Future<List<OBJ?>> getAllByIndex(
          String indexName, List<List<Object?>> keys) =>
      Future.value(List.filled(keys.length, null));
  @override List<OBJ?> getAllByIndexSync(
          String indexName, List<List<Object?>> keys) =>
      List.filled(keys.length, null);

  // ── writes ─────────────────────────────────────────────────────────────────

  @override
  Future<List<int>> putAll(List<OBJ> objects) {
    final ids = _storeAll(objects);
    if (ids.any((id) => id != 0)) _notify();
    return Future.value(ids);
  }

  @override
  List<int> putAllSync(List<OBJ> objects, {bool saveLinks = true}) {
    final ids = _storeAll(objects);
    if (ids.any((id) => id != 0)) _notify();
    return ids;
  }

  @override
  Future<List<int>> putAllByIndex(String indexName, List<OBJ> objects) =>
      putAll(objects);
  @override
  List<int> putAllByIndexSync(String indexName, List<OBJ> objects,
          {bool saveLinks = true}) =>
      putAllSync(objects);

  List<int> _storeAll(List<OBJ> objects) {
    final ids = <int>[];
    for (final obj in objects) {
      final id = _idOf(obj);
      if (id != null) {
        _store[id] = obj;
        ids.add(id);
      } else {
        ids.add(0);
      }
    }
    return ids;
  }

  // ── deletes ────────────────────────────────────────────────────────────────

  @override
  Future<int> deleteAll(List<int> ids) async {
    int count = 0;
    for (final id in ids) {
      if (_store.remove(id) != null) count++;
    }
    if (count > 0) _notify();
    return count;
  }

  @override
  int deleteAllSync(List<int> ids) {
    int count = 0;
    for (final id in ids) {
      if (_store.remove(id) != null) count++;
    }
    if (count > 0) _notify();
    return count;
  }

  @override
  Future<int> deleteAllByIndex(
          String indexName, List<List<Object?>> keys) =>
      Future.value(0);
  @override
  int deleteAllByIndexSync(String indexName, List<List<Object?>> keys) => 0;

  @override
  Future<void> clear() async {
    _store.clear();
    _notify();
  }

  @override
  void clearSync() {
    _store.clear();
    _notify();
  }

  // ── JSON import (no-op) ────────────────────────────────────────────────────

  @override Future<void> importJsonRaw(Uint8List jsonBytes) => Future.value();
  @override void importJsonRawSync(Uint8List jsonBytes) {}
  @override Future<void> importJson(List<Map<String, dynamic>> json) =>
      Future.value();
  @override void importJsonSync(List<Map<String, dynamic>> json) {}

  // ── query building ─────────────────────────────────────────────────────────

  @override
    Query<R> buildQuery<R>({
      List<WhereClause> whereClauses = const [],
      bool whereDistinct = false,
      Sort whereSort = Sort.asc,
      FilterOperation? filter,
      List<SortProperty> sortBy = const [],
      List<DistinctProperty> distinctBy = const [],
      int? offset,
      int? limit,
      String? property,
    }) {
      final _f = filter;
      List<R> applyFilter() => _store.values
          .whereType<R>()
          .where((item) => _f == null || _matchesFilter(item, _f))
          .toList();
      return MockQuery<R>(_mockIsar, applyFilter(), _changes.stream, applyFilter);
    }

    /// Evaluates an Isar [FilterOperation] against [obj] via its [toJson] map.
    /// Defaults to true (keep) for any condition that cannot be evaluated.
    static bool _matchesFilter(dynamic obj, FilterOperation op) {
      try {
        if (op is FilterGroup) {
          switch (op.type) {
            case FilterGroupType.and:
              return op.filters.every((f) => _matchesFilter(obj, f));
            case FilterGroupType.or:
              return op.filters.any((f) => _matchesFilter(obj, f));
            case FilterGroupType.not:
              return op.filters.isEmpty ||
                  !_matchesFilter(obj, op.filters.first);
            case FilterGroupType.xor:
              return op.filters.fold<bool>(false,
                  (acc, f) => acc ^ _matchesFilter(obj, f));
          }
        }
        if (op is FilterCondition) {
          final Map<String, dynamic>? json =
              (obj as dynamic).toJson() as Map<String, dynamic>?;
          if (json == null) return true;
          final prop = op.property;
          if (prop == null) return true;
          final dynamic fieldValue = json[prop];
          switch (op.type) {
            case FilterConditionType.isNull:
              return fieldValue == null;
            case FilterConditionType.isNotNull:
              return fieldValue != null;
            case FilterConditionType.equalTo:
              final v1 = op.value1;
              if (fieldValue == v1) return true;
              // Enum stored as its .index — try comparing numerically
              try {
                final idx = (v1 as dynamic).index;
                return fieldValue == idx;
              } catch (_) {}
              return false;
            case FilterConditionType.greaterThan:
            case FilterConditionType.lessThan:
            case FilterConditionType.between:
              // Used for list-length checks (isEmpty / isNotEmpty)
              if (fieldValue is List) {
                final v1 = op.value1;
                final v2 = op.value2 ?? v1;
                if (v1 is int && v2 is int) {
                  return fieldValue.length >= v1 && fieldValue.length <= v2;
                }
              }
              return true;
            default:
              return true;
          }
        }
      } catch (_) {}
      return true;
    }

  // ── counts / sizes ─────────────────────────────────────────────────────────

  @override Future<int> count() => Future.value(_store.length);
  @override int countSync() => _store.length;
  @override Future<int> getSize(
          {bool includeIndexes = false, bool includeLinks = false}) =>
      Future.value(0);
  @override int getSizeSync(
          {bool includeIndexes = false, bool includeLinks = false}) =>
      0;

  // ── watch helpers ──────────────────────────────────────────────────────────

  @override
  Stream<void> watchLazy({bool fireImmediately = false}) =>
      _watchLazy(fireImmediately);

  Stream<void> _watchLazy(bool fireImmediately) async* {
    if (fireImmediately) yield null;
    yield* _changes.stream;
  }

  @override
  Stream<OBJ?> watchObject(int id, {bool fireImmediately = false}) =>
      _watchObj(id, fireImmediately);

  Stream<OBJ?> _watchObj(int id, bool fireImmediately) async* {
    if (fireImmediately) yield _store[id];
    yield* _changes.stream.map((_) => _store[id]);
  }

  @override
  Stream<void> watchObjectLazy(int id, {bool fireImmediately = false}) =>
      _watchLazy(fireImmediately);

  @override Future<void> verify(List<OBJ> objects) => Future.value();
  @override Future<void> verifyLink(
          String linkName, List<int> sourceIds, List<int> targetIds) =>
      Future.value();
}

// ── MockIsar ─────────────────────────────────────────────────────────────────

class MockIsar extends Isar {
  final Map<Type, IsarCollection<dynamic>> _mockCollections = {};

  MockIsar() : super('watchtowerDb');

  @override String? get directory => null;

  @override
  IsarCollection<T> collection<T>() {
    return _mockCollections.putIfAbsent(
            T, () => MockIsarCollection<T>(this)) as IsarCollection<T>;
  }

  void seed<T>(int id, T obj) {
    (collection<T>() as MockIsarCollection<T>).seed(id, obj);
  }

  @override Future<T> txn<T>(Future<T> Function() callback) => callback();
  @override T txnSync<T>(T Function() callback) => callback();
  @override Future<T> writeTxn<T>(Future<T> Function() callback,
          {bool silent = false}) =>
      callback();
  @override T writeTxnSync<T>(T Function() callback,
          {bool silent = false}) =>
      callback();
  @override Future<int> getSize(
          {bool includeIndexes = false, bool includeLinks = false}) =>
      Future.value(0);
  @override int getSizeSync(
          {bool includeIndexes = false, bool includeLinks = false}) =>
      0;
  @override Future<void> copyToFile(String targetPath) => Future.value();
  @override Future<void> verify() => Future.value();
}
