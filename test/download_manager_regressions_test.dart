import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/services/download_manager/download_connectivity.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart'
    show DownloadPoolInitializationGate;
import 'package:watchtower/utils/mock_isar.dart';

void main() {
  group('Wi-Fi-only download gate', () {
    test('permits Wi-Fi and ethernet only', () {
      expect(hasWifiOrEthernet([ConnectivityResult.wifi]), isTrue);
      expect(hasWifiOrEthernet([ConnectivityResult.ethernet]), isTrue);
      expect(hasWifiOrEthernet([ConnectivityResult.mobile]), isFalse);
      expect(hasWifiOrEthernet([ConnectivityResult.none]), isFalse);
    });
  });

  group('download pool initialization', () {
    test('coalesces concurrent worker startup requests', () async {
      final gate = DownloadPoolInitializationGate();
      final startup = Completer<void>();
      var startupCalls = 0;

      final first = gate.initialize(() {
        startupCalls++;
        return startup.future;
      });
      final second = gate.initialize(() async {
        startupCalls++;
      });

      expect(startupCalls, 1);
      startup.complete();
      await Future.wait([first, second]);

      expect(startupCalls, 1);
      expect(gate.isInitialized, isTrue);
    });

    test('failed worker startup can be retried', () async {
      final gate = DownloadPoolInitializationGate();
      var startupCalls = 0;

      await expectLater(
        gate.initialize(() async {
          startupCalls++;
          throw StateError('simulated worker startup failure');
        }),
        throwsA(isA<StateError>()),
      );
      expect(gate.isInitialized, isFalse);

      await gate.initialize(() async {
        startupCalls++;
      });

      expect(startupCalls, 2);
      expect(gate.isInitialized, isTrue);
    });
  });

  group('download worker reservation', () {
    const downloadId = 91234567;

    tearDown(() => ActiveDownloadRegistry.unregister(downloadId));

    test('only one scheduler can claim a chapter', () {
      expect(
        ActiveDownloadRegistry.tryRegisterInternal(
          downloadId,
          '$downloadId',
          itemType: ItemType.manga,
          source: 'test',
        ),
        isTrue,
      );
      expect(
        ActiveDownloadRegistry.tryRegisterInternal(
          downloadId,
          '$downloadId',
          itemType: ItemType.manga,
          source: 'test',
        ),
        isFalse,
      );
      expect(ActiveDownloadRegistry.isActive(downloadId), isTrue);
    });

    test('cancel is idempotent and clears the slot', () {
      expect(
        ActiveDownloadRegistry.tryRegisterInternal(
          downloadId,
          '$downloadId',
          itemType: ItemType.manga,
          source: 'test',
        ),
        isTrue,
      );
      expect(ActiveDownloadRegistry.isActive(downloadId), isTrue);
      // Annulation double : ne doit pas planter ni launcher d'opération
      // fantôme (source classique du RangeError length quand deux isolate
      // se battent pour le même .part).
      ActiveDownloadRegistry.cancel(downloadId);
      ActiveDownloadRegistry.cancel(downloadId);
      expect(ActiveDownloadRegistry.isActive(downloadId), isFalse);
    });
  });

  group('persisted download queue', () {
    late MockIsar testIsar;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testIsar = MockIsar();
      app.isar = testIsar;
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('new chapter is persisted before queueing completes', () async {
      final chapter = _testChapter(930001);

      await container.read(addDownloadToQueueProvider(chapter: chapter).future);

      final queued = testIsar.downloads.getSync(chapter.id!);
      expect(queued, isNotNull);
      expect(testIsar.chapters.getSync(chapter.id!), same(chapter));
      expect(queued!.isDownload, isFalse);
      expect(queued.isStartDownload, isTrue);
      expect(queued.status, 'queued');
      expect(queued.chapter.value, same(chapter));
    });

    test('legacy chapter relation is restored from mangaId', () async {
      final manga = _testManga(932001);
      testIsar.seed<Manga>(manga.id!, manga);
      final chapter = Chapter(
        id: 930002,
        mangaId: manga.id,
        name: 'Legacy chapter',
        url: 'https://example.invalid/legacy',
      );

      await container.read(addDownloadToQueueProvider(chapter: chapter).future);

      expect(chapter.manga.value, same(manga));
      expect(
        testIsar.downloads.getSync(chapter.id!)!.chapter.value,
        same(chapter),
      );
    });

    test('corrupt manga reads become a clear queue error', () {
      app.isar = _CorruptMangaIsar();
      final chapter = Chapter(
        id: 930003,
        mangaId: 932003,
        name: 'Unreadable manga relation',
        url: 'https://example.invalid/corrupt',
      );

      expect(
        () => ensureChapterLinksLoaded(chapter),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('mangaId=932003'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('RangeError'),
              ),
        ),
      );
    });

    test('failed, cancelled, paused, and legacy rows are re-queued', () async {
      final cases = <(String?, bool?, bool?)>[
        ('failed', false, false),
        ('cancelled', false, false),
        ('paused', false, false),
        (null, null, null),
      ];

      for (var index = 0; index < cases.length; index++) {
        final id = 930010 + index;
        final chapter = _testChapter(id);
        final (status, isDownload, isStartDownload) = cases[index];
        final existing = Download(
          id: id,
          succeeded: 4,
          failed: 1,
          total: 5,
          isDownload: isDownload,
          isStartDownload: isStartDownload,
          status: status,
        )..chapter.value = chapter;
        testIsar.seed<Download>(id, existing);

        await container.read(
          addDownloadToQueueProvider(chapter: chapter).future,
        );

        final queued = testIsar.downloads.getSync(id)!;
        expect(queued.isDownload, isFalse, reason: status);
        expect(queued.isStartDownload, isTrue, reason: status);
        expect(queued.failed, 0, reason: status);
        expect(queued.total, 1, reason: status);
        expect(queued.status, 'queued', reason: status);
      }
    });

    test('queue write errors propagate instead of reporting success', () async {
      final failingIsar = _FailingTransactionIsar();
      app.isar = failingIsar;
      final chapter = _testChapter(930020);

      await expectLater(
        container.read(addDownloadToQueueProvider(chapter: chapter).future),
        throwsA(isA<StateError>()),
      );
      expect(failingIsar.downloads.getSync(chapter.id!), isNull);
    });

    test('scheduler dispatches a persisted row to its worker', () async {
      final failedChapter = _testChapter(930030);
      final nextChapter = _testChapter(930031);
      final workerStarts = <int>[];
      final workerStatuses = <int, String?>{};
      final failedWorker = downloadChapterProvider(
        chapter: failedChapter,
        useWifi: false,
      ).overrideWith((ref) async {
        workerStarts.add(failedChapter.id!);
        final queued = testIsar.downloads.getSync(failedChapter.id!)!;
        workerStatuses[failedChapter.id!] = queued.status;
        testIsar.writeTxnSync(() {
          testIsar.downloads.putSync(
            queued
              ..isDownload = false
              ..isStartDownload = false
              ..status = 'failed',
          );
        });
      });
      final nextWorker = downloadChapterProvider(
        chapter: nextChapter,
        useWifi: false,
      ).overrideWith((ref) async {
        workerStarts.add(nextChapter.id!);
        final queued = testIsar.downloads.getSync(nextChapter.id!)!;
        workerStatuses[nextChapter.id!] = queued.status;
        testIsar.writeTxnSync(() {
          testIsar.downloads.putSync(
            queued
              ..isDownload = true
              ..isStartDownload = false,
          );
        });
      });
      container.dispose();
      container = ProviderContainer(
        overrides: [failedWorker, nextWorker],
      );

      await container.read(
        addDownloadToQueueProvider(chapter: failedChapter).future,
      );
      await container.read(
        addDownloadToQueueProvider(chapter: nextChapter).future,
      );
      await container.read(processDownloadsProvider(useWifi: false).future);

      expect(workerStarts, containsAll([failedChapter.id, nextChapter.id]));
      expect(workerStatuses.values, everyElement('fetching_metadata'));
      expect(
        testIsar.downloads.getSync(failedChapter.id!)!.status,
        'failed',
      );
      expect(testIsar.downloads.getSync(nextChapter.id!)!.isDownload, isTrue);
    });

    test('scheduler recovers queued rows with stale start flags', () async {
      final chapter = _testChapter(930032);
      var workerStarted = false;
      final worker = downloadChapterProvider(
        chapter: chapter,
        useWifi: false,
      ).overrideWith((ref) async {
        workerStarted = true;
        final queued = testIsar.downloads.getSync(chapter.id!)!;
        testIsar.writeTxnSync(() {
          testIsar.downloads.putSync(
            queued
              ..isDownload = true
              ..isStartDownload = false
              ..status = 'completed',
          );
        });
      });
      container.dispose();
      container = ProviderContainer(overrides: [worker]);

      final staleQueueRow = Download(
        id: chapter.id,
        succeeded: 0,
        failed: 0,
        total: 1,
        isDownload: false,
        isStartDownload: false,
        status: 'queued',
      )..chapter.value = chapter;
      testIsar.seed<Download>(chapter.id!, staleQueueRow);

      await container.read(processDownloadsProvider(useWifi: false).future);

      expect(workerStarted, isTrue);
      expect(testIsar.downloads.getSync(chapter.id!)!.isDownload, isTrue);
    });
  });

  group('Download Isar serialization', () {
    test('estimates room for each persisted string field', () {
      final title = List.filled(62, 'x').join();
      final download = Download(
        id: 930040,
        succeeded: 0,
        failed: 0,
        total: 1,
        isDownload: false,
        isStartDownload: true,
        title: title,
        quality: 'Original',
        posterUrl: 'https://example.invalid/poster.jpg',
        filePath: '/tmp/chapter.cbz',
        status: 'fetching_metadata',
      );
      const staticSize = 59;
      final offsets = List<int>.filled(13, 0)..[12] = staticSize;

      // The regression is in generated Isar size estimation. Check the
      // generated schema directly so the test does not require native Isar.
      // ignore: invalid_use_of_protected_member
      final estimatedSize = DownloadSchema.estimateSize(
        download,
        offsets,
        const <Type, List<int>>{},
      );
      final strings = [
        download.title,
        download.quality,
        download.posterUrl,
        download.filePath,
        download.status,
      ].whereType<String>();
      final expectedSize = strings.fold<int>(
        staticSize,
        (size, value) => size + 3 + value.length * 3,
      );

      expect(estimatedSize, expectedSize);
    });
  });
}

