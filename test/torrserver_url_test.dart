import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/torrent_server.dart';

void main() {
  group('normaliseTorrServerUrl', () {
    test('returns null for blank input so the bundled server is used', () {
      expect(normaliseTorrServerUrl(null), isNull);
      expect(normaliseTorrServerUrl(''), isNull);
      expect(normaliseTorrServerUrl('   '), isNull);
    });

    test('adds the default scheme and port to a bare host', () {
      expect(normaliseTorrServerUrl('127.0.0.1'), 'http://127.0.0.1:8090');
      expect(normaliseTorrServerUrl('192.168.1.10'), 'http://192.168.1.10:8090');
    });

    test('keeps an explicit port', () {
      expect(normaliseTorrServerUrl('127.0.0.1:9000'), 'http://127.0.0.1:9000');
      expect(
        normaliseTorrServerUrl('http://192.168.1.10:8090'),
        'http://192.168.1.10:8090',
      );
    });

    test('preserves an explicit https scheme', () {
      expect(
        normaliseTorrServerUrl('https://torr.example.com'),
        'https://torr.example.com:8090',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        normaliseTorrServerUrl('  127.0.0.1:8090  '),
        'http://127.0.0.1:8090',
      );
    });
  });
}
