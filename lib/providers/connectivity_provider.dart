import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/services/connectivity_service.dart';

/// The single app-wide connectivity service, started on first read.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService.instance;
  service.start();
  return service;
});

/// Whether the device currently has usable Internet.
///
/// Emits the current value first, then every change, so a widget that watches
/// it renders the right state immediately instead of waiting for a transition.
/// Starts optimistic (`true`): the service corrects it once it knows better.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return _startWith(service.onChanged, service.isOnline.value);
});

/// Synchronous read of the current reachability, for callers that cannot watch
/// (download workers, HTTP interceptors).
bool get isCurrentlyOnline => ConnectivityService.instance.isOnline.value;

/// A `ValueListenableBuilder`-friendly view of the same value.
ValueListenable<bool> get onlineListenable =>
    ConnectivityService.instance.isOnline;

Stream<T> _startWith<T>(Stream<T> source, T value) async* {
  yield value;
  yield* source;
}
