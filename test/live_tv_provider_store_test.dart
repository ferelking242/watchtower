import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/data/live_defaults.dart';
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

  test('a fresh store ships only the bundled provider', () {
    final providers = store().read();

    expect(providers.map((p) => p.id), [LiveDefaults.bundledId]);
    expect(providers.single.isBuiltin, isTrue);
    expect(providers.single.isBundled, isTrue);
    expect(providers.single.kind, LiveProviderKind.bundled);
  });

  test('the bundled provider reads from an asset, not the network', () {
    final provider = store().read().single;

    expect(provider.source, LiveDefaults.bundledAsset);
    expect(provider.source, startsWith('assets/'));
    expect(provider.isEnabled, isTrue);
  });

  test('builtins are restored even if the stored list lost them', () async {
    await store().saveAll(const []);
    final providers = store().read();

    expect(providers, isNotEmpty);
    expect(providers.map((p) => p.id), contains(LiveDefaults.bundledId));
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
    await store().remove(LiveDefaults.bundledId);

    final ids = store().read().map((p) => p.id);
    expect(ids, isNot(contains(custom.id)));
    expect(ids, contains(LiveDefaults.bundledId));
  });

  test('disabling a builtin survives a reload', () async {
    final id = LiveDefaults.bundledId;
    await store().setEnabled(id, false);

    expect(store().read().firstWhere((p) => p.id == id).isEnabled, isFalse);
  });

  LiveProviderCatalogEntry entryFor(
    String id, {
    required String version,
  }) => LiveProviderCatalogEntry(
    id: id,
    name: 'IPTV Pro',
    kind: LiveProviderKind.m3u,
    source: 'https://example.com/list.m3u',
    version: version,
  );

  test('applyUpdates upgrades a provider to a newer catalogue version', () async {
    final id = LiveDefaults.bundledId;
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '0.9.0') : provider,
    ]);

    final updated = await store().applyUpdates([entryFor(id, version: '1.2.0')]);

    expect(updated.map((p) => p.id), [id]);
    final now = store().read().firstWhere((p) => p.id == id);
    expect(now.version, '1.2.0');
    expect(now.name, 'IPTV Pro');
  });

  test('applyUpdates does nothing when versions match', () async {
    final id = LiveDefaults.bundledId;
    expect(
      await store().applyUpdates([
        entryFor(id, version: store().read().single.version),
      ]),
      isEmpty,
    );
  });

  test('applyUpdates does not downgrade', () async {
    final id = LiveDefaults.bundledId;
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '99.0.0') : provider,
    ]);

    final updated = await store().applyUpdates([entryFor(id, version: '1.2.0')]);

    expect(updated, isEmpty);
    expect(store().read().firstWhere((p) => p.id == id).version, '99.0.0');
  });

  test('version comparison is numeric, not lexicographic', () async {
    final id = LiveDefaults.bundledId;
    await store().saveAll([
      for (final provider in store().read())
        provider.id == id ? provider.copyWith(version: '1.9.0') : provider,
    ]);

    // 1.10.0 is newer than 1.9.0 even though '1.10.0' sorts first as a string.
    final updated = await store().applyUpdates([
      entryFor(id, version: '1.10.0'),
    ]);

    expect(updated.map((p) => p.version), ['1.10.0']);
  });

  test('an unknown catalogue id does not create a provider', () async {
    await store().applyUpdates([entryFor('not-installed', version: '9.9.9')]);

    expect(
      store().read().map((p) => p.id),
      isNot(contains('not-installed')),
    );
  });

  test('unreadable stored json degrades to builtins instead of throwing', () async {
    await box.put('providers', 'not json');

    final providers = store().read();
    expect(providers.map((p) => p.id), contains(LiveDefaults.bundledId));
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
