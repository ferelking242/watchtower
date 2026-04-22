import 'package:flutter_riverpod/flutter_riverpod.dart';

class _NavShowLabelsNotifier extends Notifier<bool> {
  @override
  bool build() => true;
}

class _NavIconSizeNotifier extends Notifier<double> {
  @override
  double build() => 22;
}

final navShowLabelsProvider = NotifierProvider<_NavShowLabelsNotifier, bool>(
  _NavShowLabelsNotifier.new,
);

final navIconSizeProvider = NotifierProvider<_NavIconSizeNotifier, double>(
  _NavIconSizeNotifier.new,
);
