import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:watchtower/services/update_notification_service.dart';

/// Drives one "mise en file d'attente" run (the box shown while the selected
/// videos are resolved and pushed to the download queue).
///
/// It is the single source of truth shared by three surfaces that must stay in
/// sync: the in-app box, the Android/iOS notification the box can be sent to,
/// and the worker pool that performs the enqueues. Pausing here suspends the
/// workers; cancelling stops them after the in-flight item.
class BulkEnqueueController extends ChangeNotifier {
  BulkEnqueueController({required this.total});

  /// The controller currently driving a run, so a notification action can find
  /// it back after the dialog was dismissed.
  static BulkEnqueueController? active;

  final int total;

  int done = 0;
  int queued = 0;
  int failed = 0;
  bool cancelled = false;
  bool paused = false;
  bool backgrounded = false;
  bool finished = false;

  Completer<void>? _resumeGate;

  double get progress => total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

  int get remaining => (total - done).clamp(0, total);

  /// Called by each worker before taking a new item. Returns false once the run
  /// was cancelled, and waits while it is paused.
  Future<bool> waitTurn() async {
    while (paused && !cancelled) {
      _resumeGate ??= Completer<void>();
      await _resumeGate!.future;
    }
    return !cancelled;
  }

  void report({int queued = 0, int failed = 0}) {
    done += queued + failed;
    this.queued += queued;
    this.failed += failed;
    _publish();
  }

  void setPaused(bool value) {
    if (paused == value || finished) return;
    paused = value;
    if (!paused) {
      _resumeGate?.complete();
      _resumeGate = null;
    }
    _publish();
  }

  void togglePause() => setPaused(!paused);

  void cancel() {
    if (cancelled || finished) return;
    cancelled = true;
    paused = false;
    _resumeGate?.complete();
    _resumeGate = null;
    _publish();
  }

  void setBackgrounded(bool value) {
    backgrounded = value;
    notifyListeners();
  }

  void complete() {
    finished = true;
    paused = false;
    _resumeGate?.complete();
    _resumeGate = null;
    if (identical(active, this)) active = null;
    unawaited(
      WatchtowerNotificationService.instance.cancelDownloadQueueNotification(),
    );
    notifyListeners();
  }

  void _publish() {
    notifyListeners();
    if (backgrounded && !finished) {
      unawaited(
        WatchtowerNotificationService.instance.showDownloadQueueProgress(
          done: done,
          total: total,
          paused: paused,
          finished: finished,
          queued: queued,
          failed: failed,
        ),
      );
    }
  }

  /// Entry point used by the notification action handler (background taps).
  static Future<void> handleNotificationAction(
    DownloadQueueNotificationAction action,
  ) async {
    final controller = active;
    if (controller == null) return;
    switch (action) {
      case DownloadQueueNotificationAction.pause:
        controller.setPaused(true);
      case DownloadQueueNotificationAction.resume:
        controller.setPaused(false);
      case DownloadQueueNotificationAction.cancel:
        controller.cancel();
    }
  }
}
