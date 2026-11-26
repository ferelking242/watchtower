import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/watch/detail/player_tap_resolver.dart';

PointerDownEvent _down(int pointer, double x, double y) => PointerDownEvent(
  pointer: pointer,
  position: Offset(x, y),
);

PointerUpEvent _up(int pointer, double x, double y) => PointerUpEvent(
  pointer: pointer,
  position: Offset(x, y),
);

PointerMoveEvent _move(int pointer, double x, double y) => PointerMoveEvent(
  pointer: pointer,
  position: Offset(x, y),
);

void main() {
  group('PlayerTapResolver', () {
    test('a normal double-tap fires onDoubleTap and reverts the first tap', () {
      fakeAsync((async) {
        final taps = <double>[];
        final doubles = <double>[];
        var reverts = 0;
        final resolver = PlayerTapResolver(
          onTap: () => taps.add(1),
          onTapRevert: () => reverts++,
          onDoubleTap: doubles.add,
        );

        resolver.onPointerDown(_down(1, 500, 300));
        async.elapse(const Duration(milliseconds: 80));
        resolver.onPointerUp(_up(1, 500, 300));
        // The single tap already fired: the controls react without waiting.
        expect(taps, [1]);
        async.elapse(const Duration(milliseconds: 150));
        resolver.onPointerDown(_down(2, 500, 300));
        async.elapse(const Duration(milliseconds: 80));
        resolver.onPointerUp(_up(2, 500, 300));
        async.elapse(const Duration(seconds: 1));

        expect(doubles, [500.0]);
        expect(reverts, 1);
        expect(taps, [1]);
      });
    });

    test('a single tap fires once and is never reverted', () {
      fakeAsync((async) {
        final taps = <int>[];
        var reverts = 0;
        final resolver = PlayerTapResolver(
          onTap: () => taps.add(1),
          onTapRevert: () => reverts++,
          onDoubleTap: (_) {},
        );

        resolver.onPointerDown(_down(1, 500, 300));
        resolver.onPointerUp(_up(1, 500, 300));
        async.elapse(const Duration(seconds: 2));

        expect(taps, [1]);
        expect(reverts, 0);
      });
    });

    test('a slow-ish double-tap (400 ms between taps) still registers', () {
      fakeAsync((async) {
        final doubles = <double>[];
        final resolver = PlayerTapResolver(
          onTap: () {},
          onDoubleTap: doubles.add,
        );

        resolver.onPointerDown(_down(1, 800, 300));
        async.elapse(const Duration(milliseconds: 120));
        resolver.onPointerUp(_up(1, 800, 300));
        async.elapse(const Duration(milliseconds: 400));
        resolver.onPointerDown(_down(2, 800, 300));
        async.elapse(const Duration(milliseconds: 60));
        resolver.onPointerUp(_up(2, 800, 300));
        async.elapse(const Duration(seconds: 1));

        expect(doubles, [800.0]);
      });
    });

    test('an accepted hold does not fire a double-tap from its own press', () {
      fakeAsync((async) {
        final doubles = <double>[];
        var holds = 0;
        final resolver = PlayerTapResolver(
          onTap: () {},
          onDoubleTap: doubles.add,
          onHoldStart: (x) {
            holds++;
            return true;
          },
          onHoldEnd: () {},
        );

        resolver.onPointerDown(_down(1, 900, 300));
        async.elapse(const Duration(milliseconds: 600));
        expect(holds, 1);
        resolver.onPointerUp(_up(1, 900, 300));
        async.elapse(const Duration(milliseconds: 100));
        resolver.onPointerDown(_down(2, 900, 300));
        async.elapse(const Duration(milliseconds: 60));
        resolver.onPointerUp(_up(2, 900, 300));
        async.elapse(const Duration(seconds: 1));

        // The tap that followed the hold is a plain single tap, never a seek.
        expect(doubles, isEmpty);
      });
    });

    test('two double-taps in a row both fire', () {
      fakeAsync((async) {
        final doubles = <double>[];
        final resolver = PlayerTapResolver(
          onTap: () {},
          onDoubleTap: doubles.add,
        );

        for (var i = 0; i < 2; i++) {
          resolver.onPointerDown(_down(1, 900, 300));
          async.elapse(const Duration(milliseconds: 70));
          resolver.onPointerUp(_up(1, 900, 300));
          async.elapse(const Duration(milliseconds: 120));
          resolver.onPointerDown(_down(2, 900, 300));
          async.elapse(const Duration(milliseconds: 70));
          resolver.onPointerUp(_up(2, 900, 300));
          async.elapse(const Duration(milliseconds: 200));
        }
        async.elapse(const Duration(seconds: 1));

        expect(doubles, [900.0, 900.0]);
      });
    });

    test('a drag past the slop is never reported as a tap', () {
      fakeAsync((async) {
        final taps = <int>[];
        final doubles = <double>[];
        final resolver = PlayerTapResolver(
          onTap: () => taps.add(1),
          onDoubleTap: doubles.add,
        );

        resolver.onPointerDown(_down(1, 300, 300));
        async.elapse(const Duration(milliseconds: 60));
        resolver.onPointerMove(_move(1, 420, 300));
        resolver.onPointerUp(_up(1, 420, 300));
        async.elapse(const Duration(seconds: 1));

        expect(taps, isEmpty);
        expect(doubles, isEmpty);
      });
    });

    test('a resting second finger does not swallow the tap', () {
      fakeAsync((async) {
        final doubles = <double>[];
        final resolver = PlayerTapResolver(
          onTap: () {},
          onDoubleTap: doubles.add,
        );

        // Palm down and stays down for the whole sequence.
        resolver.onPointerDown(_down(9, 40, 700));
        resolver.onPointerDown(_down(1, 900, 300));
        async.elapse(const Duration(milliseconds: 70));
        resolver.onPointerUp(_up(1, 900, 300));
        async.elapse(const Duration(milliseconds: 120));
        resolver.onPointerDown(_down(2, 900, 300));
        async.elapse(const Duration(milliseconds: 70));
        resolver.onPointerUp(_up(2, 900, 300));
        async.elapse(const Duration(seconds: 1));

        expect(doubles, [900.0]);
      });
    });
  });
}
