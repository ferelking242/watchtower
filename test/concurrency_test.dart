import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/concurrency.dart';

void main() {
  group('mapParallel', () {
    test('runs independent work concurrently', () async {
      var inFlight = 0;
      var peak = 0;
      final results = await mapParallel<int, int>(List.generate(20, (i) => i), 5, (
        i,
      ) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return i * 2;
      });

      expect(results, List.generate(20, (i) => i * 2));
      expect(peak, 5, reason: 'should keep the pool full but not exceed it');
    });

    test('preserves input order even when tasks finish out of order', () async {
      final results = await mapParallel<int, int>(List.generate(10, (i) => i), 10, (
        i,
      ) async {
        await Future<void>.delayed(Duration(milliseconds: 20 - i));
        return i;
      });
      expect(results, List.generate(10, (i) => i));
    });

    test('aborts on first error when propagateErrors is true', () async {
      var started = 0;
      await expectLater(
        mapParallel<int, int>(List.generate(10, (i) => i), 2, (i) async {
          started++;
          if (i == 0) throw StateError('boom');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return i;
        }),
        throwsA(isA<StateError>()),
      );
      expect(started, lessThan(10));
    });

    test('keeps going and records null on error when disabled', () async {
      final results = await mapParallel<int, int>(List.generate(6, (i) => i), 3, (
        i,
      ) async {
        if (i.isEven) throw StateError('even');
        return i;
      }, propagateErrors: false);

      expect(results[1], 1);
      expect(results[3], 3);
      expect(results[5], 5);
      expect(results[0], isNull);
      expect(results[2], isNull);
      expect(results[4], isNull);
    });

    test('handles empty input', () async {
      expect(await mapParallel<int, int>(<int>[], 4, (i) async => i), isEmpty);
    });
  });

  group('forEachParallel', () {
    test('runs each item exactly once under bounded concurrency', () async {
      final seen = <int>[];
      var peak = 0;
      var inFlight = 0;
      await forEachParallel<int>(List.generate(50, (i) => i), 8, (i) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        seen.add(i);
        await Future<void>.delayed(const Duration(milliseconds: 2));
        inFlight--;
      });

      expect(seen.toSet(), List.generate(50, (i) => i).toSet());
      expect(seen.length, 50);
      expect(peak, lessThanOrEqualTo(8));
    });
  });
}
