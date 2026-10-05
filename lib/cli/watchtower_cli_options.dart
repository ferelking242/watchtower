class WatchtowerCliOptions {
  final List<String> positional = [];
  String? repo;
  String? type;
  String mode = 'load';
  String? report;
  String? query;
  String? url;
  int page = 1;
  int concurrency = 4;
  int timeoutSeconds = 45;
  bool includeNsfw = true;
  bool all = false;
  bool json = false;
  bool quiet = false;
  bool help = false;
  bool version = false;

  static const supportedTypes = {
    'manga',
    'watch',
    'anime',
    'novel',
    'music',
    'game',
    'plugin',
  };
  static const supportedModes = {'load', 'smoke', 'deep'};

  static WatchtowerCliOptions parse(List<String> args) {
    final result = WatchtowerCliOptions();

    String valueFor(List<String> args, int index, String? inlineValue) {
      if (inlineValue != null) {
        if (inlineValue.isEmpty) {
          throw FormatException('Missing value for ${args[index]}');
        }
        return inlineValue;
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        throw FormatException('Missing value for ${args[index]}');
      }
      return args[index + 1];
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--') {
        result.positional.addAll(args.skip(i + 1));
        break;
      }

      final separator = arg.startsWith('--') ? arg.indexOf('=') : -1;
      final name = separator < 0 ? arg : arg.substring(0, separator);
      final inlineValue =
          separator < 0 ? null : arg.substring(separator + 1);

      void setString(void Function(String value) assign) {
        assign(valueFor(args, i, inlineValue));
        if (inlineValue == null) i++;
      }

      void setInteger(
        String option,
        void Function(int value) assign, {
        required int minimum,
        required int maximum,
      }) {
        final raw = valueFor(args, i, inlineValue);
        final value = int.tryParse(raw);
        if (value == null || value < minimum || value > maximum) {
          throw FormatException(
            '$option must be an integer between $minimum and $maximum.',
          );
        }
        assign(value);
        if (inlineValue == null) i++;
      }

      switch (name) {
        case '-h':
        case '--help':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.help = true;
        case '--repo':
        case '--extensions':
        case '--extensions-dir':
          setString((value) => result.repo = value);
        case '--type':
          setString((value) {
            final normalized = value.toLowerCase();
            if (!supportedTypes.contains(normalized)) {
              throw FormatException(
                'Unknown type "$value". Supported types: '
                '${supportedTypes.join(', ')}.',
              );
            }
            result.type = normalized;
          });
        case '--mode':
          setString((value) {
            if (!supportedModes.contains(value)) {
              throw FormatException(
                'Unknown test mode "$value". Supported modes: '
                '${supportedModes.join(', ')}.',
              );
            }
            result.mode = value;
          });
        case '--report':
          setString((value) => result.report = value);
        case '--query':
          setString((value) => result.query = value);
        case '--url':
          setString((value) => result.url = value);
        case '--page':
          setInteger(
            '--page',
            (value) => result.page = value,
            minimum: 1,
            maximum: 1000000,
          );
        case '--concurrency':
          setInteger(
            '--concurrency',
            (value) => result.concurrency = value,
            minimum: 1,
            maximum: 16,
          );
        case '--timeout':
          setInteger(
            '--timeout',
            (value) => result.timeoutSeconds = value,
            minimum: 1,
            maximum: 300,
          );
        case '--include-nsfw':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.includeNsfw = true;
        case '--exclude-nsfw':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.includeNsfw = false;
        case '--all':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.all = true;
        case '--json':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.json = true;
        case '--quiet':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.quiet = true;
        case '--version':
        case '-V':
          if (inlineValue != null) {
            throw FormatException('$name does not take a value.');
          }
          result.version = true;
        default:
          if (name.startsWith('-')) {
            throw FormatException('Unknown option: $name');
          }
          if (inlineValue != null) {
            throw FormatException('Unexpected value for positional argument: $arg');
          }
          result.positional.add(arg);
      }
    }
    return result;
  }
}
