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
          headers: const {'content-type': 'image/jpeg'},
          bodyBytes: const [
            0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
          ],
        ),
        isNull,
      );
    });

    test('rejects a body shorter than its advertised length', () {
      expect(
        imageDownloadResponseError(
          statusCode: 200,
          headers: const {
            'content-type': 'image/jpeg',
            'content-length': '24',
          },
          bodyBytes: const [
            0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46,
            0x49, 0x46, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
          ],
        ),
        contains('incomplete response body'),
      );
    });
  });

  group('isReusableImagePayload', () {
    test('rejects cached HTML and incomplete JPEG files', () {
      expect(
        isReusableImagePayload(
          length: 24,
          prefix: '<html>Access denied'.codeUnits,
          tail: 'Access denied</html>'.codeUnits,
        ),
        isFalse,
      );
      expect(
        isReusableImagePayload(
          length: 40,
          prefix: const [0xff, 0xd8, 0xff, 0xe0],
          tail: const [0x11, 0x22, 0x33],
        ),
        isFalse,
      );
    });

    test('accepts a cached JPEG with its end marker intact', () {
      expect(
        isReusableImagePayload(
          length: 40,
          prefix: const [0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10],
          tail: const [0x10, 0x20, 0x30, 0xff, 0xd9],
        ),
        isTrue,
      );
    });
  });
}
