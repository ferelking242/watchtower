import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/cli/watchtower_cli_safety.dart';

void main() {
  group('CLI output redaction', () {
    test('redacts sensitive fields recursively', () {
      final safe =
          redactCliOutput({
                'headers': {
                  'Authorization': 'Bearer private-value',
                  'Accept': 'application/json',
                },
                'preferences': [
                  {
                    'key': 'apiToken',
                    'editTextPreference': {'value': 'private-token'},
                  },
                  {
                    'key': 'theme',
                    'editTextPreference': {'value': 'dark'},
                  },
                ],
              })
              as Map;

      expect(safe['headers']['Authorization'], '[REDACTED]');
      expect(safe['headers']['Accept'], 'application/json');
      expect(
        safe['preferences'][0]['editTextPreference']['value'],
        '[REDACTED]',
      );
      expect(safe['preferences'][1]['editTextPreference']['value'], 'dark');
    });

    test('redacts URL credentials and secret query parameters', () {
      final value = sanitizeCliText(
        'https://user:password@example.org/media?token=abc123&page=2'
        '&X-Amz-Signature=secret-signature',
      );

      expect(value, contains('user:[REDACTED]@'));
      expect(value, contains('token=[REDACTED]'));
      expect(value, contains('page=2'));
      expect(value, contains('X-Amz-Signature=[REDACTED]'));
      expect(value, isNot(contains('abc123')));
      expect(value, isNot(contains('secret-signature')));
    });

    test('redacts credentials embedded in error text', () {
      final value = sanitizeCliText(
        'Request failed Authorization: Bearer bearer-secret; apiToken=token-secret',
      );

      expect(value, contains('Authorization: [REDACTED]'));
      expect(value, contains('apiToken=[REDACTED]'));
      expect(value, isNot(contains('bearer-secret')));
      expect(value, isNot(contains('token-secret')));
    });
  });
}
