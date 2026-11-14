// Riverpod 2.x compatibility shims. The `StateProvider` factory intentionally
// mirrors the removed Riverpod 2.x API name.
// ignore_for_file: non_constant_identifier_names

import 'package:hooks_riverpod/hooks_riverpod.dart';

abstract class FamilyAsyncNotifier<State, Arg> extends AsyncNotifier<State> {
  late Arg _familyArg;
  Arg get arg => _familyArg;
  void initFamily(Arg a) => _familyArg = a;
}

abstract class FamilyNotifier<State, Arg> extends Notifier<State> {
  late Arg _familyArg;
  Arg get arg => _familyArg;
  void initFamily(Arg a) => _familyArg = a;
}

typedef AutoDisposeFamilyAsyncNotifier<S, A> = FamilyAsyncNotifier<S, A>;
typedef AutoDisposeFamilyNotifier<S, A> = FamilyNotifier<S, A>;
typedef AutoDisposeAsyncNotifier<T> = AsyncNotifier<T>;
typedef AutoDisposeNotifier<T> = Notifier<T>;
typedef AutoDisposeRef = Ref;
typedef AutoDisposeAsyncNotifierProviderRef = Ref;
typedef AsyncNotifierBase<T> = AsyncNotifier<T>;

extension AsyncValueCompat<T> on AsyncValue<T> {
  T? get valueOrNull => whenOrNull(data: (v) => v);
}

class StateNotifierCompat<T> extends Notifier<T> {
  StateNotifierCompat(this._create);
  final T Function(Ref) _create;

  @override
  T build() => _create(ref);

  /// Compat shim for Riverpod 2.x `StateProvider.notifier.state`.
  void set(T value) => state = value;

  /// Compat shim: Riverpod 2.x StateProvider had an update() method.
  void update(T Function(T current) cb) => state = cb(state);
}

NotifierProvider<StateNotifierCompat<T>, T> StateProvider<T>(
  T Function(Ref) create, {
  String? name,
}) {
  return NotifierProvider<StateNotifierCompat<T>, T>(
    () => StateNotifierCompat<T>(create),
    name: name,
  );
}
