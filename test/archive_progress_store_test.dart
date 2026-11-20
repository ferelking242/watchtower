import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/services/download_manager/archive_progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ArchiveProgressStore.instance.resetForTest();
  });

  group('ArchiveProgress', () {
    test('reports a determinate value from done/total', () {
      const progress = ArchiveProgress(done: 3, total: 6);
      expect(progress.value, 0.5);
    });

    test('reports no value when the pass is indeterminate', () {
      const progress = ArchiveProgress(done: 0, total: 1, indeterminate: true);
      expect(progress.value, isNull);
    });

    test('survives a JSON round-trip including the indeterminate flag', () {
      const progress = ArchiveProgress(done: 2, total: 8, indeterminate: true);
      final restored = ArchiveProgress.fromJson(progress.toJson());
      expect(restored, isNotNull);
      expect(restored!.done, 2);
      expect(restored.total, 8);
      expect(restored.indeterminate, isTrue);
    });

    test('drops a payload with no usable total', () {
      expect(ArchiveProgress.fromJson({'done': 1, 'total': 0}), isNull);
    });
  });

  group('ArchiveProgressStore', () {
    test('markIndeterminate drives the golden bar with no percentage', () {
      final store = ArchiveProgressStore.instance;
      store.clear(9001);

      store.markIndeterminate(9001);

      final entry = store.of(9001);
      expect(entry, isNotNull);
      expect(entry!.indeterminate, isTrue);
      expect(entry.value, isNull);

      store.clear(9001);
      expect(store.of(9001), isNull);
    });

    test('set replaces the indeterminate marker with real progress', () {
      final store = ArchiveProgressStore.instance;
      store.markIndeterminate(9002);
      store.set(9002, done: 5, total: 10);

      final entry = store.of(9002)!;
      expect(entry.indeterminate, isFalse);
      expect(entry.value, 0.5);

      store.clear(9002);
    });

    test('publishes every tick but coalesces the persisted writes', () async {
      // A 200-page chapter calls set() once per page; writing the whole map to
      // SharedPreferences each time is what stalled the packing pass.
      final store = ArchiveProgressStore.instance;
      store.clear(9100);

      for (var done = 1; done <= 20; done++) {
        store.set(9100, done: done, total: 20);
      }

      // The UI sees the latest value immediately.
      expect(store.of(9100)!.done, 20);
      // The debounced write has not landed yet.
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('watchtower_archive_progress'), isNull);

      await store.flushForTest();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('watchtower_archive_progress'), contains('9100'));

      store.clear(9100);
    });

    test('clear persists immediately so no marker outlives the pass', () async {
      final store = ArchiveProgressStore.instance;
      store.set(9101, done: 1, total: 2);
      await store.flushForTest();

      store.clear(9101);
      // clear() is synchronous by API, so let its fire-and-forget write land.
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('watchtower_archive_progress'), '{}');
    });
  });

  group('ArchiveProgressStore cold start', () {
    test('drops a second-pass marker no worker owns', () async {
      // A process killed while packing wrote this marker; on the next launch
      // nothing is packing, so restoring it left the row with an animated
      // golden bar for the whole download.
      SharedPreferences.setMockInitialValues({
        'watchtower_archive_progress':
            '{"4242":{"done":0,"total":1,"indeterminate":true}}',
      });
      final store = ArchiveProgressStore.instance;
      store.resetForTest();

      await store.load(isLive: (id) => false);

      expect(store.of(4242), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('watchtower_archive_progress'), '{}');
    });

    test('keeps the marker of a chapter this process is still working on', () async {
      SharedPreferences.setMockInitialValues({
        'watchtower_archive_progress':
            '{"4243":{"done":3,"total":10,"indeterminate":false}}',
      });
      final store = ArchiveProgressStore.instance;
      store.resetForTest();

      await store.load(isLive: (id) => id == 4243);

      final entry = store.of(4243)!;
      expect(entry.done, 3);
      expect(entry.value, 0.3);
      store.clear(4243);
    });

    test('restores everything when no liveness filter is given', () async {
      SharedPreferences.setMockInitialValues({
        'watchtower_archive_progress':
            '{"4244":{"done":1,"total":4,"indeterminate":false}}',
      });
      final store = ArchiveProgressStore.instance;
      store.resetForTest();

      await store.load();

      expect(store.of(4244)!.value, 0.25);
      store.clear(4244);
    });
  });
}
