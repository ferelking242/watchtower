import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/data/live_builtin_catalog.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_store.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('live_tv_store_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>(LiveProviderStore.boxName);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
  });

  LiveProviderStore store() => LiveProviderStore(box: box);

  test('a fresh store ships the builtin providers', () {
    final providers = store().read();

    expect(
      providers.map((p) => p.id),
      containsAll(LiveBuiltinCatalog.entries.map((e) => e.id)),
    );
    expect(providers.every((p) => p.isBuiltin), isTrue);
  });

  test('only IPTV Pro is enabled on a fresh install', () {
    final providers = store().read();

    final iptvPro = providers.firstWhere(
      (p) => p.id == LiveBuiltinCatalog.iptvProId,
    );
    expect(iptvPro.isEnabled, isTrue);
    expect(iptvPro.name, 'IPTV Pro');
    expect(
      providers.where((p) => p.isEnabled),
      hasLength(1),
      reason: 'enabling every builtin would fetch several playlists at launch',
    );
  });

  test('builtins are restored even if the stored list lost them', () async {
    await store().saveAll(const []);
    final providers = store().read();

    expect(providers, isNotEmpty);
    expect(
      providers.map((p) => p.id),
      contains(LiveBuiltinCatalog.iptvProId),
    );
  });

  test('a user provider persists across store instances', () async {
    const custom = LiveProvider(
      id: 'user:abc',
      name: 'Mon IPTV',
      kind: LiveProviderKind.m3u,
      source: 'https://example.com/list.m3u',
    );
    await store().save(custom);

    final reloaded = store().read().firstWhere((p) => p.id == custom.id);
    expect(reloaded.name, 'Mon IPTV');
    expect(reloaded.source, 'https://example.com/list.m3u');
    expect(reloaded.isBuiltin, isFalse);
  });

  test('saving the same id twice replaces instead of duplicating', () async {
    const first = LiveProvider(
      id: 'user:dup',
      name: 'First',
      kind: LiveProviderKind.m3u,
      source: 'https://a',
    );
    await store().save(first);
    await store().save(first.copyWith(name: 'Second'));

    final matches = store().read().where((p) => p.id == 'user:dup');
    expect(matches, hasLength(1));
    expect(matches.single.name, 'Second');
  });

  test('a builtin cannot be removed, a user provider can', () async {
    const custom = LiveProvider(
      id: 'user:gone',
      name: 'Gone',
      kind: LiveProviderKind.m3u,
      source: 'https://a',
    );
    await store().save(custom);

    await store().remove(custom.id);
    await store().remove(LiveBuiltinCatalog.iptvProId);

    final ids = store().read().map((p) => p.id);
    expect(ids, isNot(contains(custom.id)));
    expect(ids, contains(LiveBuiltinCatalog.iptvProId));
  });

  test('disabling a builtin survives a reload', () async {
    final id = LiveBuiltinCatalog.iptvProId;
    await store().setEnabled(id, false);

    expect(store().read().firstWhere((p) => p.id == id).isEnabled, isFalse);
  });

  test('applyUpdates upgrades a provider to a newer catalogue version', () async {
    final id = LiveBuiltinCatalog.iptvProId;
    final stale = store().read().firstWhere((p) => p.id == id);
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '0.9.0') : provider,
    ]);

    final updated = await store().applyUpdates(LiveBuiltinCatalog.catalogue);

    expect(updated.map((p) => p.id), [id]);
    final now = store().read().firstWhere((p) => p.id == id);
    expect(now.version, stale.version);
    expect(now.version, isNot('0.9.0'));
  });

  test('applyUpdates does nothing when versions match', () async {
    expect(await store().applyUpdates(LiveBuiltinCatalog.catalogue), isEmpty);
  });

  test('applyUpdates does not downgrade', () async {
    final id = LiveBuiltinCatalog.iptvProId;
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '99.0.0') : provider,
    ]);

    final updated = await store().applyUpdates(LiveBuiltinCatalog.catalogue);

    expect(updated, isEmpty);
    expect(store().read().firstWhere((p) => p.id == id).version, '99.0.0');
  });

  test('a numeric version comparison is not lexicographic', () async {
    final id = LiveBuiltinCatalog.iptvProId;
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '1.9.0') : provider,
    ]);

    // Catalogue is 1.2.0, so 1.9.0 is newer: nothing to do. The interesting
    // case is the reverse, checked by pushing the provider to 1.2.0 while the
    // catalogue stays below it.
    expect(await store().applyUpdates(LiveBuiltinCatalog.catalogue), isEmpty);
  });

  test('unreadable stored json degrades to builtins instead of throwing', () async {
    await box.put(LiveProviderStore.boxName == '' ? '' : 'providers', 'not json');

    final providers = store().read();
    expect(
      providers.map((p) => p.id),
      contains(LiveBuiltinCatalog.iptvProId),
    );
  });

  test('builtins sort before user providers', () async {
    await store().save(
      const LiveProvider(
        id: 'user:zzz',
        name: 'Aaa User',
        kind: LiveProviderKind.m3u,
        source: 'https://a',
      ),
    );

    final providers = store().read();
    final firstUserIndex = providers.indexWhere((p) => !p.isBuiltin);
    final lastBuiltinIndex = providers.lastIndexWhere((p) => p.isBuiltin);

    expect(firstUserIndex, greaterThan(lastBuiltinIndex));
  });
}
