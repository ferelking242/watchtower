import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/isolate_service.dart';

const _version = '8.1.160';

const _help = '''
Watchtower CLI $_version

Usage:
  watchtower --cli <command> [options]

Commands:
  help                         Affiche cette aide
  version                      Affiche la version
  doctor                       Vérifie le binaire et le runtime QuickJS
  extensions list              Liste les extensions d'un dépôt local
  extensions test              Teste les extensions avec le vrai moteur Watchtower
  source <id|name> <operation> Exécute une opération sur une extension

Options générales:
  --repo, --extensions DIR     Dépôt watchtower-extensions local
  --extensions-dir DIR         Alias explicite de --repo
  --type TYPE                  manga, watch, novel, music, game ou plugin
  --include-nsfw               Alias conservé : inclut les extensions NSFW
  --exclude-nsfw               Exclut les extensions NSFW
  --all                        Teste toutes les extensions (comportement par défaut)
  --mode MODE                  load (défaut), smoke ou deep
  --concurrency N              Nombre de tests en parallèle (défaut: 4)
  --timeout SECONDS            Timeout par opération (défaut: 45)
  --report FILE                Écrit le rapport JSON à cet emplacement
  --json                       Sortie JSON uniquement
  --quiet                      Masque la progression
  --version                    Affiche la version
  --query TEXT                 Requête pour source ... search
  --url URL                    URL pour source ... detail/videos/pages
  --page N                     Numéro de page (défaut: 1)
  -h, --help                   Affiche cette aide

Modes de test:
  load                         Charge chaque extension dans QuickJS et vérifie ses préférences
  smoke                        load + popular, latest, search, détail et premier média
  deep                         smoke + page 2 et vérification HTTP du premier média

Exemples:
  watchtower --cli doctor
  watchtower --cli extensions list --repo ./watchtower-extensions
  watchtower --cli extensions test --repo ./watchtower-extensions --mode smoke --report report.json
  watchtower --cli source 1900000002 popular --repo ./watchtower-extensions
''';

class _CliOptions {
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

  static _CliOptions parse(List<String> args) {
    final result = _CliOptions();
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      String? value;
      String name = arg;
      if (arg.startsWith('--') && arg.contains('=')) {
        final split = arg.substring(2).split('=');
        name = '--${split.first}';
        value = split.skip(1).join('=');
      }
      String takeValue() => value ?? (i + 1 < args.length ? args[++i] : '');
      switch (name) {
        case '-h':
        case '--help':
          result.help = true;
        case '--repo':
        case '--extensions':
        case '--extensions-dir':
          result.repo = takeValue();
        case '--type':
          result.type = takeValue();
        case '--mode':
          result.mode = takeValue();
        case '--report':
          result.report = takeValue();
        case '--query':
          result.query = takeValue();
        case '--url':
          result.url = takeValue();
        case '--page':
          result.page = int.tryParse(takeValue()) ?? 1;
        case '--concurrency':
          result.concurrency = int.tryParse(takeValue()) ?? 4;
        case '--timeout':
          result.timeoutSeconds = int.tryParse(takeValue()) ?? 45;
        case '--include-nsfw':
          result.includeNsfw = true;
        case '--exclude-nsfw':
          result.includeNsfw = false;
        case '--all':
          result.all = true;
        case '--json':
          result.json = true;
        case '--quiet':
          result.quiet = true;
        case '--version':
        case '-V':
          result.version = true;
        default:
          if (arg.startsWith('-')) {
            throw FormatException('Unknown option: $arg');
          }
          result.positional.add(arg);
      }
    }
    result.concurrency = result.concurrency.clamp(1, 16).toInt();
    result.timeoutSeconds = result.timeoutSeconds.clamp(1, 300).toInt();
    if (!['load', 'smoke', 'deep'].contains(result.mode)) {
      throw FormatException('Unknown test mode: ${result.mode}');
    }
    return result;
  }
}

class _CatalogItem {
  final Map<String, dynamic> metadata;
  final Source source;
  final String file;

  const _CatalogItem({
    required this.metadata,
    required this.source,
    required this.file,
  });
}

class _Catalog {
  final String root;
  final List<_CatalogItem> items;
  final List<Map<String, dynamic>> failures;

  const _Catalog({
    required this.root,
    required this.items,
    required this.failures,
  });
}

class _Step {
  final bool ok;
  final int ms;
  final int? count;
  final String? error;
  final Map<String, dynamic>? extra;

  const _Step({
    required this.ok,
    required this.ms,
    this.count,
    this.error,
    this.extra,
  });

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'ms': ms,
        if (count != null) 'count': count,
        if (error != null) 'error': error,
        if (extra != null) ...extra!,
      };
}

