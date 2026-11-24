import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/widgets/catalog_bulk_download_sheet.dart';

MManga _video(String link) => MManga(name: link, link: link);

/// Loader that replays canned pages and records how many were requested.
CataloguePageLoader _loader(
  List<({List<MManga> items, bool hasMore})> pages, {
  void Function(int calls)? onCall,
}) {
  var calls = 0;
  return () async {
    final index = calls < pages.length ? calls : pages.length - 1;
    calls++;
    onCall?.call(calls);
    return pages[index];
  };
}

void main() {
  group('isBulkDownloadTarget', () {
    test('keeps entries that carry a video link', () {
      expect(isBulkDownloadTarget(_video('https://x.test/video/1')), isTrue);
    });

    test('drops entries without a link', () {
      expect(isBulkDownloadTarget(MManga(name: 'No link')), isFalse);
      expect(isBulkDownloadTarget(_video('   ')), isFalse);
    });

    test('drops collection rows, which open a sub-list instead', () {
      expect(
        isBulkDownloadTarget(
          MManga(name: 'Studio', link: 'https://x.test/video?o=playlist-1'),
        ),
        isFalse,
      );
      expect(
        isBulkDownloadTarget(
          MManga(
            name: 'Studio',
            link: 'https://x.test/studio',
            collectionId: 'studio_1',
          ),
        ),
        isFalse,
      );
    });
  });

  group('CatalogueDrain', () {
    test('collects every page until the catalogue reports its end', () async {
      final drain = CatalogueDrain(
        loadMore: _loader([
          (items: [_video('https://x.test/1')], hasMore: true),
          (items: [_video('https://x.test/2')], hasMore: true),
          (items: [_video('https://x.test/3')], hasMore: false),
        ]),
      );

      await drain.run();

      expect(drain.items.map((item) => item.link), [
        'https://x.test/1',
        'https://x.test/2',
        'https://x.test/3',
      ]);
      expect(drain.pages, 3);
    });

    test('hands each new batch to onPage with the page number', () async {
      final batches = <int>[];
      final drain = CatalogueDrain(
        loadMore: _loader([
          (items: [_video('https://x.test/1')], hasMore: true),
          (items: [_video('https://x.test/2')], hasMore: false),
        ]),
        onPage: (fresh, pages) => batches.add(pages),
      );

      await drain.run();

      expect(batches, [1, 2]);
    });

    test('ignores a card repeated across a page boundary', () async {
      final drain = CatalogueDrain(
        loadMore: _loader([
          (items: [_video('https://x.test/1')], hasMore: true),
          (
            items: [_video('https://x.test/1'), _video('https://x.test/2')],
            hasMore: false,
          ),
        ]),
      );

      await drain.run();

      expect(drain.items.map((item) => item.link), [
        'https://x.test/1',
        'https://x.test/2',
      ]);
    });

    test('stops after three consecutive empty pages', () async {
      var calls = 0;
      final drain = CatalogueDrain(
        loadMore: _loader(
          [
            (items: [_video('https://x.test/1')], hasMore: true),
            (items: const <MManga>[], hasMore: true),
          ],
          onCall: (count) => calls = count,
        ),
      );

      await drain.run();

      // One useful page, then three stalled ones.
      expect(calls, 4);
      expect(drain.items, hasLength(1));
    });

    test('stops at the requested count without fetching more pages', () async {
      var calls = 0;
      final drain = CatalogueDrain(
        limit: 2,
        loadMore: _loader(
          [
            (
              items: [_video('https://x.test/1'), _video('https://x.test/2')],
              hasMore: true,
            ),
            (items: [_video('https://x.test/3')], hasMore: true),
          ],
          onCall: (count) => calls = count,
        ),
      );

      await drain.run();

      expect(calls, 1);
      expect(drain.items.map((item) => item.link), [
        'https://x.test/1',
        'https://x.test/2',
      ]);
    });

    test('truncates the page that overshoots the requested count', () async {
      final drain = CatalogueDrain(
        limit: 2,
        loadMore: _loader([
          (
            items: [
              _video('https://x.test/1'),
              _video('https://x.test/2'),
              _video('https://x.test/3'),
            ],
            hasMore: true,
          ),
        ]),
      );

      await drain.run();

      expect(drain.items, hasLength(2));
    });

    test('leaves the rows alone when the sheet is closed', () async {
      late CatalogueDrain drain;
      drain = CatalogueDrain(
        loadMore: () async {
          drain.stop();
          return (items: [_video('https://x.test/1')], hasMore: true);
        },
      );

      await drain.run();

      expect(drain.stopped, isTrue);
      expect(drain.items, isEmpty);
    });

    test('skips rows that cannot be queued', () async {
      final drain = CatalogueDrain(
        loadMore: _loader([
          (
            items: [
              _video('https://x.test/1'),
              MManga(name: 'No link'),
              MManga(
                name: 'Studio',
                link: 'https://x.test/studio',
                collectionId: 'studio_1',
              ),
            ],
            hasMore: false,
          ),
        ]),
      );

      await drain.run();

      expect(drain.items.map((item) => item.link), ['https://x.test/1']);
    });
  });

  group('showCatalogBulkDownloadSheet', () {
    testWidgets('opens on the tap, without waiting for the drain', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final loaded = [_video('https://x.test/1')];
      final gate = Completer<({List<MManga> items, bool hasMore})>();
      var drainCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showCatalogBulkDownloadSheet(
                    context: context,
                    ref: ref,
                    source: Source(name: 'Test', itemType: ItemType.manga),
                    items: loaded,
                    loadMore: () {
                      drainCalls++;
                      return gate.future;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The box is on screen while the very first catalogue page is still
      // pending: waiting for the drain before showing it was the bug.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('Loading the catalogue · 1 items'),
        findsOneWidget,
      );
      expect(drainCalls, 1);

      // The drain then feeds the open sheet.
      gate.complete((
        items: [...loaded, _video('https://x.test/2')],
        hasMore: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The drain is over, so the banner is gone and the sheet still stands.
      expect(find.textContaining('Loading the catalogue'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
