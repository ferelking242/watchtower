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
