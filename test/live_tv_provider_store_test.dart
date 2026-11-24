import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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

  const seeded = LiveProvider(
    id: 'market:iptv',
    name: 'IPTV Pro',
    kind: LiveProviderKind.m3u,
    source: 'https://example.com/list.m3u',
    version: '1.0.0',
  );

  test('a fresh store ships no provider at all', () {
    expect(store().read(), isEmpty);
  });

  test('a provider retired from the app is dropped from an upgraded install',
      () async {
    // An install that predates the removal still has the record on disk; it
    // points at an asset the build no longer contains.
    await box.put(
      'providers',
      jsonEncode([
        {
          'id': 'wt-world',
          'name': 'Watchtower World',
          'kind': 'bundled',
          'source': 'assets/live/world.json',
          'isBundled': true,
          'isBuiltin': true,
        },
      ]),
    );

    expect(store().read(), isEmpty);
  });

  test('a provider renamed in the catalogue keeps its install', () async {
    // The five verified catalogues shipped with a `wiflix-` prefix that was
    // later dropped. An install that saved the old id must still read back
    // under the new one, or the Marketplace would offer it as not installed
    // while the stale record keeps fetching.
    await box.put(
      'providers',
      jsonEncode([
        {
          'id': 'wiflix-iptv-org',
          'name': 'IPTV-org — Monde vérifié',
          'kind': 'json',
          'source': 'https://example.com/iptv-org-world.json',
          'version': '1.0.0',
        },
      ]),
    );

    final providers = store().read();
    expect(providers, hasLength(1));
    expect(providers.single.id, 'iptv-org');
    expect(providers.single.source, 'https://example.com/iptv-org-world.json');
  });

  test('renaming does not resurrect a provider the user deleted', () async {
    await box.put(
      'providers',
      jsonEncode([
        {'id': 'wt-world', 'name': 'Watchtower World', 'kind': 'bundled',
          'source': 'assets/live/world.json'},
        {'id': 'wiflix-free-tv', 'name': 'Free-TV', 'kind': 'json',
          'source': 'https://example.com/free-tv-world.json'},
      ]),
    );

    final providers = store().read();
    expect(providers.map((p) => p.id), ['free-tv']);
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

  test('a provider can be removed, and removing twice is harmless', () async {
    await store().save(seeded);

    await store().remove(seeded.id);
    await store().remove(seeded.id);

    expect(store().read(), isEmpty);
  });

  test('disabling a provider survives a reload', () async {
    await store().save(seeded);
    await store().setEnabled(seeded.id, false);

    expect(store().read().single.isEnabled, isFalse);
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
    final id = seeded.id;
    await store().save(seeded.copyWith(version: '0.9.0'));

    final updated = await store().applyUpdates([entryFor(id, version: '1.2.0')]);

    expect(updated.map((p) => p.id), [id]);
    final now = store().read().firstWhere((p) => p.id == id);
    expect(now.version, '1.2.0');
    expect(now.name, 'IPTV Pro');
  });

  test('applyUpdates does nothing when versions match', () async {
    await store().save(seeded);
    expect(
      await store().applyUpdates([
        entryFor(seeded.id, version: seeded.version),
      ]),
      isEmpty,
    );
  });

  test('applyUpdates does not downgrade', () async {
    final id = seeded.id;
    await store().save(seeded.copyWith(version: '99.0.0'));

    final updated = await store().applyUpdates([entryFor(id, version: '1.2.0')]);

    expect(updated, isEmpty);
    expect(store().read().firstWhere((p) => p.id == id).version, '99.0.0');
  });

  test('version comparison is numeric, not lexicographic', () async {
    final id = seeded.id;
    await store().save(seeded.copyWith(version: '1.9.0'));

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

  test('unreadable stored json degrades to an empty list instead of throwing',
      () async {
    await box.put('providers', 'not json');

    expect(store().read(), isEmpty);
  });

  test('providers sort by name, case-insensitively', () async {
    await store().save(seeded.copyWith(name: 'zzz lower'));
    await store().save(
      const LiveProvider(
        id: 'market:aaa',
        name: 'Aaa Upper',
        kind: LiveProviderKind.m3u,
        source: 'https://b',
      ),
    );

    expect(store().read().map((p) => p.name), ['Aaa Upper', 'zzz lower']);
  });
}
