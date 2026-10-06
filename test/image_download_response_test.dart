import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';

void main() {
  group('imageDownloadResponseError', () {
    test('rejects non-success HTTP responses', () {
      expect(
        imageDownloadResponseError(
          statusCode: 503,
          headers: const {},
          bodyBytes: const [1, 2, 3],
        ),
        'HTTP 503',
      );
    });

    test('rejects empty success responses', () {
      expect(
        imageDownloadResponseError(
          statusCode: 200,
          headers: const {'content-type': 'image/jpeg'},
          bodyBytes: const [],
        ),
        'empty response body',
      );
    });

    test('rejects HTML returned with an image request', () {
      expect(
        imageDownloadResponseError(
          statusCode: 200,
          headers: const {'Content-Type': 'text/html; charset=utf-8'},
          bodyBytes: '<!doctype html><html>'.codeUnits,
        ),
        isNotNull,
      );
    });

    test('accepts a non-empty image response', () {
      expect(
        imageDownloadResponseError(
          statusCode: 200,
          headers: const {'content-type': 'image/png'},
          bodyBytes: const [137, 80, 78, 71, 13, 10, 26, 10],
        ),
        isNull,
      );
    });
  });
}
