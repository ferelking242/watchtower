import 'package:watchtower/cli/output/cli_output.dart';

/// Parsed representation of the raw `--cli` argument vector.
class CliInvocation {
  CliInvocation({
    required this.rawArgs,
    required this.positional,
    required this.options,
    required this.flags,
    required this.format,
    required this.quiet,
    required this.help,
    required this.interactive,
    this.multiOptions = const {},
  });

  final List<String> rawArgs;
  final List<String> positional;
  final Map<String, String> options;
  final Set<String> flags;

  /// Every value seen for a repeated option, in order. `options` keeps the
  /// last value for single-valued options; list filters read this map so
  /// `--lang fr --lang en` and `--lang fr,en` both select both languages.
  final Map<String, List<String>> multiOptions;
  final CliOutputFormat format;
  final bool quiet;
  final bool help;
  final bool interactive;

  String? get command => positional.isEmpty ? null : positional.first;
  String? get subcommand => positional.length > 1 ? positional[1] : null;

  /// Positional arguments after `<command> <subcommand>`.
  List<String> get arguments =>
      positional.length > 2 ? positional.sublist(2) : const [];

  bool hasFlag(String name) => flags.contains(name);
  String? option(String name) => options[name];

  String? string(String name) => options[name];

  int intOption(String name, {int? fallback}) {
    final value = options[name];
    if (value == null) return fallback ?? 0;
    return int.tryParse(value) ?? fallback ?? 0;
  }

  bool boolOption(String name, {bool fallback = false}) {
    if (flags.contains(name)) return true;
    final value = options[name];
    if (value == null) return fallback;
    final normalized = value.toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  /// Collects a comma-separated value that may be repeated across aliases.
  ///
  /// `--lang fr --lang en` and `--lang fr,en` both yield `{fr, en}`, so a
  /// caller can filter on several languages at once.
  Set<String> listOption(Iterable<String> names) {
    final values = <String>{};
    for (final name in names) {
      final raws =
          multiOptions[name] ?? [if (options[name] != null) options[name]!];
      for (final raw in raws) {
        for (final part in raw.split(',')) {
          final value = part.trim().toLowerCase();
          if (value.isNotEmpty) values.add(value);
        }
      }
    }
    return values;
  }

  /// A single option resolved from several aliases (first match wins).
  String? firstOption(Iterable<String> names) {
    for (final name in names) {
      final value = options[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

const _globalFlags = {
  'json',
  'ndjson',
  'quiet',
  'help',
  'interactive',
  'no-color',
  'verbose',
};

/// Parses `args` (the tokens after `--cli`). Global flags may appear anywhere.
CliInvocation parseCliInvocation(List<String> args) {
  final positional = <String>[];
  final options = <String, String>{};
  final multiOptions = <String, List<String>>{};
  final flags = <String>{};

  void recordOption(String name, String value) {
    options[name] = value;
    (multiOptions[name] ??= []).add(value);
  }

  var format = CliOutputFormat.human;
  var quiet = false;
  var help = false;
  var interactive = false;

  var index = 0;
  while (index < args.length) {
    final token = args[index];
    if (token == '--') {
      positional.addAll(args.sublist(index + 1));
      break;
    }
    if (token.startsWith('--')) {
      var name = token.substring(2);
      String? value;
      final eq = name.indexOf('=');
      if (eq != -1) {
        value = name.substring(eq + 1);
        name = name.substring(0, eq);
      }

      if (name == 'json') {
        format = CliOutputFormat.json;
      } else if (name == 'ndjson') {
        format = CliOutputFormat.ndjson;
      } else if (name == 'quiet') {
        quiet = true;
      } else if (name == 'help') {
        help = true;
      } else if (name == 'interactive') {
        interactive = true;
      } else if (_globalFlags.contains(name)) {
        flags.add(name);
      } else {
        if (value != null) {
          recordOption(name, value);
        } else if (index + 1 < args.length &&
            !args[index + 1].startsWith('--')) {
          recordOption(name, args[++index]);
        } else {
          flags.add(name);
        }
      }
    } else if (token.startsWith('-') && token.length > 1 && token != '-') {
      // Short flags: -h, -q, -j.
      for (final ch in token.substring(1).split('')) {
        switch (ch) {
          case 'h':
            help = true;
            break;
          case 'q':
            quiet = true;
            break;
          case 'j':
            format = CliOutputFormat.json;
            break;
          default:
            flags.add(ch);
        }
      }
    } else {
      positional.add(token);
    }
    index++;
  }

  return CliInvocation(
    rawArgs: args,
    positional: positional,
    options: options,
    flags: flags,
    format: format,
    quiet: quiet,
    help: help,
    interactive: interactive,
    multiOptions: multiOptions,
  );
}
