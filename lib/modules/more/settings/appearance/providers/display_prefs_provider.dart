import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Display preferences (Affichage) persisted in the `ui_prefs` Hive box.
const _kBox = 'ui_prefs';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

T _read<T>(String key, T fallback) {
  final v = _box?.get(key);
  return v is T ? v : fallback;
}

void _write(String key, Object? value) => _box?.put(key, value);

// ── Tablet mode ──────────────────────────────────────────────────────────────
// auto | always | landscape | never

class TabletModeNotifier extends Notifier<String> {
  static const _valid = {'auto', 'always', 'landscape', 'never'};

  @override
  String build() {
    final stored = _read('tablet_mode', 'auto');
    return _valid.contains(stored) ? stored : 'auto';
  }

  void set(String v) {
    final safe = _valid.contains(v) ? v : 'auto';
    _write('tablet_mode', safe);
    state = safe;
  }
}

final tabletModeProvider =
    NotifierProvider<TabletModeNotifier, String>(TabletModeNotifier.new);

const kTabletModeOptions = <(String, String)>[
  ('auto', 'Auto'),
  ('always', 'Toujours'),
  ('landscape', 'Paysage'),
  ('never', 'Jamais'),
];

String tabletModeLabel(String value) {
  for (final o in kTabletModeOptions) {
    if (o.$1 == value) return o.$2;
  }
  return 'Auto';
}

// ── Render images inside manga descriptions ──────────────────────────────────

class RenderDescriptionImagesNotifier extends Notifier<bool> {
  @override
  bool build() => _read('render_description_images', false);

  void set(bool v) {
    _write('render_description_images', v);
    state = v;
  }
}

final renderDescriptionImagesProvider =
    NotifierProvider<RenderDescriptionImagesNotifier, bool>(
  RenderDescriptionImagesNotifier.new,
);

// ── App language override (null = follow system) ─────────────────────────────

class AppLanguageNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = _box?.get('app_language') as String?;
    if (code == null || code.isEmpty) return null;
    final parts = code.split('_');
    return parts.length > 1
        ? Locale(parts[0], parts[1])
        : Locale(parts[0]);
  }

  void set(Locale? locale) {
    if (locale == null) {
      _box?.delete('app_language');
    } else {
      final code = locale.countryCode == null
          ? locale.languageCode
          : '${locale.languageCode}_${locale.countryCode}';
      _write('app_language', code);
    }
    state = locale;
  }
}

final appLanguageOverrideProvider =
    NotifierProvider<AppLanguageNotifier, Locale?>(AppLanguageNotifier.new);

/// Applies the stored tablet-mode preference to a width-based guess.
///
/// [widthIsTablet] is the plain breakpoint result and [isLandscape] the current
/// orientation. Read synchronously from Hive so it can be used from a
/// `BuildContext` extension without a Riverpod handle.
bool resolveTabletMode({required bool widthIsTablet, required bool isLandscape}) {
  switch (_read('tablet_mode', 'auto')) {
    case 'always':
      return true;
    case 'never':
      return false;
    case 'landscape':
      return widthIsTablet && isLandscape;
    case 'auto':
    default:
      return widthIsTablet;
  }
}
