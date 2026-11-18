import 'dart:async';

/// Lets a queue-setting change wake the running download scheduler so the new
/// limits apply at once instead of on the next 900 ms poll.
///
/// The scheduler registers its current tick's completer; completing it makes
/// the tick's delay resolve immediately. Kept in its own file so both the
/// scheduler and the settings providers can import it without a cycle.
Completer<void>? _wakeup;

void registerDownloadQueueWakeup(Completer<void> wakeup) => _wakeup = wakeup;

void clearDownloadQueueWakeup(Completer<void> wakeup) {
  if (identical(_wakeup, wakeup)) _wakeup = null;
}

/// Completes the current tick's wakeup so the scheduler re-evaluates now.
void wakeDownloadQueueScheduler() {
  final wakeup = _wakeup;
  if (wakeup != null && !wakeup.isCompleted) wakeup.complete();
}
