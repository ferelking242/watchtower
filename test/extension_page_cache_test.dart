import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/services/extension_page_cache.dart';

void main() {
  group('ExtensionPageCache', () {
    test('returns deep copies so callers cannot mutate cached results', () async {
      final cache = ExtensionPageCache();
      final key = _key('source-a');
      final sourcePages = MPages(
        hasNextPage: true,
        list: [
          MManga(
            name: 'Original',
            genre: ['Drama'],
            chapters: [MChapter(name: 'Episode 1')],
          ),
        ],
      );

      final first = await cache.getOrLoad(key, () async => sourcePages);
      final firstPages = first!;
      firstPages.list.first.name = 'Changed';
      firstPages.list.first.genre!.add('Changed');
      firstPages.list.first.chapters!.first.name = 'Changed';

      final second = await cache.getOrLoad(
        key,
        () => throw StateError('a valid entry should be reused'),
      );
      final secondPages = second!;
      expect(secondPages.list.first.name, 'Original');
      expect(secondPages.list.first.genre, ['Drama']);
      expect(secondPages.list.first.chapters!.first.name, 'Episode 1');
      expect(identical(firstPages, secondPages), isFalse);
      expect(identical(firstPages.list.first, secondPages.list.first), isFalse);
    });

    test('coalesces concurrent loads and returns independent copies', () async {
      final cache = ExtensionPageCache();
      final completer = Completer<MPages?>();
      var loads = 0;
      Future<MPages?> loader() {
        loads++;
        return completer.future;
      }

      final firstFuture = cache.getOrLoad(_key('source-a'), loader);
      final secondFuture = cache.getOrLoad(_key('source-a'), loader);
      completer.complete(_pages('Loaded once'));
      final results = await Future.wait([firstFuture, secondFuture]);

      expect(loads, 1);
      expect(results.map((pages) => pages!.list.single.name), [
        'Loaded once',
        'Loaded once',
      ]);
      expect(identical(results[0], results[1]), isFalse);
    });

    test('expires entries and keeps the cache bounded by LRU order', () async {
      var now = DateTime.utc(2026, 1, 1);
      final cache = ExtensionPageCache(
        ttl: const Duration(minutes: 1),
        maxEntries: 2,
        clock: () => now,
      );
      var loads = 0;

      Future<MPages?> load(String name) async {
        loads++;
        return _pages(name);
      }

      await cache.getOrLoad(_key('a'), () => load('A'));
      await cache.getOrLoad(_key('b'), () => load('B'));
      await cache.getOrLoad(_key('a'), () => load('unexpected A reload'));
      await cache.getOrLoad(_key('c'), () => load('C'));
      expect(cache.length, 2);
      await cache.getOrLoad(_key('b'), () => load('B reloaded'));
      expect(loads, 4);

      now = now.add(const Duration(minutes: 1));
      await cache.getOrLoad(_key('c'), () => load('C expired'));
      expect(loads, 5);
    });

    test('invalidating a source prevents stale in-flight data being cached',
        () async {
      final cache = ExtensionPageCache();
      final staleRequest = Completer<MPages?>();
      final key = _key('source-a');
      final staleFuture = cache.getOrLoad(key, () => staleRequest.future);

      cache.invalidateSourceKey('source-a');
      await cache.getOrLoad(key, () async => _pages('Fresh'));
      staleRequest.complete(_pages('Stale'));
      await staleFuture;

      final result = await cache.getOrLoad(
        key,
        () => throw StateError('the fresh value should be cached'),
      );
      expect(result!.list.single.name, 'Fresh');
    });
  });
}

ExtensionPageCacheKey _key(String sourceKey) => ExtensionPageCacheKey(
  sourceKey: sourceKey,
  service: 'popular',
  page: 1,
);

MPages _pages(String name) =>
    MPages(list: [MManga(name: name)], hasNextPage: false);
