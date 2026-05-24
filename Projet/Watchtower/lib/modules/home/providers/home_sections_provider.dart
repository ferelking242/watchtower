import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model — one configurable home section
// ─────────────────────────────────────────────────────────────────────────────

class HomeSection {
  final String id;
  final String label;
  final bool defaultEnabled;

  const HomeSection({
    required this.id,
    required this.label,
    this.defaultEnabled = true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Default section catalogue (ordered)
// ─────────────────────────────────────────────────────────────────────────────

const kDefaultHomeSections = [
  HomeSection(id: 'hero',            label: 'Carrousel hero'),
  HomeSection(id: 'continue',        label: 'Continuer à regarder'),
  HomeSection(id: 'spotlight',       label: 'Coup de cœur'),
  HomeSection(id: 'recent',          label: 'Sorties récentes'),
  HomeSection(id: 'trending',        label: 'En ce moment'),
  HomeSection(id: 'sagas',           label: 'Sagas & Longues séries'),
  HomeSection(id: 'top',             label: 'Top du moment'),
  HomeSection(id: 'upcoming',        label: 'Prochainement'),
  HomeSection(id: 'schedule',        label: 'Planning hebdomadaire', defaultEnabled: false),
];

// ─────────────────────────────────────────────────────────────────────────────
// State — ordered list of (sectionId, enabled)
// ─────────────────────────────────────────────────────────────────────────────

class HomeSectionsNotifier extends Notifier<List<(String, bool)>> {
  static const _boxKey  = 'home_sections_order';
  static const _boxName = 'watchtower_prefs';

  Box? get _box {
    try {
      return Hive.box(_boxName);
    } catch (_) {
      return null;
    }
  }

  @override
  List<(String, bool)> build() => _load();

  List<(String, bool)> _load() {
    final raw = _box?.get(_boxKey) as List? ?? [];
    if (raw.isEmpty) {
      return kDefaultHomeSections
          .map((s) => (s.id, s.defaultEnabled))
          .toList();
    }
    // Merge saved with defaults (in case new sections were added)
    final saved = Map<String, bool>.fromEntries(
      raw.map((e) {
        final parts = (e as String).split(':');
        return MapEntry(parts[0], parts[1] == '1');
      }),
    );
    final merged = kDefaultHomeSections
        .map((s) => (s.id, saved[s.id] ?? s.defaultEnabled))
        .toList();
    // Respect saved order
    final savedOrder = raw.map((e) => (e as String).split(':')[0]).toList();
    merged.sort((a, b) {
      final ia = savedOrder.indexOf(a.$1);
      final ib = savedOrder.indexOf(b.$1);
      if (ia == -1 && ib == -1) return 0;
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return merged;
  }

  void _save() {
    final raw = state.map((t) => '${t.$1}:${t.$2 ? 1 : 0}').toList();
    _box?.put(_boxKey, raw);
  }

  void toggle(String id) {
    state = [
      for (final t in state)
        if (t.$1 == id) (t.$1, !t.$2) else t,
    ];
    _save();
  }

  void reorder(int oldIdx, int newIdx) {
    final list = state.toList();
    final item = list.removeAt(oldIdx);
    list.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, item);
    state = list;
    _save();
  }

  bool isEnabled(String id) =>
      state.firstWhere((t) => t.$1 == id, orElse: () => (id, true)).$2;

  void reset() {
    state = kDefaultHomeSections
        .map((s) => (s.id, s.defaultEnabled))
        .toList();
    _save();
  }
}

final homeSectionsProvider =
    NotifierProvider<HomeSectionsNotifier, List<(String, bool)>>(
  HomeSectionsNotifier.new,
);
