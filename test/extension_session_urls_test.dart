import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/http/extension_session_urls.dart';

void main() {
  group('extensionSessionUrls', () {
    test('includes both the source and separate login hosts', () {
      expect(
        extensionSessionUrls(
          baseUrl: 'https://reader.example/',
          loginUrl: 'https://accounts.example.net/login?next=%2F',
        ),
        ['https://reader.example/', 'https://accounts.example.net/login'],
      );
    });

    test('keeps distinct paths on the same host for path-scoped cookies', () {
      expect(
        extensionSessionUrls(
          baseUrl: 'https://reader.example/',
          loginUrl: 'https://reader.example/auth/login?next=%2F',
        ),
        ['https://reader.example/', 'https://reader.example/auth/login'],
      );
    });

    test('drops invalid and non-web URLs and removes query state', () {
      expect(
        extensionSessionUrls(
          baseUrl: 'javascript:alert(1)',
          loginUrl: 'https://reader.example/login?token=one-time#finish',
        ),
        ['https://reader.example/login'],
      );
    });
  });
}
