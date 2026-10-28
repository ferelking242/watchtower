import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Library settings persisted in the `library_settings` Hive box.
///
/// The keys mirror Mihon's library section so the two stay comparable:
/// update scheduling, metadata refresh, per-category sort and swipe behaviour.
const _kBox = 'library_settings';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

T _read<T>(String key, T fallback) {
  final v = _box?.get(key);
  return v is T ? v : fallback;
}

void _write(String key, Object? value) => _box?.put(key, value);

// ── Update interval (0 = manual/off, otherwise hours) ────────────────────────

class LibraryUpdateIntervalNotifier extends Notifier<int> {
  @override
  int build() => _read('update_interval', 168); // weekly

  void set(int hours) {
    _write('update_interval', hours);
    state = hours;
  }
}

final libraryUpdateIntervalProvider =
    NotifierProvider<LibraryUpdateIntervalNotifier, int>(
  LibraryUpdateIntervalNotifier.new,
);

/// Human-readable labels for [libraryUpdateIntervalProvider], in hours.
const kLibraryUpdateIntervalOptions = <int, String>{
  0: 'Manuelle',
  6: 'Toutes les 6 heures',
  12: 'Toutes les 12 heures',
  24: 'Tous les jours',
  48: 'Tous les 2 jours',
  168: 'Chaque semaine',
  336: 'Toutes les 2 semaines',
  720: 'Chaque mois',
};

// ── Restriction: only on Wi-Fi ───────────────────────────────────────────────

class LibraryUpdateWifiOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => _read('update_wifi_only', false);

  void set(bool v) {
    _write('update_wifi_only', v);
    state = v;
  }
}

final libraryUpdateWifiOnlyProvider =
    NotifierProvider<LibraryUpdateWifiOnlyNotifier, bool>(
  LibraryUpdateWifiOnlyNotifier.new,
);

// ── Restriction: only while charging ────────────────────────────────────────

class LibraryUpdateChargingOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => _read('update_charging_only', false);

  void set(bool v) {
    _write('update_charging_only', v);
    state = v;
  }
}

final libraryUpdateChargingOnlyProvider =
    NotifierProvider<LibraryUpdateChargingOnlyNotifier, bool>(
  LibraryUpdateChargingOnlyNotifier.new,
);

// ── Auto refresh metadata ────────────────────────────────────────────────────

class LibraryAutoRefreshMetadataNotifier extends Notifier<bool> {
  @override
  bool build() => _read('auto_refresh_metadata', false);

  void set(bool v) {
    _write('auto_refresh_metadata', v);
    state = v;
  }
}

final libraryAutoRefreshMetadataProvider =
    NotifierProvider<LibraryAutoRefreshMetadataNotifier, bool>(
  LibraryAutoRefreshMetadataNotifier.new,
);

// ── Check for new cover / synopsis on library update ─────────────────────────

class LibraryCheckNewCoverNotifier extends Notifier<bool> {
  @override
  bool build() => _read('check_new_cover', false);

  void set(bool v) {
    _write('check_new_cover', v);
    state = v;
  }
}

final libraryCheckNewCoverProvider =
    NotifierProvider<LibraryCheckNewCoverNotifier, bool>(
  LibraryCheckNewCoverNotifier.new,
);

// ── Smart update (0 = off) ───────────────────────────────────────────────────

class LibrarySmartUpdateNotifier extends Notifier<int> {
  @override
  int build() => _read('smart_update', 0);

  void set(int v) {
    _write('smart_update', v);
    state = v;
  }
}

final librarySmartUpdateProvider =
    NotifierProvider<LibrarySmartUpdateNotifier, int>(
  LibrarySmartUpdateNotifier.new,
);

const kLibrarySmartUpdateLabels = <String>[
  'Aucun(e)',
  'Nouveaux chapitres uniquement',
  'Toujours',
];

// ── Show unread chapter badge on the updates icon ────────────────────────────

class LibraryUnreadBadgeNotifier extends Notifier<bool> {
  @override
  bool build() => _read('unread_badge', true);

  void set(bool v) {
    _write('unread_badge', v);
    state = v;
  }
}

final libraryUnreadBadgeProvider =
    NotifierProvider<LibraryUnreadBadgeNotifier, bool>(
  LibraryUnreadBadgeNotifier.new,
);

// ── Swipe left / right actions ───────────────────────────────────────────────

/// Actions available for the left/right swipe gesture, Mihon-style.
const kLibrarySwipeActions = <String>[
  'Marquer le chapitre',
  'Marquer comme lu',
  'Aucun(e)',
  'Ajouter à la bibliothèque',
  'Télécharger',
  'Partager',
];

class LibrarySwipeLeftNotifier extends Notifier<int> {
  @override
  int build() => _read('swipe_left', 0); // Marquer le chapitre

  void set(int v) {
    _write('swipe_left', v);
    state = v;
  }
}

final librarySwipeLeftProvider =
    NotifierProvider<LibrarySwipeLeftNotifier, int>(LibrarySwipeLeftNotifier.new);

class LibrarySwipeRightNotifier extends Notifier<int> {
  @override
  int build() => _read('swipe_right', 1); // Marquer comme lu

  void set(int v) {
    _write('swipe_right', v);
    state = v;
  }
}

final librarySwipeRightProvider =
    NotifierProvider<LibrarySwipeRightNotifier, int>(
  LibrarySwipeRightNotifier.new,
);

// ── Mark duplicate chapter as read (0 = none) ────────────────────────────────

class LibraryMarkDuplicateReadNotifier extends Notifier<int> {
  @override
  int build() => _read('mark_duplicate_read', 0);

  void set(int v) {
    _write('mark_duplicate_read', v);
    state = v;
  }
}

final libraryMarkDuplicateReadProvider =
    NotifierProvider<LibraryMarkDuplicateReadNotifier, int>(
  LibraryMarkDuplicateReadNotifier.new,
);

// ── Hide missing-chapter indicators ──────────────────────────────────────────

class LibraryHideMissingChaptersNotifier extends Notifier<bool> {
  @override
  bool build() => _read('hide_missing_chapters', false);

  void set(bool v) {
    _write('hide_missing_chapters', v);
    state = v;
  }
}

final libraryHideMissingChaptersProvider =
    NotifierProvider<LibraryHideMissingChaptersNotifier, bool>(
  LibraryHideMissingChaptersNotifier.new,
);

// ── Sort settings per category ───────────────────────────────────────────────

/// Whether sorting is remembered per category instead of globally.
class LibraryPerCategorySortNotifier extends Notifier<bool> {
  @override
  bool build() => _read('per_category_sort', false);

  void set(bool v) {
    _write('per_category_sort', v);
    state = v;
  }
}

final libraryPerCategorySortProvider =
    NotifierProvider<LibraryPerCategorySortNotifier, bool>(
  LibraryPerCategorySortNotifier.new,
);

// ── Default category ─────────────────────────────────────────────────────────

class DefaultCategoryNotifier extends Notifier<String> {
  @override
  String build() => _read('default_category', 'Défaut');

  void set(String v) {
    _write('default_category', v);
    state = v;
  }
}

final defaultCategoryStateProvider =
    NotifierProvider<DefaultCategoryNotifier, String>(
  DefaultCategoryNotifier.new,
);