Chapter _testChapter(int id) {
  final manga = _testManga(id + 1000);
  return Chapter(
    id: id,
    mangaId: manga.id,
    name: 'Chapter $id',
    url: 'https://example.invalid/$id',
  )..manga.value = manga;
}

Manga _testManga(int id) {
  return Manga(
    id: id,
    source: 'test',
    author: '',
    artist: '',
    genre: const [],
    imageUrl: '',
    lang: 'en',
    link: '',
    name: 'Test manga',
    status: Status.ongoing,
    description: '',
    sourceId: 0,
  );
}

class _FailingTransactionIsar extends MockIsar {
  @override
  T writeTxnSync<T>(T Function() callback, {bool silent = false}) {
    throw StateError('simulated Isar write failure');
  }
}

class _CorruptMangaIsar extends MockIsar {
  late final _CorruptMangaCollection _mangaCollection =
      _CorruptMangaCollection(this);

  @override
  IsarCollection<T> collection<T>() {
    if (T == Manga) return _mangaCollection as IsarCollection<T>;
    return super.collection<T>();
  }
}

class _CorruptMangaCollection extends MockIsarCollection<Manga> {
  _CorruptMangaCollection(MockIsar isar) : super(isar);

  @override
  Manga? getSync(int id) => throw RangeError('index 62, length 59');
}
