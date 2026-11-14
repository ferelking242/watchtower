import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('nav_display_test');
    Hive.init(dir.path);
    await Hive.openBox('nav_display');
  });

  tearDown(() async {
    await Hive.box('nav_display').clear();
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

  test('sidebar defaults to the left', () {
    final container = freshContainer();
    expect(container.read(navSidebarPositionProvider), 'left');
  });

  test('sidebar can move to the right and back', () {
    final container = freshContainer();
    final notifier = container.read(navSidebarPositionProvider.notifier);

    notifier.set('right');
    expect(container.read(navSidebarPositionProvider), 'right');

    notifier.set('left');
    expect(container.read(navSidebarPositionProvider), 'left');
  });

  test('an unknown sidebar value falls back to the left', () {
    final container = freshContainer();
    container.read(navSidebarPositionProvider.notifier).set('diagonal');
    expect(container.read(navSidebarPositionProvider), 'left');
  });

  test('the sidebar position is persisted', () {
    final container = freshContainer();
    container.read(navSidebarPositionProvider.notifier).set('right');
    expect(Hive.box('nav_display').get('sidebar_position'), 'right');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(navSidebarPositionProvider), 'right');
  });

  test('an unknown stored sidebar value is rejected on read', () {
    Hive.box('nav_display').put('sidebar_position', 'middle');
    final container = freshContainer();
    expect(container.read(navSidebarPositionProvider), 'left');
  });
}
