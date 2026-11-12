import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:watchtower/modules/manga/reader/services/page_navigation_service.dart';

/// Records the offsets requested by the navigation service instead of driving
/// a real list, so the scroll maths can be asserted without a widget tree.
class _RecordingOffsetController extends ScrollOffsetController {
  final List<double> offsets = [];
  final List<Duration> durations = [];

  @override
  Future<void> animateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    offsets.add(offset);
    durations.add(duration);
  }
}

void main() {
  group('PageNavigationService continuous scrolling', () {
    late _RecordingOffsetController offsetController;

    PageNavigationService buildService({
      required Size viewport,
      Axis axis = Axis.vertical,
    }) {
      return PageNavigationService(
        itemScrollController: ItemScrollController(),
        scrollOffsetController: offsetController,
        extendedController: ExtendedPageController(),
        viewportSize: () => viewport,
        scrollAxis: () => axis,
      );
    }

    setUp(() {
      offsetController = _RecordingOffsetController();
    });

    test('a forward step moves by 3/4 of the viewport height', () {
      final service = buildService(viewport: const Size(400, 800));
      service.scrollForward();
      expect(offsetController.offsets.single, 800 * 3 / 4);
    });

    test('a backward step is the negative of a forward step', () {
      final service = buildService(viewport: const Size(400, 800));
      service.scrollBackward();
      expect(offsetController.offsets.single, -800 * 3 / 4);
    });

    test('horizontal readers step by the viewport width', () {
      final service = buildService(
        viewport: const Size(400, 800),
        axis: Axis.horizontal,
      );
      service.scrollForward();
      expect(offsetController.offsets.single, 400 * 3 / 4);
    });

    test('an instant step uses a zero-duration animation', () {
      final service = buildService(viewport: const Size(400, 800));
      service.scrollForward(animated: false);
      expect(offsetController.durations.single, Duration.zero);
    });

    test('an unresolved viewport is ignored', () {
      final service = buildService(viewport: Size.zero);
      service.scrollForward();
      expect(offsetController.offsets, isEmpty);
    });
  });
}
