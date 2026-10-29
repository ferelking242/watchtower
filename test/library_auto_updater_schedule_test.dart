import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/library_auto_updater.dart';

/// The automatic library update schedule (Mihon "Mises à jour" section) is the
/// only piece of the scheduler that can be reasoned about without a running
/// app, so it is exercised directly: the interval gate, the "never ran" case
/// and the manual-only case.
void main() {
  const hour = 3600 * 1000;

  test('manual only (0 h) never runs', () {
    expect(
      isLibraryUpdateDue(intervalHours: 0, lastRunMs: 0, nowMs: 10 * hour),
      isFalse,
    );
  });

  test('a schedule that never ran is due immediately', () {
    // lastRunMs 0 means "epoch", so any real wall-clock now is far past the
    // interval — the first cold start runs the update.
    final now = DateTime(2026, 10, 27).millisecondsSinceEpoch;
    expect(
      isLibraryUpdateDue(intervalHours: 168, lastRunMs: 0, nowMs: now),
      isTrue,
    );
  });

  test('not due before the interval elapses', () {
    final now = 1000 * hour;
    expect(
      isLibraryUpdateDue(
        intervalHours: 24,
        lastRunMs: now - 23 * hour,
        nowMs: now,
      ),
      isFalse,
    );
  });

  test('due exactly at the interval boundary', () {
    final now = 1000 * hour;
    expect(
      isLibraryUpdateDue(
        intervalHours: 24,
        lastRunMs: now - 24 * hour,
        nowMs: now,
      ),
      isTrue,
    );
  });

  test('due again after the interval elapses', () {
    final now = 1000 * hour;
    expect(
      isLibraryUpdateDue(
        intervalHours: 6,
        lastRunMs: now - 7 * hour,
        nowMs: now,
      ),
      isTrue,
    );
  });

  test('weekly interval is not due after six days', () {
    final now = 1000 * hour;
    expect(
      isLibraryUpdateDue(
        intervalHours: 168,
        lastRunMs: now - 144 * hour,
        nowMs: now,
      ),
      isFalse,
    );
  });
}
