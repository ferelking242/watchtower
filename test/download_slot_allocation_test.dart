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
}
