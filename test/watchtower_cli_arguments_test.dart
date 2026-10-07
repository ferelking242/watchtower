import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/commands/plugins_command.dart';
import 'package:watchtower/cli/output/cli_output.dart';
import 'package:watchtower/cli/runtime/cli_arguments.dart';
import 'package:watchtower/cli/watchtower_cli_safety.dart';

void main() {
  group('parseCliInvocation', () {
    test('keeps commands positional and accepts inline values', () {
      final invocation = parseCliInvocation([
        'extensions',
        'install',
        '--repo=./catalog',
        '--type=anime',
        '--page=3',
      ]);

      expect(invocation.command, 'extensions');
      expect(invocation.subcommand, 'install');
      expect(invocation.option('repo'), './catalog');
      expect(invocation.option('type'), 'anime');
      expect(invocation.intOption('page'), 3);
    });

    test('accepts separate values, short flags and options after commands', () {
      final invocation = parseCliInvocation([
        'sources',
        '12',
        'search',
        '--query',
        'space opera',
        '--data-dir',
        './data dir',
        '-j',
        '-q',
      ]);

      expect(invocation.positional, ['sources', '12', 'search']);
      expect(invocation.option('query'), 'space opera');
      expect(invocation.option('data-dir'), './data dir');
      expect(invocation.format, CliOutputFormat.json);
      expect(invocation.quiet, isTrue);
    });

    test('supports an explicit end-of-options marker', () {
      final invocation = parseCliInvocation(['library', '--', '-weird-name']);
      expect(invocation.positional, ['library', '-weird-name']);
      expect(invocation.option('-weird-name'), isNull);
    });

    test('parses boolean options from flags and explicit values', () {
      final flags = parseCliInvocation(['downloads', 'process', '--wifi']);
      expect(flags.boolOption('wifi'), isTrue);

      final explicit = parseCliInvocation([
        'downloads',
        'process',
        '--wifi=false',
      ]);
      expect(explicit.boolOption('wifi', fallback: true), isFalse);

      final fallback = parseCliInvocation(['downloads', 'process']);
      expect(fallback.boolOption('wifi', fallback: true), isTrue);
    });

    test('defaults to human output with help disabled', () {
      final invocation = parseCliInvocation([]);
      expect(invocation.command, isNull);
      expect(invocation.format, CliOutputFormat.human);
      expect(invocation.help, isFalse);
      expect(invocation.quiet, isFalse);
    });

    test('recognises --help and -h', () {
      expect(parseCliInvocation(['--help']).help, isTrue);
      expect(parseCliInvocation(['extensions', '-h']).help, isTrue);
    });

    test('intOption returns the fallback for non-numeric values', () {
      final invocation = parseCliInvocation(['downloads', 'watch', '--page=x']);
      expect(invocation.intOption('page', fallback: 5), 5);
    });
  });

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

  group('loadPluginCatalog', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('wt-plugins'));
    tearDown(() => root.deleteSync(recursive: true));

    void writeIndex(String contents) {
      final index = Directory('${root.path}/index')..createSync();
      File('${index.path}/plugins.json').writeAsStringSync(contents);
    }

    test('accepts a well-formed catalog and exposes the plugin list', () {
      writeIndex(
        '{"lastUpdated":"2024-01-01","plugins":'
        '[{"id":"manga-meta"},{"id":"anime-meta"}]}',
      );

      final catalog = loadPluginCatalog(root.path);
      expect(catalog.plugins, hasLength(2));
      expect(catalog.failures, isEmpty);
      expect(catalog.summary()['valid'], isTrue);
      expect(catalog.lastUpdated, '2024-01-01');
    });

    test('reports missing ids, duplicates and non-object entries', () {
      writeIndex('{"plugins":[{"id":"dup"},{"id":"dup"},{"name":"no-id"},42]}');

      final catalog = loadPluginCatalog(root.path);
      expect(catalog.plugins, hasLength(1));
      expect(catalog.failures, hasLength(3));
      expect(catalog.summary()['valid'], isFalse);
    });

    test('rejects an index that is not an object with a plugins array', () {
      writeIndex('[]');
      expect(
        () => loadPluginCatalog(root.path),
        throwsA(isA<CliUsageException>()),
      );
    });

    test('rejects a missing index file', () {
      expect(
        () => loadPluginCatalog(root.path),
        throwsA(isA<CliUsageException>()),
      );
    });
  });
}
