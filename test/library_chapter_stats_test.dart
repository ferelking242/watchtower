import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/library/providers/library_filter_provider.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// `libraryChapterStatsProvider` replaces the per-rebuild synchronous read of
/// every chapter of the library that the grid/list used to run for their badge
/// counters. It must aggregate exactly the same totals.
Download _download(int id, bool isDownload) => Download(
  id: id,
  succeeded: 0,
  failed: 0,
  total: 0,
  isDownload: isDownload,
  isStartDownload: false,
);

void main() {
  late MockIsar mock;

  setUp(() {
    mock = MockIsar();
    app.isar = mock;
  });

  /// Builds the container *after* the fixture is seeded: the provider emits its
  /// first snapshot (and resolves `.future`) on subscription, and `seed` does
  /// not notify watchers. Riverpod 3 also keeps a provider alive only while
  /// something listens to it.
  Future<Map<int, MangaChapterStats>> readStats() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      libraryChapterStatsProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(libraryChapterStatsProvider.future);
  }

  test('aggregates total, unread and downloaded counts per manga', () async {
    mock.seed<Chapter>(10, Chapter(id: 10, mangaId: 1, name: 'c1'));
    mock.seed<Chapter>(
      11,
      Chapter(id: 11, mangaId: 1, name: 'c2', isRead: true),
    );
    mock.seed<Chapter>(
      12,
      Chapter(id: 12, mangaId: 1, name: 'c3', isRead: true),
    );
    mock.seed<Chapter>(13, Chapter(id: 13, mangaId: 2, name: 'c4'));
    mock.seed<Download>(10, _download(10, true));
    mock.seed<Download>(21, _download(21, false));

    final stats = await readStats();

    expect(stats[1]!.total, 3);
    expect(stats[1]!.unread, 1);
    // A Download row shares its id with the chapter it belongs to, so id 10
    // marks chapter 10 downloaded.
    expect(stats[1]!.downloaded, 1);

    expect(stats[2]!.total, 1);
    expect(stats[2]!.unread, 1);
    expect(stats[2]!.downloaded, 0);
  });

  test('ignores downloads that are not active', () async {
    mock.seed<Chapter>(10, Chapter(id: 10, mangaId: 1, name: 'c1'));
    mock.seed<Download>(10, _download(10, false));
    mock.seed<Download>(21, _download(21, false));

    final stats = await readStats();

    expect(stats[1]!.total, 1);
    expect(stats[1]!.downloaded, 0);
  });

  test('chapters without a mangaId are skipped', () async {
    mock.seed<Chapter>(10, Chapter(id: 10, mangaId: null, name: 'orphan'));
    mock.seed<Chapter>(11, Chapter(id: 11, mangaId: 5, name: 'c1'));

    final stats = await readStats();

    expect(stats.keys, [5]);
    expect(stats[5]!.total, 1);
  });

  test('an empty library yields an empty map', () async {
    final stats = await readStats();
    expect(stats, isEmpty);
  });
}
