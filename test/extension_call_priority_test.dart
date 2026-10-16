import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/lib.dart';

/// One source runs on one non-reentrant extension runtime, so every call for
/// that source is serialized. These assertions pin the ordering contract: the
/// call that resolves the video URL must never queue behind the metadata fetch
/// or the decorative detail tabs.
void main() {
  group('extension call priority', () {
    test('getVideoList outranks every other call', () {
      final playback = ExtensionServiceRegistry.priorityFor('getVideoList');

      for (final serviceType in [
        'getDetail',
        'getPopular',
        'getLatestUpdates',
        'search',
        'getCustomList',
        'getRecommendations',
        'getComments',
        'getSuggestions',
        null,
      ]) {
        expect(
          playback,
          lessThan(ExtensionServiceRegistry.priorityFor(serviceType)),
          reason: '$serviceType must yield to getVideoList',
        );
      }
    });

    test('decorative tabs yield to detail and listings', () {
      final detail = ExtensionServiceRegistry.priorityFor('getDetail');

      for (final serviceType in [
        'getRecommendations',
        'getComments',
        'getSuggestions',
      ]) {
        expect(
          detail,
          lessThan(ExtensionServiceRegistry.priorityFor(serviceType)),
          reason: '$serviceType must wait for getDetail',
        );
      }
    });

    test('unknown and null service types are non-playback', () {
      final unknown = ExtensionServiceRegistry.priorityFor('getSomethingNew');
      expect(unknown, ExtensionServiceRegistry.priorityFor(null));
      expect(
        ExtensionServiceRegistry.priorityFor('getVideoList'),
        lessThan(unknown),
      );
    });

    test('priority buckets stay within the queue size', () {
      // `_ExtensionSourceQueue` keeps one bucket per distinct priority, so a
      // new tier must extend its bucket list too.
      for (final serviceType in [
        'getVideoList',
        'getDetail',
        'getRecommendations',
        null,
      ]) {
        final priority = ExtensionServiceRegistry.priorityFor(serviceType);
        expect(priority, inInclusiveRange(0, 2));
      }
    });
  });
}
