import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/utils/concurrency.dart';

void main() {
  group('bulk download worker slots', () {
    test(
      'resolves a 25-item batch concurrently with stable worker slots',
      () async {
        final activeSlots = <int>{};
        final completed = <int>[];
        var active = 0;
        var peak = 0;

        await forEachParallelWithWorkerSlots(
          List.generate(25, (index) => index),
          4,
          (item, workerSlot) async {
            expect(activeSlots.add(workerSlot), isTrue);
            active++;
            if (active > peak) peak = active;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            completed.add(item);
            active--;
            activeSlots.remove(workerSlot);
          },
        );

        expect(peak, 4);
        expect(completed.length, 25);
        expect(completed.toSet(), Set<int>.from(List.generate(25, (i) => i)));
      },
    );
  });

  group('GetIsolateService worker affinity', () {
    test(
      'keeps a worker slot across async work and restores the outer zone',
      () async {
        final service = getIsolateService;
        expect(service.currentWorkerSlot, isNull);

        final selected = await service.runOnWorkerSlot(2, () async {
          await Future<void>.delayed(Duration.zero);
          return service.currentWorkerSlot;
        });

        expect(selected, 2);
        expect(service.currentWorkerSlot, isNull);
      },
    );

    test('nested work can select a different worker slot', () async {
      final service = getIsolateService;

      final slots = await service.runOnWorkerSlot(1, () async {
        final before = service.currentWorkerSlot;
        final nested = await service.runOnWorkerSlot(
          3,
          () async => service.currentWorkerSlot,
        );
        return (before, nested, service.currentWorkerSlot);
      });

      expect(slots, (1, 3, 1));
    });
  });
}
