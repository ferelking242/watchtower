import 'package:flutter_riverpod/flutter_riverpod.dart';

class MiniWebViewEntry {
  final String url;
  final String title;
  const MiniWebViewEntry({required this.url, required this.title});
}

class MiniWebViewNotifier extends Notifier<List<MiniWebViewEntry>> {
  @override
  List<MiniWebViewEntry> build() => [];

  void push(MiniWebViewEntry entry) => state = [entry, ...state];

  void removeAt(int index) {
    final list = [...state];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = list;
    }
  }

  MiniWebViewEntry? pop() {
    if (state.isEmpty) return null;
    final entry = state.first;
    state = state.skip(1).toList();
    return entry;
  }

  void clear() => state = [];
}

final miniWebViewProvider =
    NotifierProvider<MiniWebViewNotifier, List<MiniWebViewEntry>>(
  MiniWebViewNotifier.new,
);
