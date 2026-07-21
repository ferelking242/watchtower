import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 0 = list  |  1 = grid (2 cols)  |  2 = grid étendu (3 cols)
class ExtensionLayoutNotifier extends Notifier<int> {
  static const _kKey = 'ext_layout_mode';

  @override
  int build() {
    _loadAsync();
    return 1;
  }

  void _loadAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getInt(_kKey);
      if (val != null && state != val) state = val;
    } catch (_) {}
  }

  void set(int value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kKey, value);
    } catch (_) {}
  }
}

final extensionLayoutModeProvider =
    NotifierProvider<ExtensionLayoutNotifier, int>(
  ExtensionLayoutNotifier.new,
);
