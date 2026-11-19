import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/more/download_queue/download_slot_allocation.dart';

void main() {
  group('allocateSourceSlots', () {
    test('the user example: 20 vs 10 elements on a 5-slot budget', () {
      final slots = allocateSourceSlots(
        total: 5,
        pendingBySource: const {'src1': 20, 'src2': 10},
        perSourceCap: 10,
      );

      expect(slots['src1'], 2);
      expect(slots['src2'], 3, reason: 'the smaller queue gets the bigger share');
      expect(slots.values.reduce((a, b) => a + b), 5);
    });

    test('the user example: 5+5 elements with src=2 and total=5', () {
      final slots = allocateSourceSlots(
        total: 5,
        pendingBySource: const {'src1': 5, 'src2': 5},
        perSourceCap: 2,
      );

      expect(slots, {'src1': 2, 'src2': 2});
    });

    test('never exceeds the total budget', () {
      for (final total in [1, 2, 3, 5, 10]) {
        final slots = allocateSourceSlots(
          total: total,
          pendingBySource: const {'a': 100, 'b': 50, 'c': 7},
          perSourceCap: 10,
        );
        expect(slots.values.reduce((a, b) => a + b), lessThanOrEqualTo(total));
      }
    });

    test('never exceeds the per-source cap', () {
      final slots = allocateSourceSlots(
        total: 20,
        pendingBySource: const {'a': 100, 'b': 1},
        perSourceCap: 3,
      );

      for (final value in slots.values) {
        expect(value, lessThanOrEqualTo(3));
      }
    });

    test('never gives a source more slots than it has items', () {
      final slots = allocateSourceSlots(
        total: 10,
        pendingBySource: const {'a': 1, 'b': 2, 'c': 40},
        perSourceCap: 10,
      );

      expect(slots['a'], lessThanOrEqualTo(1));
      expect(slots['b'], lessThanOrEqualTo(2));
      expect(slots['c'], lessThanOrEqualTo(40));
    });

    test('a short source does not starve a long one', () {
      // 'a' can only take 1 slot, so the remaining budget must reach 'b'.
      final slots = allocateSourceSlots(
        total: 4,
        pendingBySource: const {'a': 1, 'b': 30},
        perSourceCap: 10,
      );

      expect(slots['a'], 1);
      expect(slots['b'], 3);
    });

    test('single source gets the whole budget up to its cap', () {
      expect(
        allocateSourceSlots(
          total: 5,
          pendingBySource: const {'only': 100},
          perSourceCap: 3,
        ),
        {'only': 3},
      );
      expect(
        allocateSourceSlots(
          total: 5,
          pendingBySource: const {'only': 100},
          perSourceCap: 10,
        ),
        {'only': 5},
      );
    });

    test('sources with no pending work get no slots', () {
      final slots = allocateSourceSlots(
        total: 4,
        pendingBySource: const {'a': 3, 'idle': 0},
        perSourceCap: 10,
      );

      expect(slots.containsKey('idle'), isFalse);
      expect(slots['a'], 3, reason: 'capped by its own pending count');
    });

    test('degenerate inputs yield an empty allocation', () {
      expect(
        allocateSourceSlots(total: 0, pendingBySource: const {'a': 3}, perSourceCap: 5),
        isEmpty,
      );
      expect(
        allocateSourceSlots(total: 5, pendingBySource: const {'a': 3}, perSourceCap: 0),
        isEmpty,
      );
      expect(
        allocateSourceSlots(total: 5, pendingBySource: const {}, perSourceCap: 5),
        isEmpty,
      );
    });

    test('all slots are handed out when the workload allows it', () {
      final slots = allocateSourceSlots(
        total: 6,
        pendingBySource: const {'a': 10, 'b': 10, 'c': 10},
        perSourceCap: 10,
      );

      expect(slots, {'a': 2, 'b': 2, 'c': 2});
      expect(slots.values.reduce((a, b) => a + b), 6);
    });
  });

  group('selectPreemptions', () {
    test('keeps the oldest workers and stops the newest over budget', () {
      final active = [
        const ActiveSlot(downloadId: 1, source: 'a'),
        const ActiveSlot(downloadId: 2, source: 'a'),
        const ActiveSlot(downloadId: 3, source: 'a'),
        const ActiveSlot(downloadId: 4, source: 'a'),
        const ActiveSlot(downloadId: 5, source: 'a'),
        const ActiveSlot(downloadId: 6, source: 'a'),
        const ActiveSlot(downloadId: 7, source: 'a'),
      ];

      final preempted = selectPreemptions(
        slots: active,
        total: 3,
        perSourceCap: 10,
      );

      expect(preempted, [4, 5, 6, 7]);
    });

    test('enforces the per-source cap as well as the total', () {
      final active = [
        const ActiveSlot(downloadId: 1, source: 'a'),
        const ActiveSlot(downloadId: 2, source: 'a'),
        const ActiveSlot(downloadId: 3, source: 'a'),
        const ActiveSlot(downloadId: 4, source: 'b'),
      ];

      final preempted = selectPreemptions(
        slots: active,
        total: 10,
        perSourceCap: 2,
      );

      expect(preempted, [3]);
    });

    test('does not preempt for a share the user never set', () {
      // Five workers on one source with total 10 and src cap 10: nothing is
      // over either limit, so nothing may be stopped.
      final preempted = selectPreemptions(
        slots: const [
          ActiveSlot(downloadId: 1, source: 'a'),
          ActiveSlot(downloadId: 2, source: 'a'),
          ActiveSlot(downloadId: 3, source: 'a'),
          ActiveSlot(downloadId: 4, source: 'a'),
          ActiveSlot(downloadId: 5, source: 'a'),
        ],
        total: 10,
        perSourceCap: 10,
      );

      expect(preempted, isEmpty);
    });

    test('ignores workers that are already stopping', () {
      final active = [
        const ActiveSlot(downloadId: 1, source: 'a'),
        const ActiveSlot(downloadId: 2, source: 'a', preempted: true),
        const ActiveSlot(downloadId: 3, source: 'a'),
      ];

      final preempted = selectPreemptions(
        slots: active,
        total: 1,
        perSourceCap: 10,
      );

      // Worker 2 is already draining: it must not push a live worker out, and
      // it must not be preempted a second time.
      expect(preempted, [3]);
    });

    test('a zero limit stops everything that is still running', () {
      final active = [
        const ActiveSlot(downloadId: 1, source: 'a'),
        const ActiveSlot(downloadId: 2, source: 'b', preempted: true),
        const ActiveSlot(downloadId: 3, source: 'b'),
      ];

      expect(
        selectPreemptions(slots: active, total: 0, perSourceCap: 5),
        [1, 3],
      );
    });
  });

  group('hasCompetingSource', () {
    test('is true while another source is below its share', () {
      expect(
        hasCompetingSource(
          source: 'a',
          startableBySource: const {'a': 10, 'b': 10},
          activeBySource: const {'a': 4, 'b': 0},
          shareBySource: const {'a': 2, 'b': 2},
          perSourceCap: 5,
        ),
        isTrue,
      );
    });

    test('is false when the other source has no pending work left', () {
      expect(
        hasCompetingSource(
          source: 'a',
          startableBySource: const {'a': 10, 'b': 0},
          activeBySource: const {'a': 4, 'b': 0},
          shareBySource: const {'a': 2, 'b': 2},
          perSourceCap: 5,
        ),
        isFalse,
        reason: 'an empty source must not keep a slot idle',
      );
    });

    test('is false when the other source already started all its work', () {
      expect(
        hasCompetingSource(
          source: 'a',
          startableBySource: const {'a': 10, 'b': 2},
          activeBySource: const {'a': 1, 'b': 2},
          shareBySource: const {'a': 2, 'b': 2},
          perSourceCap: 5,
        ),
        isFalse,
        reason: 'a source with nothing left to start must not reserve a slot',
      );
    });

    test('is false when the other source already reached its share', () {
      expect(
        hasCompetingSource(
          source: 'a',
          startableBySource: const {'a': 10, 'b': 10},
          activeBySource: const {'a': 4, 'b': 2},
          shareBySource: const {'a': 2, 'b': 2},
          perSourceCap: 5,
        ),
        isFalse,
      );
    });
  });
}
