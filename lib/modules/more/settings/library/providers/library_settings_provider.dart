import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:watchtower/l10n/generated/app_localizations.dart';

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

/// Update intervals offered by [libraryUpdateIntervalProvider], in hours.
/// Labels are resolved through [libraryUpdateIntervalLabel] so the picker
/// renders in the active locale.
const kLibraryUpdateIntervalOptions = <int>[
  0,
  6,
  12,
  24,
  48,
  168,
  336,
  720,
];

/// Localised label for an interval value from [kLibraryUpdateIntervalOptions].
String libraryUpdateIntervalLabel(AppLocalizations l10n, int hours) {
  return switch (hours) {
    0 => l10n.library_settings_manual,
    6 => l10n.every_6_hours,
    12 => l10n.every_12_hours,
    24 => l10n.daily,
    48 => l10n.library_settings_every_2_days,
    168 => l10n.weekly,
    336 => l10n.library_settings_every_2_weeks,
    720 => l10n.library_settings_every_month,
    _ => l10n.library_settings_manual,
  };
}

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

/// Smart-update modes, indexed by value. Labels come from
/// [librarySmartUpdateLabel] so the picker renders in the active locale.
const kLibrarySmartUpdateValues = <int>[0, 1, 2];

/// Localised label for a value from [kLibrarySmartUpdateValues].
String librarySmartUpdateLabel(AppLocalizations l10n, int value) {
  return switch (value) {
    1 => l10n.library_settings_smart_new_chapters,
    2 => l10n.library_settings_always,
    _ => l10n.library_settings_swipe_none,
  };
}

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

/// Actions available for the left/right swipe gesture, Mihon-style. The list
/// carries values only; labels resolve through [librarySwipeActionLabel].
const kLibrarySwipeActions = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// Localised label for a value from [kLibrarySwipeActions].
String librarySwipeActionLabel(AppLocalizations l10n, int action) {
  return switch (action) {
    0 => l10n.library_settings_mark_chapter,
    1 => l10n.library_settings_mark_as_read,
    2 => l10n.library_settings_swipe_none,
    3 => l10n.add_to_library,
    4 => l10n.download,
    5 => l10n.share,
    6 => l10n.library_swipe_copy_link,
    7 => l10n.library_swipe_remove_from_library,
    8 => l10n.library_swipe_mark_unread,
    9 => l10n.remove,
    _ => l10n.library_settings_swipe_none,
  };
}

class LibrarySwipeLeftNotifier extends Notifier<int> {
  @override
  // Right-to-left swipe marks the first unread chapter (default); the opposite
  // rightward swipe marks the entry as read — see `librarySwipeRightProvider`.
  // Deleting is never a default: it is destructive and needs an explicit pick.
  //
  // The key carries a version suffix because the action *indices* were
  // reshuffled when the full action list landed: a value persisted by an older
  // build pointed at a different action, so users kept a destructive or
  // read-marking swipe they never picked. Bumping the key once restores the
  // documented defaults.
  int build() => _read('swipe_left_v2', 0);

  void set(int v) {
    _write('swipe_left_v2', v);
    state = v;
  }
}

final librarySwipeLeftProvider =
    NotifierProvider<LibrarySwipeLeftNotifier, int>(LibrarySwipeLeftNotifier.new);

class LibrarySwipeRightNotifier extends Notifier<int> {
  @override
  int build() => _read('swipe_right_v2', 1); // Marquer comme lu

  void set(int v) {
    _write('swipe_right_v2', v);
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

// ── Category include / exclude lists for automatic updates ───────────────────

/// Category ids the automatic update must be limited to. Empty = all.
class LibraryUpdateIncludeCategoriesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => _readSet('update_include_categories');

  void set(Set<int> v) {
    _write('update_include_categories', v.toList());
    state = v;
  }

  void toggle(int id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    set(next);
  }
}

final libraryUpdateIncludeCategoriesProvider =
    NotifierProvider<LibraryUpdateIncludeCategoriesNotifier, Set<int>>(
  LibraryUpdateIncludeCategoriesNotifier.new,
);

/// Category ids the automatic update must skip. Empty = none.
class LibraryUpdateExcludeCategoriesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => _readSet('update_exclude_categories');

