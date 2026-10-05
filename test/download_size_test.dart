import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/download_manager/download_size.dart';

void main() {
  group('trustedDownloadByteCount', () {
    test('accepts realistic sizes and an explicitly allowed zero', () {
      expect(trustedDownloadByteCount(256 * 1024 * 1024), 256 * 1024 * 1024);
      expect(trustedDownloadByteCount(0, allowZero: true), 0);
      expect(trustedDownloadBytesFromKilobytes(256), 256 * 1024);
    });

    test('rejects missing, non-positive, and implausibly large sizes', () {
      expect(trustedDownloadByteCount(null), isNull);
      expect(trustedDownloadByteCount(0), isNull);
      expect(trustedDownloadByteCount(-1, allowZero: true), isNull);
      expect(
        trustedDownloadByteCount(maxTrustedDownloadBytes + 1),
        isNull,
      );
      expect(
        trustedDownloadByteCount(15467008 * 1024 * 1024 * 1024),
        isNull,
      );
      expect(
        trustedDownloadBytesFromKilobytes(
          maxTrustedDownloadBytes ~/ 1024 + 1,
        ),
        isNull,
      );
    });

    test('accepts the configured upper bound', () {
      expect(
        trustedDownloadByteCount(maxTrustedDownloadBytes),
        maxTrustedDownloadBytes,
      );
    });
  });
}