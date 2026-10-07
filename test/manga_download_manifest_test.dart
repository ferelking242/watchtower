import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/manga_download_manifest.dart';

void main() {
  group('MangaDownloadManifest', () {
    test('persists chapter/page state without credentials', () {
      final manifest = reconcileMangaDownloadManifest(
        chapterUrl: 'https://manga.example/chapter/4?token=chapter-secret',
        chapterId: 42,
        mangaId: 12,
        extensionId: '7',
        sourceId: 7,
        chapterMetadata: const {
          'chapterName': 'Chapter 4',
          'seriesName': 'Example',
        },
        pages: [
          PageUrl(
            'https://cdn.example/page.jpg?signature=image-secret&width=900',
            headers: const {
              'Authorization': 'Bearer private',
              'Referer': 'https://manga.example/',
            },
          ),
        ],
        filePaths: const ['/downloads/example/001.jpg'],
        completed: const [false],
      );
      final encoded = manifest.encode();

      expect(encoded, isNot(contains('chapter-secret')));
      expect(encoded, isNot(contains('image-secret')));
      expect(encoded, isNot(contains('Bearer private')));

      final decoded = MangaDownloadManifest.decode(encoded)!;
      expect(decoded.chapterId, 42);
      expect(decoded.mangaId, 12);
      expect(decoded.extensionId, '7');
      expect(decoded.sourceId, 7);
      expect(decoded.chapterMetadata['seriesName'], 'Example');
      expect(decoded.pages.single.filePath, '/downloads/example/001.jpg');
      expect(decoded.pages.single.toJson()['fileName'], '001.jpg');
      expect(decoded.pages.single.state, MangaPageState.pending);
      expect(decoded.pages.single.headers['Referer'], 'https://manga.example/');
      expect(
        decoded.pages.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(decoded.createdAt, greaterThan(0));
      expect(decoded.updatedAt, greaterThan(0));
    });

    test('retains page attempts and failure details for retry', () {
      final previous = MangaDownloadManifest(
        chapterUrl: 'https://manga.example/chapter/4',
        pages: const [
          MangaDownloadPage(
            index: 0,
            url: 'https://cdn.example/page.jpg',
            headers: {},
            filePath: '/downloads/example/001.jpg',
            state: MangaPageState.failed,
            attempts: 2,
            lastError: 'HTTP 403',
            updatedAt: 100,
          ),
        ],
        createdAt: 50,
        updatedAt: 100,
      );

      final retried = reconcileMangaDownloadManifest(
        chapterUrl: previous.chapterUrl,
        pages: [PageUrl('https://cdn.example/page.jpg')],
        filePaths: const ['/downloads/example/001.jpg'],
        completed: const [false],
        previous: previous,
      );

      expect(retried.createdAt, 50);
      expect(retried.pages.single.state, MangaPageState.failed);
      expect(retried.pages.single.attempts, 2);
      expect(retried.pages.single.lastError, 'HTTP 403');
    });

    test('reads legacy version 1 manifests', () {
      final legacy = MangaDownloadManifest.decode('''
        {"version":1,"chapterUrl":"https://manga.example/chapter",
         "pages":[{"index":0,"url":"https://cdn.example/page.jpg",
         "headers":{},"filePath":"/chapter/001.jpg","state":"completed"}]}
      ''');

      expect(legacy, isNotNull);
      expect(legacy!.chapterId, isNull);
      expect(legacy.pages.single.state, MangaPageState.completed);
      expect(legacy.pages.single.attempts, 0);
    });
  });
}
