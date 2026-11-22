import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Favourited channels, kept as `LiveChannel.id` strings.
///
/// Ids rather than channel objects: a playlist re-fetch can change a URL or a
/// logo, and a favourite must survive that. The channel itself is looked up in
/// the current list, so a favourite whose provider is disabled simply does not
/// resolve rather than showing stale data.
class LiveFavoritesStore {
  LiveFavoritesStore({Box<dynamic>? box}) : _box = box;

  static const boxName = 'live_tv_favorites';
  static const _key = 'ids';

  final Box<dynamic>? _box;

  Box<dynamic>? get _store =>
      _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);

  Set<String> read() {
    final raw = _store?.get(_key);
    if (raw is! List) return {};
    return {
      for (final id in raw)
        if (id is String && id.isNotEmpty) id,
    };
  }

  Future<void> write(Set<String> ids) async {
    final box = _store;
    if (box == null) return;
    await box.put(_key, ids.toList());
  }
}

/// Favourites as a Riverpod state, so a star tapped on the home list and the
/// favourites tab stay in step without either rebuilding the whole module.
class LiveFavoritesNotifier extends Notifier<Set<String>> {
  late final LiveFavoritesStore _store = LiveFavoritesStore();

  @override
  Set<String> build() => _store.read();

  bool contains(String channelId) => state.contains(channelId);

  Future<void> toggle(String channelId) async {
    final next = Set<String>.from(state);
    if (!next.remove(channelId)) next.add(channelId);
    state = next;
    await _store.write(next);
  }

  Future<void> clear() async {
    state = {};
    await _store.write({});
  }
}

final liveFavoritesProvider =
    NotifierProvider<LiveFavoritesNotifier, Set<String>>(
      LiveFavoritesNotifier.new,
    );