  void set(Set<int> v) {
    _write('update_exclude_categories', v.toList());
    state = v;
  }

  void toggle(int id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    set(next);
  }
}

final libraryUpdateExcludeCategoriesProvider =
    NotifierProvider<LibraryUpdateExcludeCategoriesNotifier, Set<int>>(
  LibraryUpdateExcludeCategoriesNotifier.new,
);

Set<int> _readSet(String key) {
  final raw = _box?.get(key);
  if (raw is List) return raw.whereType<int>().toSet();
  return <int>{};
}

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

// ── Display options mirrored from the Library filter overlay ─────────────────

/// Shows an unread-chapter badge on each library card.
class LibraryShowUnreadChaptersNotifier extends Notifier<bool> {
  @override
  bool build() => _read('show_unread_chapters', true);

  void set(bool v) {
    _write('show_unread_chapters', v);
    state = v;
  }
}

final libraryShowUnreadChaptersProvider =
    NotifierProvider<LibraryShowUnreadChaptersNotifier, bool>(
  LibraryShowUnreadChaptersNotifier.new,
);

/// Draws the count/language badges as a translucent overlay on the cover.
class LibraryOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => _read('cover_overlay', true);

  void set(bool v) {
    _write('cover_overlay', v);
    state = v;
  }
}

final libraryOverlayProvider =
    NotifierProvider<LibraryOverlayNotifier, bool>(LibraryOverlayNotifier.new);

// ── Continue-reading provider watermark ──────────────────────────────────────

/// When on, the continue-reading button shows the source (extension) that
/// provides the entry, mirroring the watermark drawn on download-manager
/// covers. Defaults to on.
class LibraryShowProviderBadgeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final raw = _box?.get('show_provider_badge');
    return raw is bool ? raw : true;
  }

  void set(bool v) {
    _write('show_provider_badge', v);
    state = v;
  }
}

final libraryShowProviderBadgeProvider =
    NotifierProvider<LibraryShowProviderBadgeNotifier, bool>(
  LibraryShowProviderBadgeNotifier.new,
);

// ── Content rating (classification) filter ───────────────────────────────────

/// Content-rating markers. `safe`/`suggestive`/`nsfw` are the selectable
/// buckets; entries whose genre does not match any marker are treated as safe.
const kLibraryContentRatingMarkers = <String>{
  'r18',
  'r-18',
  '18+',
  'nsfw',
  'adult',
  'hentai',
  'ecchi',
  'suggestive',
  'smut',
  'mature',
};

/// Whether [manga] carries an adult/explicit marker in its genre list.
bool isNsfwGenre(Iterable<String>? genre) {
  if (genre == null) return false;
  for (final g in genre) {
    if (kLibraryContentRatingMarkers.contains(g.trim().toLowerCase())) {
      return true;
    }
  }
  return false;
}

/// Whether [manga] carries a "suggestive" marker (but not a hard adult one).
bool isSuggestiveGenre(Iterable<String>? genre) {
  if (genre == null) return false;
  const suggestive = {'suggestive', 'ecchi', 'smut', 'mature'};
  for (final g in genre) {
    if (suggestive.contains(g.trim().toLowerCase())) return true;
  }
  return false;
}

/// Selected classification buckets (empty = show everything). Persisted per
/// item type in the `library_settings` box.
class LibraryContentRatingFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => _readStringSet('content_rating_filter');

  void set(Set<String> v) {
    _write('content_rating_filter', v.toList());
    state = v;
  }

  void toggle(String bucket) {
    final next = {...state};
    next.contains(bucket) ? next.remove(bucket) : next.add(bucket);
    set(next);
  }
}

final libraryContentRatingFilterProvider =
    NotifierProvider<LibraryContentRatingFilterNotifier, Set<String>>(
  LibraryContentRatingFilterNotifier.new,
);

Set<String> _readStringSet(String key) {
  final raw = _box?.get(key);
  if (raw is List) return raw.whereType<String>().toSet();
  return <String>{};
}
