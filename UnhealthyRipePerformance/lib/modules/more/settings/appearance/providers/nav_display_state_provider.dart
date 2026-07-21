import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/utils/log/logger.dart';

const _kNavBox = 'nav_display';

Box? get _box => Hive.isBoxOpen(_kNavBox) ? Hive.box(_kNavBox) : null;

void _navLog(String msg) => AppLogger.log(
      msg,
      logLevel: LogLevel.debug,
      tag: LogTag.nav,
    );

// ── Show labels ──────────────────────────────────────────────────────────────

class NavShowLabelsNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('show_labels', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('show_labels', v);
    state = v;
    _navLog('show_labels → $v');
  }
}

final navShowLabelsProvider = NotifierProvider<NavShowLabelsNotifier, bool>(
  NavShowLabelsNotifier.new,
);

// ── Icon size ────────────────────────────────────────────────────────────────

class NavIconSizeNotifier extends Notifier<double> {
  @override
  double build() =>
      (_box?.get('icon_size', defaultValue: 22.0) as num?)?.toDouble() ?? 22.0;

  void set(double v) {
    _box?.put('icon_size', v);
    state = v;
    _navLog('icon_size → ${v.toStringAsFixed(1)} px');
  }
}

final navIconSizeProvider = NotifierProvider<NavIconSizeNotifier, double>(
  NavIconSizeNotifier.new,
);

// ── Item spacing ─────────────────────────────────────────────────────────────

class NavItemSpacingNotifier extends Notifier<double> {
  @override
  double build() =>
      (_box?.get('item_spacing', defaultValue: 4.0) as num?)?.toDouble() ?? 4.0;

  void set(double v) {
    _box?.put('item_spacing', v);
    state = v;
    _navLog('item_spacing → ${v.toStringAsFixed(1)} px');
  }
}

final navItemSpacingProvider = NotifierProvider<NavItemSpacingNotifier, double>(
  NavItemSpacingNotifier.new,
);

// ── Haptic feedback ──────────────────────────────────────────────────────────

class NavHapticNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('haptic', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('haptic', v);
    state = v;
    _navLog('haptic → $v');
  }
}

final navHapticProvider = NotifierProvider<NavHapticNotifier, bool>(
  NavHapticNotifier.new,
);

// ── Animation speed (0=off, 1=normal, 2=fast) ────────────────────────────────

class NavAnimSpeedNotifier extends Notifier<int> {
  @override
  int build() => _box?.get('anim_speed', defaultValue: 1) as int? ?? 1;

  void set(int v) {
    _box?.put('anim_speed', v);
    state = v;
    const labels = ['off', 'normal', 'fast'];
    _navLog('anim_speed → ${labels[v.clamp(0, 2)]}');
  }
}

final navAnimSpeedProvider = NotifierProvider<NavAnimSpeedNotifier, int>(
  NavAnimSpeedNotifier.new,
);

// ── Dock style: 'classic' | 'immersive' | 'pc_sidebar' ──────────────────────

class NavDockStyleNotifier extends Notifier<String> {
  static const _valid = {'classic', 'immersive', 'pc_sidebar'};

  @override
  String build() {
    final stored =
        _box?.get('dock_style', defaultValue: 'immersive') as String? ??
        'immersive';
    return _valid.contains(stored) ? stored : 'immersive';
  }

  /// Valid values: classic, immersive, pc_sidebar
  void set(String v) {
    final safe = _valid.contains(v) ? v : 'classic';
    _box?.put('dock_style', safe);
    state = safe;
    _navLog('dock_style changed to $safe');
  }
}

final navDockStyleProvider = NotifierProvider<NavDockStyleNotifier, String>(
  NavDockStyleNotifier.new,
);

// ── Merge Library on dock (2nd entry: /Library unified page) ─────────────────

class MergeLibraryOnDockNotifier extends Notifier<bool> {
  @override
  bool build() =>
      _box?.get('merge_library_dock', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('merge_library_dock', v);
    state = v;
    _navLog('merge_library_dock → $v');
  }
}

final mergeLibraryOnDockProvider =
    NotifierProvider<MergeLibraryOnDockNotifier, bool>(
  MergeLibraryOnDockNotifier.new,
);
