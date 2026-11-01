import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/log/logger.dart';

void main() {
  group('sanitizeLogText', () {
    test('removes credentials and private parts of media URLs', () {
      final result = sanitizeLogText(
        'request=https://user:pass@cdn.example/video.m3u8'
        '?token=signed-secret#fragment-secret',
      );

      expect(result, contains('cdn.example'));
      expect(result, contains('[redacted-path]'));
      expect(result, contains('[REDACTED]'));
      expect(result, isNot(contains('signed-secret')));
      expect(result, isNot(contains('fragment-secret')));
      expect(result, isNot(contains('user:pass')));
      expect(result, isNot(contains('/video.m3u8')));
    });

    test('redacts authorization and cookie header values', () {
      final result = sanitizeLogText(
        'Authorization: Bearer auth-secret, Cookie: session-secret',
      );

      expect(result, contains('Authorization'));
      expect(result, contains('Cookie'));
      expect(result, isNot(contains('auth-secret')));
      expect(result, isNot(contains('session-secret')));
    });

    test('redacts local file names from filesystem errors', () {
      final result = sanitizeLogText(
        "FileSystemException: Write failed, path = "
        "'/storage/emulated/0/Watchtower/Downloads/private title.mp4' "
        '(OS Error: No space left on device)',
      );

      expect(result, contains('FileSystemException'));
      expect(result, contains('No space left on device'));
      expect(result, isNot(contains('private title.mp4')));
    });
  });

  test('AppLogger keeps the complete stack trace in recent entries', () {
    AppLogger.clearRing();
    final stack = StackTrace.fromString(
      List.generate(20, (index) => '#$index frame-$index').join('\n'),
    );

    AppLogger.log(
      'complete trace test',
      logLevel: LogLevel.warning,
      stackTrace: stack,
    );

    final entry = AppLogger.recentEntries().last;
    expect(entry, contains('#19 frame-19'));
    expect(entry, isNot(contains('more lines hidden')));
    AppLogger.clearRing();
  });

  test('AppLogger forwards complete worker error details', () {
    String? forwarded;
    AppLogger.setWorkerLogForwarder((payload) => forwarded = payload);
    final stack = StackTrace.fromString(
      List.generate(20, (index) => '#$index frame-$index').join('\n'),
    );

    AppLogger.log(
      'worker request failed',
      logLevel: LogLevel.error,
      tag: LogTag.network,
      error: StateError('request failed'),
      stackTrace: stack,
    );

    final payload = jsonDecode(forwarded!) as Map<String, dynamic>;
    expect(payload['message'], 'worker request failed');
    expect(payload['level'], LogLevel.error.index);
    expect(payload['tag'], LogTag.network);
    expect(payload['stackTrace'], contains('#19 frame-19'));
    AppLogger.setWorkerLogForwarder(null);
  });
}
