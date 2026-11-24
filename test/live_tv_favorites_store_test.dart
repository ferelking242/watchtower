import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watchtower/modules/live_tv/data/live_favorites_store.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('live_tv_favorites_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>(LiveFavoritesStore.boxName);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
  });

  LiveFavoritesStore store() => LiveFavoritesStore(box: box);

  test('a favourite saved under a renamed provider still resolves', () async {
    // `LiveChannel.id` embeds the provider id, so dropping the `wiflix-` prefix
    // would silently orphan every channel starred before the rename.
    await box.put('ids', ['wiflix-iptv-org:tf1', 'wiflix-free-tv:arte']);

    expect(store().read(), {'iptv-org:tf1', 'free-tv:arte'});
  });

  test('favourites from untouched providers are left alone', () async {
    await box.put('ids', ['iptv-org-fr:tf1', 'user:abc:mine']);

    expect(store().read(), {'iptv-org-fr:tf1', 'user:abc:mine'});
  });

  test('an id with no separator is kept as-is', () async {
    await box.put('ids', ['weird']);

    expect(store().read(), {'weird'});
  });
}
