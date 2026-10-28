import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Extra reader options (Mihon parity) that have no field in the Isar settings
/// model yet. Persisted in the `reader_prefs` Hive box.
const _kBox = 'reader_prefs';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

T _read<T>(String key, T fallback) {
  final v = _box?.get(key);
  return v is T ? v : fallback;
}

void _write(String key, Object? value) => _box?.put(key, value);

/// Generic bool preference backed by the box.
class _BoolPref extends Notifier<bool> {
  _BoolPref(this._key, this._default);
  final String _key;
  final bool _default;

  @override
  bool build() => _read(_key, _default);

  void set(bool v) {
    _write(_key, v);
    state = v;
  }
}

class _IntPref extends Notifier<int> {
  _IntPref(this._key, this._default);
  final String _key;
  final int _default;

  @override
  int build() => _read(_key, _default);

  void set(int v) {
    _write(_key, v);
    state = v;
  }
}

class _StringPref extends Notifier<String> {
  _StringPref(this._key, this._default);
  final String _key;
  final String _default;

  @override
  String build() => _read(_key, _default);

  void set(String v) {
    _write(_key, v);
    state = v;
  }
}

NotifierProvider<_BoolPref, bool> _boolPref(String key, bool def) =>
    NotifierProvider<_BoolPref, bool>(() => _BoolPref(key, def));

NotifierProvider<_IntPref, int> _intPref(String key, int def) =>
    NotifierProvider<_IntPref, int>(() => _IntPref(key, def));

NotifierProvider<_StringPref, String> _stringPref(String key, String def) =>
    NotifierProvider<_StringPref, String>(() => _StringPref(key, def));

// ── En cours ────────────────────────────────────────────────────────────────

/// Skip chapters already marked as read when navigating.
final skipReadChaptersProvider = _boolPref('skip_read_chapters', false);

/// Skip chapters hidden by filters.
final skipFilteredChaptersProvider = _boolPref('skip_filtered_chapters', false);

/// Ignore duplicate chapters.
final skipDuplicateChaptersProvider = _boolPref('skip_duplicate_chapters', true);

/// Always show the transition between chapters.
final alwaysShowChapterTransitionProvider =
    _boolPref('always_show_chapter_transition', true);

// ── Affichage ───────────────────────────────────────────────────────────────

/// Show the reading-mode picker when the reader opens.
final showReadingModeProvider = _boolPref('show_reading_mode', false);

/// Briefly show the tap zones when the reader opens.
final showTapZonesOverlayProvider = _boolPref('show_tap_zones_overlay', false);

/// Load pages ahead only while on Wi-Fi.
final loadAheadOnlyOnWifiProvider = _boolPref('load_ahead_only_on_wifi', false);

/// Default screen rotation: free | portrait | landscape.
final readerRotationProvider = _stringPref('reader_rotation', 'free');

/// Draw inside the display cutout area.
final readerCutoutProvider = _boolPref('reader_cutout', false);

/// E-ink: flash the screen on page change to reduce ghosting.
final einkFlashOnPageChangeProvider =
    _boolPref('eink_flash_on_page_change', false);

// ── Pages ───────────────────────────────────────────────────────────────────

/// Invert the tap zones (next/previous swap).
final invertPageTapZonesProvider = _boolPref('invert_page_tap_zones', false);

/// Zoom start position: auto | left | right | center.
final zoomStartPositionProvider = _stringPref('zoom_start_position', 'auto');

/// Pan wide images instead of shrinking them.
final panoramaImagesProvider = _boolPref('panorama_images', true);

/// Split wide (two-page) spreads into separate pages.
final splitWidePagesProvider = _boolPref('split_wide_pages', false);

/// Rotate wide pages so they fit the screen.
final rotateWidePagesProvider = _boolPref('rotate_wide_pages', false);

/// Double tap zooms out again (off = double tap only zooms in).
final doubleTapZoomOutProvider = _boolPref('double_tap_zoom_out', true);

// ── Bande continue ──────────────────────────────────────────────────────────

/// Continuous mode: hide the menu on scroll sensitivity (0 low … 2 high).
final continuousMenuHideSensitivityProvider =
    _intPref('continuous_menu_hide_sensitivity', 0);

// ── Navigation ──────────────────────────────────────────────────────────────

/// Vertical chapter navigator placement: none | left | right | both.
final verticalChapterNavigatorProvider =
    _stringPref('vertical_chapter_navigator', 'none');

// ── Actions ─────────────────────────────────────────────────────────────────

/// Show the action list on long press.
final longPressActionsProvider = _boolPref('long_press_actions', true);

/// Save each page into its own folder.
final savePagesInSeparateFoldersProvider =
    _boolPref('save_pages_in_separate_folders', false);

const kReaderRotationOptions = <(String, String)>[
  ('free', 'Libre'),
  ('portrait', 'Portrait'),
  ('landscape', 'Paysage'),
];

const kZoomStartOptions = <(String, String)>[
  ('auto', 'Automatique'),
  ('left', 'Gauche'),
  ('right', 'Droite'),
  ('center', 'Centre'),
];

const kVerticalNavigatorOptions = <(String, String)>[
  ('none', 'Aucun(e)'),
  ('left', 'Gauche'),
  ('right', 'Droite'),
  ('both', 'Les deux'),
];

const kMenuHideSensitivityOptions = <(int, String)>[
  (0, 'Basse'),
  (1, 'Moyenne'),
  (2, 'Haute'),
];

String optionLabel(List<(String, String)> options, String value) {
  for (final o in options) {
    if (o.$1 == value) return o.$2;
  }
  return options.first.$2;
}