class _TestResult {
  final _CatalogItem item;
  final Map<String, _Step> steps = {};
  bool ok = true;
  int totalMs = 0;

  _TestResult(this.item);

  Map<String, dynamic> toJson() => {
        'id': item.source.id,
        'name': item.source.name,
        'lang': item.source.lang,
        'itemType': item.source.itemType.name,
        'file': item.file,
        'ok': ok,
        'ms': totalMs,
        'steps': steps.map((key, value) => MapEntry(key, value.toJson())),
      };
}

Future<int> runWatchtowerCli(List<String> args) async {
  try {
    final options = _CliOptions.parse(args);
    if (options.version) {
      print('Watchtower $_version');
      return 0;
    }
    if (options.help || options.positional.isEmpty) {
      stdout.write(_help);
      return 0;
    }
    final command = options.positional.first;
    if (command == 'version') {
      print('Watchtower $_version');
      return 0;
    }
    if (command == 'help') {
      stdout.write(_help);
      return 0;
    }
    if (command == 'doctor') return _doctor(options);
    if (command == 'extensions') {
      final subcommand =
          options.positional.length > 1 ? options.positional[1] : 'list';
      final catalog = await _loadCatalog(options);
      if (subcommand == 'list') return _listExtensions(catalog, options);
      if (subcommand == 'test') return _testExtensions(catalog, options);
      throw FormatException('Unknown extensions command: $subcommand');
    }
    if (command == 'source') {
      final catalog = await _loadCatalog(options);
      return _runSource(catalog, options);
    }
    throw FormatException('Unknown command: $command');
  } catch (error, stack) {
    stderr.writeln('watchtower: $error');
    if (Platform.environment['WATCHTOWER_DEBUG'] == '1') stderr.writeln(stack);
    return 2;
  }
}

Future<int> _doctor(_CliOptions options) async {
  final result = {
    'version': _version,
    'platform': Platform.operatingSystem,
    'architecture': Platform.operatingSystemVersion,
    'dart': Platform.version,
    'native': true,
    'quickJs': true,
  };
  _printJsonOrLines(result, options);
  return 0;
}

Future<_Catalog> _loadCatalog(_CliOptions options) async {
  final root = options.repo ??
      Platform.environment['WATCHTOWER_EXTENSIONS_DIR'] ??
      '../watchtower-extensions';
  final indexDir = Directory('$root/index');
  if (!await indexDir.exists()) {
    throw ArgumentError(
      'Extension repository not found at $root. Use --repo /path/to/watchtower-extensions.',
    );
  }

  final items = <_CatalogItem>[];
  final failures = <Map<String, dynamic>>[];
  await for (final entity in indexDir.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    if (entity.uri.pathSegments.last == 'plugins.json') continue;
    try {
      final raw = jsonDecode(await entity.readAsString());
      if (raw is! List) continue;
      for (final value in raw.whereType<Map>()) {
        final metadata = Map<String, dynamic>.from(value);
        // Plugin catalogue entries (for example .smplug music packages) are
        // handled by the plugin subsystem, not by JsExtensionService. They
        // have no sourceCodeUrl and must not be treated as a JS source.
        final sourceCodeUrl = metadata['sourceCodeUrl']?.toString() ?? '';
        if (sourceCodeUrl.isEmpty) continue;
        final itemType = metadata['itemType'];
        // The subtitles catalogue is consumed by the subtitle provider, not
        // by ExtensionService. It has no corresponding Source enum value.
        if (itemType is! int || itemType < 0 || itemType >= ItemType.values.length) {
          continue;
        }
        final isNsfw = metadata['isNsfw'] == true ||
            (metadata['sourceCodeUrl']?.toString().contains('/nsfw/') ?? false);
        if (isNsfw && !options.includeNsfw) continue;
        final sourcePath = _sourcePath(root, metadata);
        final codeFile = File(sourcePath);
        if (!await codeFile.exists()) {
          failures.add({
            'name': metadata['name'],
            'id': metadata['id'],
            'file': sourcePath,
            'error': 'source code file not found',
          });
          continue;
        }
        final source = Source.fromJson({
          ...metadata,
          'sourceCode': await codeFile.readAsString(),
          'sourceCodeLanguage': 1,
          'isAdded': true,
          'isActive': true,
          'isLocal': true,
        });
        if (options.type != null && !_matchesType(source, options.type!)) {
          continue;
        }
        items.add(_CatalogItem(
          metadata: metadata,
          source: source,
          file: sourcePath,
        ));
      }
    } catch (error) {
      failures.add({'file': entity.path, 'error': error.toString()});
    }
  }
  items.sort((a, b) => (a.source.name ?? '').compareTo(b.source.name ?? ''));
  return _Catalog(root: root, items: items, failures: failures);
}

