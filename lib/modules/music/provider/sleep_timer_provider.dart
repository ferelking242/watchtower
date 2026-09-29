import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

class SleepTimerNotifier extends Notifier<Duration?> {
  Timer? _timer;

  @override
  Duration? build() => null;

  void setSleepTimer(Duration duration) {
    state = duration;

    _timer = Timer(duration, () {
      //! This can be a reason for app termination in iOS AppStore
      exit(0);
    });
  }

  void cancelSleepTimer() {
    state = null;
    _timer?.cancel();
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, Duration?>(
  SleepTimerNotifier.new,
);
