import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/cli/watchtower_cli_options.dart';

void main() {
  group('WatchtowerCliOptions.parse', () {
    test('keeps commands positional and accepts inline values', () {
      final options = WatchtowerCliOptions.parse([
        'extensions',
        'test',
        '--repo=./catalog',
        '--mode=deep',
        '--page=3',
      ]);

      expect(options.positional, ['extensions', 'test']);
      expect(options.repo, './catalog');
      expect(options.mode, 'deep');
      expect(options.page, 3);
    });

    test('accepts aliases, separate values, and options after commands', () {
      final options = WatchtowerCliOptions.parse([
        'source',
        'source-id',
        'search',
        '--extensions-dir',
        './catalog with spaces',
        '--type',
        'anime',
        '--query',
        'space opera',
        '--page',
        '2',
      ]);

      expect(options.repo, './catalog with spaces');
      expect(options.type, 'anime');
      expect(options.query, 'space opera');
      expect(options.page, 2);
      expect(options.positional, ['source', 'source-id', 'search']);
    });

    test('supports an explicit end-of-options marker', () {
      final options = WatchtowerCliOptions.parse(['source', '--', '-source']);
      expect(options.positional, ['source', '-source']);
    });

    test('retains defaults and boolean aliases', () {
      final options = WatchtowerCliOptions.parse([]);
      expect(options.mode, 'load');
      expect(options.page, 1);
      expect(options.concurrency, 4);
      expect(options.timeoutSeconds, 45);
      expect(options.includeNsfw, isTrue);

      final excluded = WatchtowerCliOptions.parse(['--exclude-nsfw', '--json']);
      expect(excluded.includeNsfw, isFalse);
      expect(excluded.json, isTrue);
    });

    test('rejects unknown options and missing or empty option values', () {
      expect(
        () => WatchtowerCliOptions.parse(['--wat']),
        throwsFormatException,
      );
      expect(
        () => WatchtowerCliOptions.parse(['--repo']),
        throwsFormatException,
      );
      expect(
        () => WatchtowerCliOptions.parse(['--repo=']),
        throwsFormatException,
      );
      expect(
        () => WatchtowerCliOptions.parse(['--mode', '--json']),
        throwsFormatException,
      );
    });

    test('rejects unsupported types and modes instead of hiding the mistake', () {
      expect(
        () => WatchtowerCliOptions.parse(['--type', 'comic']),
        throwsFormatException,
      );
      expect(
        () => WatchtowerCliOptions.parse(['--mode', 'quick']),
        throwsFormatException,
      );
    });

    test('rejects out-of-range numeric options instead of clamping them', () {
      for (final args in [
        ['--page', '0'],
        ['--page', 'not-a-number'],
        ['--concurrency', '17'],
        ['--timeout', '301'],
      ]) {
        expect(
          () => WatchtowerCliOptions.parse(args),
          throwsFormatException,
          reason: args.join(' '),
        );
      }
    });

    test('rejects values supplied to flag-only options', () {
      expect(
        () => WatchtowerCliOptions.parse(['--json=true']),
        throwsFormatException,
      );
      expect(
        () => WatchtowerCliOptions.parse(['--help=true']),
        throwsFormatException,
      );
    });
  });
}