String _sourcePath(String root, Map<String, dynamic> metadata) {
  final raw = metadata['sourceCodeUrl']?.toString() ?? '';
  final parsed = Uri.tryParse(raw);
  final path = parsed?.path ?? raw;
  final marker = path.indexOf('/src/');
  if (marker >= 0) return '$root/${path.substring(marker + 1)}';
  final pkgPath = metadata['pkgPath']?.toString() ?? '';
  if (pkgPath.startsWith('src/')) return '$root$pkgPath';
  return '$root/$pkgPath';
}

String _sourceType(Source source) {
  return switch (source.itemType) {
    ItemType.manga => 'manga',
    ItemType.anime => 'watch',
    ItemType.novel => 'novel',
    ItemType.music => 'music',
    ItemType.game => 'game',
    ItemType.plugin => 'plugin',
  };
}

bool _matchesType(Source source, String requested) {
  final value = requested.toLowerCase();
  final type = _sourceType(source);
  if (type == value) return true;
  if (type == 'watch' && value == 'anime') return true;
  if (type == 'anime' && value == 'watch') return true;
  return false;
}

int _listExtensions(_Catalog catalog, _CliOptions options) {
  if (options.json) {
    _printJsonOrLines({
      'root': catalog.root,
      'total': catalog.items.length,
      'failures': catalog.failures,
      'sources': catalog.items.map(_sourceJson).toList(),
    }, options);
    return catalog.failures.isEmpty ? 0 : 1;
  }
  for (final item in catalog.items) {
    print('${item.source.id}\t${_sourceType(item.source)}\t'
        '${item.source.lang}\t${item.source.name}\t${item.file}');
  }
  stderr.writeln(
      '${catalog.items.length} extension(s), ${catalog.failures.length} file failure(s)');
  return catalog.failures.isEmpty ? 0 : 1;
}

Future<int> _testExtensions(_Catalog catalog, _CliOptions options) async {
  await getIsolateService.start();
  try {
    final results = <_TestResult>[];
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= catalog.items.length) return;
        final item = catalog.items[index];
        final result = await _testOne(item, options);
        results.add(result);
        if (!options.quiet && !options.json) {
          stdout.writeln(
              '${result.ok ? 'PASS' : 'FAIL'} ${index + 1}/${catalog.items.length} '
              '${item.source.name} [${item.source.lang}]');
        }
      }
    }

    await Future.wait(
      List.generate(options.concurrency, (_) => worker()),
    );
    results.sort((a, b) => (a.item.source.name ?? '')
        .compareTo(b.item.source.name ?? ''));
    final passed = results.where((result) => result.ok).length;
    final report = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'version': _version,
      'mode': options.mode,
      'repository': catalog.root,
      'total': results.length,
      'passed': passed,
      'failed': results.length - passed,
      'catalogFailures': catalog.failures,
      'results': results.map((result) => result.toJson()).toList(),
    };
    if (options.report != null) {
      await File(options.report!).writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
    }
    if (options.json) {
      _printJsonOrLines(report, options);
    } else {
      print('Done: $passed passed, ${results.length - passed} failed '
          '(${results.length} tested)');
      if (options.report != null) print('Report: ${options.report}');
    }
    return passed == results.length && catalog.failures.isEmpty ? 0 : 1;
  } finally {
    await getIsolateService.stop();
    ExtensionServiceRegistry.disposeAll();
  }
}

