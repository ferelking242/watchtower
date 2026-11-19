import 'dart:async';

/// Lets a queue-setting change wake the running download scheduler so the new
/// limits apply at once instead of on the next 900 ms poll.
///
/// The scheduler registers its current tick's completer; completing it makes
/// the tick's delay resolve immediately. Kept in its own file so both the
/// scheduler and the settings providers can import it without a cycle.
Completer<void>? _wakeup;

/// Applies a *lowered* limit right away, without waiting for the next tick.
///
/// Waking the scheduler only shortens the wait; it still has to re-read the
/// queue and rebuild its state. The scheduler registers a pass that stops the
/// over-budget workers directly, so moving "simultaneous" from 7 to 3 stops the
/// four extra downloads on the spot instead of after they finish.
void Function()? _applyLimitsNow;

void registerDownloadQueueWakeup(Completer<void> wakeup) => _wakeup = wakeup;

void clearDownloadQueueWakeup(Completer<void> wakeup) {
  if (identical(_wakeup, wakeup)) _wakeup = null;
}

/// Registered by the scheduler while it runs; cleared when it stops so a
/// settings change on an idle queue does not try to preempt anything.
void registerDownloadLimitApplier(void Function() apply) =>
    _applyLimitsNow = apply;

void clearDownloadLimitApplier(void Function() apply) {
  if (identical(_applyLimitsNow, apply)) _applyLimitsNow = null;
}

/// Completes the current tick's wakeup so the scheduler re-evaluates now, and
/// stops the over-budget workers immediately when the scheduler is running.
void wakeDownloadQueueScheduler() {
  final wakeup = _wakeup;
  if (wakeup != null && !wakeup.isCompleted) wakeup.complete();
  _applyLimitsNow?.call();
}
