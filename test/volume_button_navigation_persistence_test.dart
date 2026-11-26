import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('volume_nav_persistence_test');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('reader_prefs');
  });

  tearDown(() async {
    await Hive.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Flips the toggle, then closes and reopens the box from disk before
  /// reading it back. Closing the box is what makes this a real restart: a
  /// value that only reached Hive's in-memory cache would be lost here.
  Future<bool> afterRestart(
    void Function(ProviderContainer) flip,
    bool Function(ProviderContainer) read,
  ) async {
    final first = ProviderContainer();
    flip(first);
    first.dispose();

    await Hive.close();
    box = await Hive.openBox<dynamic>('reader_prefs');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    return read(second);
  }

  test('the volume-button toggle survives an app restart', () async {
    // The regression: the value was written to `Settings`, but that property
    // is absent from the generated Isar schema, so the write never reached
    // disk and the toggle came back off on every launch.
    final enabled = await afterRestart(
      (c) => c.read(volumeButtonNavigationStateProvider.notifier).set(true),
      (c) => c.read(volumeButtonNavigationStateProvider),
    );

    expect(enabled, isTrue);
  });

  test('the invert toggle survives an app restart', () async {
    final inverted = await afterRestart(
      (c) => c
          .read(invertVolumeButtonNavigationStateProvider.notifier)
          .set(true),
      (c) => c.read(invertVolumeButtonNavigationStateProvider),
    );

    expect(inverted, isTrue);
  });

  test('both toggles default to off on a fresh install', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(volumeButtonNavigationStateProvider), isFalse);
    expect(container.read(invertVolumeButtonNavigationStateProvider), isFalse);
  });

  test('turning a toggle back off is persisted too', () async {
    box.put(kVolumeButtonNavigationKey, true);

    final enabled = await afterRestart(
      (c) => c.read(volumeButtonNavigationStateProvider.notifier).set(false),
      (c) => c.read(volumeButtonNavigationStateProvider),
    );

    expect(enabled, isFalse);
  });

  test('the toggles are stored under their documented keys', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(volumeButtonNavigationStateProvider.notifier).set(true);
    container
        .read(invertVolumeButtonNavigationStateProvider.notifier)
        .set(true);

    // Renaming a key silently orphans every preference already saved by users.
    expect(box.get(kVolumeButtonNavigationKey), isTrue);
    expect(box.get(kInvertVolumeButtonNavigationKey), isTrue);
  });
}