Future<_TestResult> _testOne(
  _CatalogItem item,
  _CliOptions options,
) async {
  final result = _TestResult(item);
  final started = Stopwatch()..start();
  Future<void> step(
    String name,
    Future<Object?> Function(ExtensionService service) action,
  ) async {
    final watch = Stopwatch()..start();
    try {
      final value = await withExtensionService(
        item.source,
        '',
        (service) => action(service).timeout(
          Duration(seconds: options.timeoutSeconds),
        ),
      );
      result.steps[name] = _Step(
        ok: true,
        ms: watch.elapsedMilliseconds,
        count: _count(value),
      );
    } catch (error) {
      result.ok = false;
      result.steps[name] = _Step(
        ok: false,
        ms: watch.elapsedMilliseconds,
        error: _shortError(error),
      );
    }
  }

  await step('load', (service) async {
    service.getSourcePreferences();
    service.getHeaders();
    return true;
  });
  if (options.mode == 'load' || !result.ok) {
    started.stop();
    result.totalMs = started.elapsedMilliseconds;
    return result;
  }

  MPages? popular;
  await step('popular', (service) async {
    popular = await service.getPopular(1);
    return popular!;
  });
  await step('latest', (service) => service.getLatestUpdates(1));
  await step('search', (service) => service.search('a', 1, const []));
  if (options.mode == 'deep') {
    await step('popularPage2', (service) => service.getPopular(2));
  }

  final probe = popular?.list
      ?.map((item) => item.link)
      .whereType<String>()
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (probe == null || probe.isEmpty) {
    result.ok = false;
    result.steps['detail'] = const _Step(
      ok: false,
      ms: 0,
      error: 'popular returned no usable item URL',
    );
  } else {
    MManga? detail;
    await step('detail', (service) async {
      detail = await service.getDetail(probe!);
      return detail!;
    });
    final mediaUrl = detail?.chapters
        ?.map((chapter) => chapter.url)
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (mediaUrl == null || mediaUrl.isEmpty) {
      result.ok = false;
      result.steps['media'] = const _Step(
        ok: false,
        ms: 0,
        error: 'detail returned no usable chapter or episode URL',
      );
    } else if (item.source.itemType == ItemType.manga) {
      List<PageUrl>? pages;
      await step('pages', (service) async {
        pages = await service.getPageList(mediaUrl!);
        return pages!;
      });
      if (options.mode == 'deep' && pages != null && pages!.isNotEmpty) {
        await step('httpProbe', (_) => _probeHttp(pages!.first.url));
      }
    } else {
      List<Video>? videos;
      await step('videos', (service) async {
        videos = await service.getVideoList(mediaUrl!);
        return videos!;
      });
      if (options.mode == 'deep' && videos != null && videos!.isNotEmpty) {
        await step('httpProbe', (_) => _probeHttp(videos!.first.url));
      }
    }
  }
  started.stop();
  result.totalMs = started.elapsedMilliseconds;
  return result;
}

Future<int> _runSource(_Catalog catalog, _CliOptions options) async {
  if (options.positional.length < 3) {
    throw ArgumentError(
        'Usage: source <id|name> <popular|latest|search|detail|videos|pages>');
  }
  final needle = options.positional[1].toLowerCase();
  final operation = options.positional[2];
  final item = catalog.items.firstWhere(
    (candidate) =>
        candidate.source.name?.toLowerCase() == needle ||
        candidate.source.id.toString() == needle,
    orElse: () => throw ArgumentError('Extension not found: $needle'),
  );
  await getIsolateService.start();
  try {
    final value = await withExtensionService(item.source, '', (service) async {
      switch (operation) {
        case 'popular':
          return service.getPopular(options.page);
        case 'latest':
          return service.getLatestUpdates(options.page);
        case 'search':
          return service.search(options.query ?? '', options.page, const []);
        case 'detail':
          return service.getDetail(options.url ?? '');
        case 'videos':
          return service.getVideoList(options.url ?? '');
        case 'pages':
          return service.getPageList(options.url ?? '');
        default:
          throw ArgumentError('Unknown source operation: $operation');
      }
    }).timeout(Duration(seconds: options.timeoutSeconds));
    _printJsonOrLines(_serialize(value), options);
    return 0;
  } finally {
    await getIsolateService.stop();
    ExtensionServiceRegistry.disposeAll();
  }
}

Map<String, dynamic> _sourceJson(_CatalogItem item) => {
      ...item.metadata,
      'file': item.file,
      'type': _sourceType(item.source),
    };

dynamic _serialize(Object? value) {
  if (value is MPages) {
    return {
      'list': value.list?.map(_serialize).toList() ?? [],
      'hasNextPage': value.hasNextPage,
    };
  }
  if (value is MManga) {
    return {
      'name': value.name,
      'imageUrl': value.imageUrl,
      'link': value.link,
      'author': value.author,
      'description': value.description,
      'chapters': value.chapters?.map(_serialize).toList() ?? [],
    };
  }
  if (value is Video) return value.toJson();
  if (value is PageUrl) return value.toJson();
  if (value is Iterable) return value.map(_serialize).toList();
  if (value is Map) return value.map((key, val) => MapEntry('$key', _serialize(val)));
  return value;
}

int? _count(Object? value) {
  if (value is MPages) return value.list?.length ?? 0;
  if (value is Iterable) return value.length;
  if (value is MManga) return value.chapters?.length ?? 0;
  return null;
}

String _shortError(Object error) {
  final value = error.toString().replaceAll('\n', ' ');
  return value.length > 500 ? '${value.substring(0, 497)}...' : value;
}

Future<int> _probeHttp(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(
          const Duration(seconds: 20),
        );
    request.followRedirects = true;
    final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode} for $url',
        uri: Uri.tryParse(url),
      );
    }
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

void _printJsonOrLines(Object value, _CliOptions options) {
  if (options.json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
  } else if (value is Map) {
    for (final entry in value.entries) stdout.writeln('${entry.key}: ${entry.value}');
  } else {
    stdout.writeln(value);
  }
}