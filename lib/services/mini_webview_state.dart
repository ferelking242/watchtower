import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single minimized WebView tab.
class MiniWebViewEntry {
  final String url;
  final String title;
  const MiniWebViewEntry({required this.url, required this.title});
}

class MiniWebViewNotifier extends StateNotifier<List<MiniWebViewEntry>> {
  MiniWebViewNotifier() : super([]);

  /// Push a new minimized tab (most recent first).
  void push(MiniWebViewEntry entry) => state = [entry, ...state];

  /// Remove the tab at [index].
  void removeAt(int index) {
    final list = [...state];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = list;
    }
  }

  /// Pop the most recent tab (used when expanding).
  MiniWebViewEntry? pop() {
    if (state.isEmpty) return null;
    final entry = state.first;
    state = state.skip(1).toList();
    return entry;
  }

  /// Remove all tabs.
  void clear() => state = [];
}

final miniWebViewProvider =
    StateNotifierProvider<MiniWebViewNotifier, List<MiniWebViewEntry>>(
  (_) => MiniWebViewNotifier(),
);
