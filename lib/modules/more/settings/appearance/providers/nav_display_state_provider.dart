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

// ââ Show labels ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class NavShowLabelsNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('show_labels', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('show_labels', v);
    state = v;
    _navLog('show_labels â $v');
  }
}

final navShowLabelsProvider = NotifierProvider<NavShowLabelsNotifier, bool>(
  NavShowLabelsNotifier.new,
);

// ââ Icon size ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class NavIconSizeNotifier extends Notifier<double> {
  @override
  double build() =>
      (_box?.get('icon_size', defaultValue: 22.0) as num?)?.toDouble() ?? 22.0;

  void set(double v) {
    _box?.put('icon_size', v);
    state = v;
    _navLog('icon_size â ${v.toStringAsFixed(1)} px');
  }
}

final navIconSizeProvider = NotifierProvider<NavIconSizeNotifier, double>(
  NavIconSizeNotifier.new,
);

// ââ Item spacing âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class NavItemSpacingNotifier extends Notifier<double> {
  @override
  double build() =>
      (_box?.get('item_spacing', defaultValue: 4.0) as num?)?.toDouble() ?? 4.0;

  void set(double v) {
    _box?.put('item_spacing', v);
    state = v;
    _navLog('item_spacing â ${v.toStringAsFixed(1)} px');
  }
}

final navItemSpacingProvider = NotifierProvider<NavItemSpacingNotifier, double>(
  NavItemSpacingNotifier.new,
);

// ââ Haptic feedback ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

class NavHapticNotifier extends Notifier<bool> {
  @override
  bool build() => _box?.get('haptic', defaultValue: true) as bool? ?? true;

  void set(bool v) {
    _box?.put('haptic', v);
    state = v;
    _navLog('haptic â $v');
  }
}

final navHapticProvider = NotifierProvider<NavHapticNotifier, bool>(
  NavHapticNotifier.new,
);

// ââ Animation speed (0=off, 1=normal, 2=fast) ââââââââââââââââââââââââââââââââ

class NavAnimSpeedNotifier extends Notifier<int> {
  @override
  int build() => _box?.get('anim_speed', defaultValue: 1) as int? ?? 1;

  void set(int v) {
    _box?.put('anim_speed', v);
    state = v;
    const labels = ['off', 'normal', 'fast'];
    _navLog('anim_speed â ${labels[v.clamp(0, 2)]}');
  }
}

final navAnimSpeedProvider = NotifierProvider<NavAnimSpeedNotifier, int>(
  NavAnimSpeedNotifier.new,
);

// ââ Dock style: 'floating' | 'classic' | 'minimal' ââââââââââââââââââââââââââ

class NavDockStyleNotifier extends Notifier<String> {
  @override
  String build() =>
      _box?.get('dock_style', defaultValue: 'floating') as String? ??
      'floating';

  /// Valid values: floating, classic, minimal, rounded_full, compact, immersive
    void set(String v) {
      const valid = {'floating', 'classic', 'minimal', 'rounded_full', 'compact', 'immersive'};
      final safe = valid.contains(v) ? v : 'floating';
      _box?.put('dock_style', safe);
      state = safe;
      _navLog('dock_style', v$safe');
    }}

final navDockStyleProvider = NotifierProvider<NavDockStyleNotifier, String>(
  NavDockStyleNotifier.new,
);

// ââ Merge Library on dock (2nd entry: /Library unified page) âââââââââââââââââ

class MergeLibraryOnDockNotifier extends Notifier<bool> {
  @override
  bool build() =>
      _box?.get('merge_library_dock', defaultValue: false) as bool? ?? false;

  void set(bool v) {
    _box?.put('merge_library_dock', v);
    state = v;
    _navLog('merge_library_dock â $v');
  }
}

final mergeLibraryOnDockProvider =
    NotifierProvider<MergeLibraryOnDockNotifier, bool>(
  MergeLibraryOnDockNotifier.new,
);
