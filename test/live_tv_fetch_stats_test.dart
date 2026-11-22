import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/data/live_defaults.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_store.dart';

/// Guards the fetch-stats design: stats must be readable and writable without
/// touching the provider list.
///
/// The first implementation stored the channel count on `LiveProvider` itself,
/// inside the provider list that `liveChannelsProvider` watches. Recording a
/// fetch therefore invalidated the future that had just completed, so every
/// fetch triggered another one — an unbounded download loop that only showed up
/// at runtime. Keeping stats in their own key is what breaks that cycle.
void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('live_tv_stats_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>(LiveProviderStore.boxName);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
  });

  LiveProviderStore store() => LiveProviderStore(box: box);

  test('recording a fetch leaves the provider list untouched', () async {
    final before = store().read().map((p) => p.toJson()).toList();

    await store().recordFetch(LiveDefaults.bundledId, 11554);

    final after = store().read().map((p) => p.toJson()).toList();
    expect(after, before, reason: 'stats must not mutate providers');
  });

  test('a recorded fetch is readable back', () async {
    await store().recordFetch(LiveDefaults.bundledId, 42);

    final stat = store().readFetchStats()[LiveDefaults.bundledId];
    expect(stat, isNotNull);
    expect(stat!.channelCount, 42);
  });

  test('stats of several providers are kept apart', () async {
    await store().recordFetch('a', 1);
    await store().recordFetch('b', 2);

    final stats = store().readFetchStats();
    expect(stats['a']!.channelCount, 1);
    expect(stats['b']!.channelCount, 2);
  });

  test('recording twice keeps one entry with the latest count', () async {
    await store().recordFetch('a', 1);
    await store().recordFetch('a', 9);

    final stats = store().readFetchStats();
    expect(stats.keys.where((k) => k == 'a'), hasLength(1));
    expect(stats['a']!.channelCount, 9);
  });

  test('corrupt stats degrade to empty without throwing', () async {
    await box.put('fetch_stats', 'not json');

    expect(store().readFetchStats(), isEmpty);
  });

  test('no stats means an empty map, not null', () {
    expect(store().readFetchStats(), isEmpty);
  });
}
