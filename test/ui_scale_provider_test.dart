import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/more/settings/advanced/providers/ui_scale_provider.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('ui_scale_test');
    Hive.init(dir.path);
    await Hive.openBox('advanced_settings');
  });

  tearDown(() async {
    await Hive.box('advanced_settings').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to 100% when nothing is stored', () {
    final container = freshContainer();
    expect(container.read(uiScaleProvider), 1.0);
  });

  test('steps up and down by the wheel increment', () {
    final container = freshContainer();
    final notifier = container.read(uiScaleProvider.notifier);

    notifier.step(1);
    expect(container.read(uiScaleProvider), closeTo(1.05, 1e-9));
    notifier.step(1);
    expect(container.read(uiScaleProvider), closeTo(1.10, 1e-9));
    notifier.step(-1);
    expect(container.read(uiScaleProvider), closeTo(1.05, 1e-9));
  });

  test('clamps at the zoom limits', () {
    final container = freshContainer();
    final notifier = container.read(uiScaleProvider.notifier);

    for (var i = 0; i < 100; i++) {
      notifier.step(1);
    }
    expect(container.read(uiScaleProvider), kMaxUiScale);

    for (var i = 0; i < 200; i++) {
      notifier.step(-1);
    }
    expect(container.read(uiScaleProvider), kMinUiScale);
  });

  test('persists to the advanced_settings box and survives a rebuild', () {
    final container = freshContainer();
    container.read(uiScaleProvider.notifier).set(1.25);

    expect(Hive.box('advanced_settings').get(kUiScaleKey), 1.25);

    // A fresh container reads the stored value. Use a new container rather
    // than a new Hive box so the assertion exercises the provider's read path.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(uiScaleProvider), closeTo(1.25, 1e-9));
  });

  test('reset returns to 100%', () {
    final container = freshContainer();
    final notifier = container.read(uiScaleProvider.notifier);
    notifier.set(1.4);
    notifier.reset();
    expect(container.read(uiScaleProvider), 1.0);
  });
}
