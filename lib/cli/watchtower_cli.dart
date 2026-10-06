import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:path/path.dart' as p;
import 'watchtower_cli_catalog.dart';
import 'watchtower_cli_plugins.dart';
import 'watchtower_cli_options.dart';
import 'watchtower_cli_safety.dart';

const _version = '8.1.160';

const _help =
    '''
Watchtower CLI $_version

Usage:
  watchtower --cli <command> [options]

Commands:
  help                         Affiche cette aide
  version                      Affiche la version
  doctor                       Vérifie la plateforme, QuickJS et les isolates
  extensions list              Liste les extensions d'un dépôt local
  extensions test              Teste les extensions avec le vrai moteur Watchtower
  plugins list                 Liste les plugins du catalogue local
  plugins show <id>            Affiche les métadonnées d'un plugin
  plugins validate [id]        Valide le catalogue des plugins
  source <id|name> <operation> Exécute une opération réelle sur une extension

Opérations source:
  popular, latest, search, detail, videos, pages, filters, preferences,
  headers, suggestions, custom-list, recommendations, comments, html,
  clean-html, supports-latest, inspect

Options générales:
  --repo, --extensions DIR     Dépôt watchtower-extensions local
  --extensions-dir DIR         Alias explicite de --repo
  --type TYPE                  manga, watch, novel, music, game ou plugin
  --lang, --language LANG      Filtre par langue (ex. fr)
  --include-unindexed          Inclut les fichiers source absents de l'index
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
  --query TEXT                 Requête pour search ou suggestions
  --filters-json JSON          Filtres sérialisés à passer à search
  --url URL                    URL pour detail/videos/pages/comments/etc.
  --name TEXT                  Nom du contenu pour source ... html
  --input-file FILE            HTML à nettoyer avec source ... clean-html
  --text TEXT                  Texte HTML direct pour source ... clean-html
  --page N                     Numéro de page (défaut: 1)
  -h, --help                   Affiche cette aide

Modes de test:
  load                         Charge chaque source avec son moteur déclaré et lit ses métadonnées
  smoke                        load + filtres, popular, latest, suggestions, recherche, détail et média
  deep                         smoke + page 2 et vérification HTTP du premier média

Exemples:
  watchtower --cli doctor
  watchtower --cli extensions list --repo ./watchtower-extensions
  watchtower --cli extensions test --repo ./watchtower-extensions --mode smoke --report report.json
  watchtower --cli plugins validate --repo ./watchtower-extensions --json
  watchtower --cli source 1900000002 search --query "space opera" --filters-json '[]'
''';

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
  final String? revision;
  final List<_CatalogItem> items;
  final List<Map<String, dynamic>> failures;

  const _Catalog({
    required this.root,
    required this.revision,
    required this.items,
    required this.failures,
  });
}

class _Step {
  final bool ok;
  final int ms;
  final int? count;
  final String? error;
  final String? errorType;
  final Map<String, dynamic>? extra;

  const _Step({
    required this.ok,
    required this.ms,
    this.count,
    this.error,
    this.errorType,
    this.extra,
  });

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'status': ok ? 'passed' : 'failed',
    'ms': ms,
    'count': ?count,
    'error': ?error,
    'errorType': ?errorType,
    ...?extra,
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
    'engine': item.source.sourceCodeLanguage.name,
    'file': item.file,
    'ok': ok,
    'ms': totalMs,
    'steps': steps.map((key, value) => MapEntry(key, value.toJson())),
  };
}

Future<int> runWatchtowerCli(List<String> args) async {
  try {
    final options = WatchtowerCliOptions.parse(args);
    if (options.version) {
      stdout.writeln('Watchtower $_version');
      return 0;
    }
    if (options.help || options.positional.isEmpty) {
      stdout.write(_help);
      return 0;
    }
    final command = options.positional.first;
    if (command == 'version') {
      stdout.writeln('Watchtower $_version');
      return 0;
    }
    if (command == 'help') {
      stdout.write(_help);
      return 0;
    }
    if (command == 'doctor') return await _doctor(options);
    if (command == 'plugins') return await _runPlugins(options);
    if (command == 'extensions') {
      final subcommand = options.positional.length > 1
          ? options.positional[1]
          : 'list';
      final catalog = await _loadCatalog(options);
      if (subcommand == 'list') return _listExtensions(catalog, options);
      if (subcommand == 'test') return await _testExtensions(catalog, options);
      throw FormatException('Unknown extensions command: $subcommand');
    }
    if (command == 'source') {
      final catalog = await _loadCatalog(options);
      return await _runSource(catalog, options);
    }
    throw FormatException('Unknown command: $command');
  } catch (error, stack) {
    stderr.writeln('watchtower: ${sanitizeCliText(error.toString())}');
    if (Platform.environment['WATCHTOWER_DEBUG'] == '1') {
      stderr.writeln(sanitizeCliText(stack.toString()));
    }
    return 2;
  }
}

Future<int> _doctor(WatchtowerCliOptions options) async {
  var isolatePoolAvailable = false;
  var quickJsAvailable = false;
  String? runtimeError;
  try {
    await getIsolateService.start();
    isolatePoolAvailable = true;
    final probe = Source(
      id: -1,
      name: 'Watchtower runtime probe',
      sourceCode: 'class DefaultExtension {}',
    )..sourceCodeLanguage = SourceCodeLanguage.javascript;
    await withExtensionService<bool>(
      probe,
      (service) async => service.supportsLatest,
    ).timeout(Duration(seconds: options.timeoutSeconds));
    quickJsAvailable = true;
  } catch (error) {
    runtimeError = _shortError(error);
  } finally {
    ExtensionServiceRegistry.disposeAll();
    if (isolatePoolAvailable) {
      try {
        await getIsolateService.stop();
      } catch (_) {}
    }
  }
  final result = {
    'version': _version,
    'platform': Platform.operatingSystem,
    'architecture': Abi.current().toString(),
    'dart': Platform.version,
    'native': true,
    'isolatePool': {'available': isolatePoolAvailable},
    'quickJs': {'available': quickJsAvailable, 'error': ?runtimeError},
  };
  _printJsonOrLines(result, options);
  return isolatePoolAvailable && quickJsAvailable ? 0 : 1;
}

Future<int> _runPlugins(WatchtowerCliOptions options) async {
  final subcommand = options.positional.length > 1
      ? options.positional[1]
      : 'list';
  if (!const {'list', 'show', 'validate'}.contains(subcommand)) {
    throw FormatException('Unknown plugins command: $subcommand');
  }
  final root =
      options.repo ??
      Platform.environment['WATCHTOWER_EXTENSIONS_DIR'] ??
      '../watchtower-extensions';
  final catalog = await loadWatchtowerCliPluginCatalog(root);
  final revision = await _readGitRevision(root);
  final requestedId = options.positional.length > 2
      ? options.positional[2].toLowerCase()
      : null;
  final visiblePlugins = catalog.plugins
      .where((plugin) => options.includeNsfw || plugin['isNsfw'] != true)
      .toList();
  final selected = requestedId == null
      ? visiblePlugins
      : visiblePlugins
            .where(
              (plugin) => plugin['id']?.toString().toLowerCase() == requestedId,
            )
            .toList();
  if (requestedId != null && selected.isEmpty) {
    throw ArgumentError('Plugin not found: $requestedId');
  }

  if (subcommand == 'show') {
    if (requestedId == null) {
      throw ArgumentError('Usage: plugins show <id>');
    }
    if (selected.length != 1) {
      throw StateError(
        'Plugin id is ambiguous in this catalogue; run plugins validate first.',
      );
    }
    _printJsonOrLines(selected.single, options);
    return 0;
  }
  if (subcommand == 'list') {
    if (options.json) {
      _printJsonOrLines({
        ...catalog.toJson(),
        'repositoryRevision': ?revision,
        'plugins': selected,
        'total': selected.length,
      }, options);
    } else {
      for (final plugin in selected) {
        stdout.writeln(
          '${plugin['id']}\t${plugin['version']}\t'
          '${plugin['category'] ?? '-'}\t${plugin['name']}',
        );
      }
      stderr.writeln('${selected.length} plugin(s) in ${catalog.root}');
    }
    return 0;
  }

  final selectedIds = selected
      .map((plugin) => plugin['id']?.toString())
      .toSet();
  final failures = catalog.failures
      .where(
        (failure) =>
            requestedId == null ||
            selectedIds.contains(failure['id']?.toString()),
      )
      .toList();
  final report = {
    'root': catalog.root,
    'repositoryRevision': ?revision,
    'lastUpdated': ?catalog.lastUpdated,
    'total': selected.length,
    'valid': failures.isEmpty,
    'failures': failures,
    'plugins': selected,
  };
  if (options.json) {
    _printJsonOrLines(report, options);
  } else {
    stdout.writeln(
      failures.isEmpty
          ? 'Valid: ${selected.length} plugin(s)'
          : 'Invalid: ${failures.length} issue(s) in the plugin catalog',
    );
    for (final failure in failures) {
      stderr.writeln(
        '${failure['id'] ?? 'entry ${failure['index']}'} '
        '${failure['field'] ?? ''}: ${failure['error']}',
      );
    }
  }
  return failures.isEmpty ? 0 : 1;
}

Future<_Catalog> _loadCatalog(WatchtowerCliOptions options) async {
  final root =
      options.repo ??
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
  final indexedSourcePaths = <String>{};
  await for (final entity in indexDir.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    if (entity.uri.pathSegments.last == 'plugins.json') continue;
    if (options.type != null &&
        !_matchesIndexFile(entity.path, options.type!)) {
      continue;
    }
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
        if (itemType is! int ||
            itemType < 0 ||
            itemType >= ItemType.values.length) {
          continue;
        }
        final sourcePath = _sourcePath(root, metadata);
        indexedSourcePaths.add(p.normalize(File(sourcePath).absolute.path));
        final isNsfw =
            metadata['isNsfw'] == true ||
            (metadata['sourceCodeUrl']?.toString().contains('/nsfw/') ?? false);
        if (isNsfw && !options.includeNsfw) continue;
        final pathType = watchtowerCliSourceTypeFromPath(sourcePath);
        if (options.type != null &&
            pathType != null &&
            !_matchesRequestedType(pathType, options.type!)) {
          continue;
        }
        final sourceLanguage = watchtowerCliSourceLanguage(
          metadata,
          sourcePath,
        );
        if (options.language != null && sourceLanguage != options.language) {
          continue;
        }
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
        final sourceCode = await codeFile.readAsString();
        final effectiveLanguage = watchtowerCliSourceLanguage(
          metadata,
          sourcePath,
          sourceCode: sourceCode,
        );
        final source = Source.fromJson({
          ...metadata,
          'lang': effectiveLanguage ?? metadata['lang'],
          'sourceCode': sourceCode,
          'isAdded': true,
          'isActive': true,
          'isLocal': true,
        });
        if (options.type != null && !_matchesType(source, options.type!)) {
          continue;
        }
        items.add(
          _CatalogItem(metadata: metadata, source: source, file: sourcePath),
        );
      }
    } catch (error) {
      failures.add({'file': entity.path, 'error': error.toString()});
    }
  }
  if (options.includeUnindexed) {
    await _loadUnindexedSources(
      root,
      options,
      items,
      failures,
      indexedSourcePaths,
    );
  }
  items.sort((a, b) => (a.source.name ?? '').compareTo(b.source.name ?? ''));
  failures.sort(
    (a, b) =>
        (a['file']?.toString() ?? '').compareTo(b['file']?.toString() ?? ''),
  );
  return _Catalog(
    root: Directory(root).absolute.path,
    revision: await _readGitRevision(root),
    items: items,
    failures: failures,
  );
}

Future<void> _loadUnindexedSources(
  String root,
  WatchtowerCliOptions options,
  List<_CatalogItem> items,
  List<Map<String, dynamic>> failures,
  Set<String> indexedSourcePaths,
) async {
  final sourceDirectory = Directory(p.join(root, 'src'));
  if (!await sourceDirectory.exists()) return;

  final absoluteRoot = Directory(root).absolute.path;
  await for (final entity in sourceDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File ||
        !entity.path.endsWith('.js') ||
        entity.path.endsWith('.min.js') ||
        p.basename(entity.path) == 'server.js') {
      continue;
    }
    final absolutePath = p.normalize(File(entity.path).absolute.path);
    if (indexedSourcePaths.contains(absolutePath)) continue;

    final relativePath = p
        .relative(absolutePath, from: absoluteRoot)
        .replaceAll(r'\', '/');
    final type = watchtowerCliSourceTypeFromPath(relativePath);
    if (type == null ||
        (options.type != null && !_matchesRequestedType(type, options.type!)) ||
        (!options.includeNsfw && relativePath.startsWith('src/nsfw/'))) {
      continue;
    }

    try {
      final sourceCode = await entity.readAsString();
      final language =
          watchtowerCliSourceLanguage(
            const {},
            relativePath,
            sourceCode: sourceCode,
          ) ??
          'all';
      if (options.language != null && language != options.language) continue;
      final metadata = watchtowerCliMetadataForUnindexedSource(
        relativePath: relativePath,
        sourceCode: sourceCode,
        type: type,
        language: language,
      );
      if (!options.includeNsfw && metadata['isNsfw'] == true) continue;
      final source = Source.fromJson({...metadata, 'sourceCode': sourceCode});
      items.add(
        _CatalogItem(metadata: metadata, source: source, file: absolutePath),
      );
    } catch (error) {
      failures.add({
        'file': entity.path,
        'error': 'could not load unindexed source: ${error.toString()}',
      });
    }
  }
}

bool _matchesRequestedType(String actual, String requested) {
  if (actual == requested) return true;
  return (actual == 'watch' && requested == 'anime') ||
      (actual == 'anime' && requested == 'watch');
}

bool _matchesIndexFile(String indexPath, String requested) {
  final indexedType = p.basenameWithoutExtension(indexPath);
  final requestedType = requested == 'anime' ? 'watch' : requested;
  return indexedType == requestedType;
}

String _sourcePath(String root, Map<String, dynamic> metadata) {
  final raw = metadata['sourceCodeUrl']?.toString() ?? '';
  final parsed = Uri.tryParse(raw);
  final path = parsed?.path ?? raw;
  final marker = path.indexOf('/src/');
  final pkgPath = metadata['pkgPath']?.toString() ?? '';
  final relativePath = marker >= 0
      ? path.substring(marker + 1)
      : pkgPath.isNotEmpty
      ? pkgPath
      : path;
  final absoluteRoot = p.normalize(Directory(root).absolute.path);
  final sourcePath = p.normalize(p.join(absoluteRoot, relativePath));
  if (!p.isWithin(absoluteRoot, sourcePath)) {
    throw FormatException('Source code path escapes the extension repository.');
  }
  return sourcePath;
}

Future<String?> _readGitRevision(String root) async {
  try {
    final result = await Process.run('git', [
      '-C',
      root,
      'rev-parse',
      '--verify',
      'HEAD',
    ], runInShell: false);
    if (result.exitCode == 0) {
      final revision = result.stdout.toString().trim();
      if (revision.isNotEmpty) return revision;
    }
  } catch (_) {}
  return null;
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

int _listExtensions(_Catalog catalog, WatchtowerCliOptions options) {
  if (options.json) {
    _printJsonOrLines({
      'root': catalog.root,
      'repositoryRevision': ?catalog.revision,
      'filters': {
        if (options.type != null) 'type': options.type,
        if (options.language != null) 'language': options.language,
        'includeUnindexed': options.includeUnindexed,
      },
      'total': catalog.items.length,
      'failures': catalog.failures,
      'sources': catalog.items.map(_sourceJson).toList(),
    }, options);
    return catalog.failures.isEmpty ? 0 : 1;
  }
  for (final item in catalog.items) {
    stdout.writeln(
      '${item.source.id}\t${_sourceType(item.source)}\t'
      '${item.source.sourceCodeLanguage.name}\t'
      '${item.source.lang}\t${item.source.name}\t${item.file}',
    );
  }
  stderr.writeln(
    '${catalog.items.length} extension(s), ${catalog.failures.length} file failure(s)',
  );
  return catalog.failures.isEmpty ? 0 : 1;
}

Future<int> _testExtensions(
  _Catalog catalog,
  WatchtowerCliOptions options,
) async {
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
            '${item.source.name} [${item.source.lang}]',
          );
        }
      }
    }

    await Future.wait(List.generate(options.concurrency, (_) => worker()));
    results.sort(
      (a, b) => (a.item.source.name ?? '').compareTo(b.item.source.name ?? ''),
    );
    final passed = results.where((result) => result.ok).length;
    final report = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'version': _version,
      'mode': options.mode,
      'filters': {
        if (options.type != null) 'type': options.type,
        if (options.language != null) 'language': options.language,
        'includeUnindexed': options.includeUnindexed,
      },
      'repository': catalog.root,
      'repositoryRevision': ?catalog.revision,
      'total': results.length,
      'passed': passed,
      'failed': results.length - passed,
      'catalogFailures': catalog.failures,
      'results': results.map((result) => result.toJson()).toList(),
    };
    if (options.report != null) {
      await File(options.report!).writeAsString(
        const JsonEncoder.withIndent('  ').convert(redactCliOutput(report)),
      );
    }
    if (options.json) {
      _printJsonOrLines(report, options);
    } else {
      stdout.writeln(
        'Done: $passed passed, ${results.length - passed} failed '
        '(${results.length} tested)',
      );
      if (options.report != null) {
        stdout.writeln('Report: ${options.report}');
      }
    }
    return passed == results.length && catalog.failures.isEmpty ? 0 : 1;
  } finally {
    await getIsolateService.stop();
    ExtensionServiceRegistry.disposeAll();
  }
}

Future<_TestResult> _testOne(
  _CatalogItem item,
  WatchtowerCliOptions options,
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
        (service) => action(service).timeout(
          Duration(seconds: options.timeoutSeconds),
        ),
      );
      result.steps[name] = _Step(
        ok: true,
        ms: watch.elapsedMilliseconds,
        count: _count(value),
        extra: value is Map ? Map<String, dynamic>.from(value) : null,
      );
    } catch (error) {
      result.ok = false;
      result.steps[name] = _Step(
        ok: false,
        ms: watch.elapsedMilliseconds,
        error: _shortError(error),
        errorType: _errorType(error),
      );
    }
  }

  var supportsLatest = true;
  await step('load', (service) async {
    supportsLatest = service.supportsLatest;
    final preferences = service.getSourcePreferences();
    final headers = service.getHeaders();
    final filters = service.getFilterList().filters;
    return {
      'engine': item.source.sourceCodeLanguage.name,
      'supportsLatest': supportsLatest,
      'preferences': preferences.length,
      'headers': headers.length,
      'filters': filters.length,
    };
  });
  if (options.mode == 'load' || !result.ok) {
    started.stop();
    result.totalMs = started.elapsedMilliseconds;
    return result;
  }

  MPages? popular;
  List<dynamic> filters = const [];
  await step('popular', (service) async {
    popular = await service.getPopular(1);
    return popular!;
  });
  await step('filters', (service) async {
    filters = service.getFilterList().filters;
    return filters;
  });
  if (supportsLatest) {
    await step('latest', (service) => service.getLatestUpdates(1));
  } else {
    result.steps['latest'] = const _Step(
      ok: true,
      ms: 0,
      extra: {'status': 'unsupported'},
    );
  }
  await step('search', (service) => service.search('a', 1, filters));
  await step('suggestions', (service) => service.getSuggestions('a'));
  if (options.mode == 'deep') {
    await step('popularPage2', (service) => service.getPopular(2));
  }

  final probe = popular?.list
      .map((item) => item.link)
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
      detail = await service.getDetail(probe);
      return detail!;
    });
    await step(
      'recommendations',
      (service) => service.getRecommendations(probe),
    );
    await step('comments', (service) => service.getComments(probe));
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
        pages = await service.getPageList(mediaUrl);
        return pages!;
      });
      if (options.mode == 'deep' && pages != null && pages!.isNotEmpty) {
        await step('httpProbe', (_) => _probeHttp(pages!.first.url));
      }
    } else if (item.source.itemType == ItemType.novel) {
      String? html;
      await step('html', (service) async {
        html = await service.getHtmlContent(detail?.name ?? '', mediaUrl);
        return html!;
      });
      if (options.mode == 'deep' && html != null) {
        await step('cleanHtml', (service) => service.cleanHtmlContent(html!));
      }
    } else {
      List<Video>? videos;
      await step('videos', (service) async {
        videos = await service.getVideoList(mediaUrl);
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

Future<int> _runSource(_Catalog catalog, WatchtowerCliOptions options) async {
  if (options.positional.length < 3) {
    throw ArgumentError('Usage: source <id|name> <operation> [arguments]');
  }
  final needle = options.positional[1].toLowerCase();
  final operation = options.positional[2];
  const supportedOperations = {
    'popular',
    'latest',
    'search',
    'detail',
    'videos',
    'pages',
    'filters',
    'preferences',
    'headers',
    'suggestions',
    'custom-list',
    'recommendations',
    'comments',
    'html',
    'clean-html',
    'supports-latest',
    'inspect',
  };
  if (!supportedOperations.contains(operation)) {
    throw FormatException('Unknown source operation: $operation');
  }
  final item = catalog.items.firstWhere(
    (candidate) =>
        candidate.source.name?.toLowerCase() == needle ||
        candidate.source.id.toString() == needle,
    orElse: () => throw ArgumentError('Extension not found: $needle'),
  );
  final url = _requiredOption(options.url, '--url', operation);
  final query = _requiredOption(options.query, '--query', operation);
  final name = _requiredOption(options.name, '--name', operation);
  final customListId = options.positional.length > 3
      ? options.positional[3]
      : null;
  if (operation == 'custom-list' &&
      (customListId == null || customListId.trim().isEmpty)) {
    throw ArgumentError('Usage: source <id|name> custom-list <list-id>');
  }
  if (operation == 'clean-html' &&
      options.inputFile == null &&
      options.text == null) {
    throw ArgumentError(
      'source clean-html requires --input-file FILE or --text HTML.',
    );
  }
  await getIsolateService.start();
  try {
    final value = await withExtensionService(item.source, (service) async {
      switch (operation) {
        case 'popular':
          return service.getPopular(options.page);
        case 'latest':
          if (!service.supportsLatest) {
            throw UnsupportedError(
              'This source does not support latest updates.',
            );
          }
          return service.getLatestUpdates(options.page);
        case 'search':
          return service.search(
            query!,
            options.page,
            _filtersFromJson(options.filtersJson, service.getFilterList()),
          );
        case 'detail':
          return service.getDetail(url!);
        case 'videos':
          return service.getVideoList(url!);
        case 'pages':
          return service.getPageList(url!);
        case 'filters':
          return service.getFilterList();
        case 'preferences':
          return service.getSourcePreferences();
        case 'headers':
          return service.getHeaders();
        case 'supports-latest':
          return {'supported': service.supportsLatest};
        case 'suggestions':
          return service.getSuggestions(query!);
        case 'custom-list':
          return service.getCustomList(customListId!, options.page);
        case 'recommendations':
          return service.getRecommendations(url!);
        case 'comments':
          return service.getComments(url!);
        case 'html':
          return service.getHtmlContent(name!, url!);
        case 'clean-html':
          final html =
              options.text ?? await File(options.inputFile!).readAsString();
          return service.cleanHtmlContent(html);
        case 'inspect':
          return {
            'id': item.source.id,
            'name': item.source.name,
            'lang': item.source.lang,
            'type': _sourceType(item.source),
            'engine': item.source.sourceCodeLanguage.name,
            'version': item.source.version,
            'baseUrl': item.source.baseUrl,
            'supportsLatest': service.supportsLatest,
            'headers': service.getHeaders(),
            'filters': service.getFilterList(),
            'preferences': service.getSourcePreferences(),
          };
        default:
          throw StateError('Operation was not validated: $operation');
      }
    }).timeout(Duration(seconds: options.timeoutSeconds));
    _printJsonOrLines(_serialize(value), options);
    return 0;
  } finally {
    await getIsolateService.stop();
    ExtensionServiceRegistry.disposeAll();
  }
}

String? _requiredOption(String? value, String option, String operation) {
  const urlOperations = {
    'detail',
    'videos',
    'pages',
    'recommendations',
    'comments',
    'html',
  };
  if ((option == '--url' && urlOperations.contains(operation)) ||
      (option == '--query' &&
          const {'search', 'suggestions'}.contains(operation)) ||
      (option == '--name' && operation == 'html')) {
    if (value == null || value.trim().isEmpty) {
      throw ArgumentError('source $operation requires $option.');
    }
  }
  return value;
}

List<dynamic> _filtersFromJson(String? source, FilterList defaults) {
  if (source == null) return defaults.filters;
  final decoded = jsonDecode(source);
  final raw = decoded is Map ? decoded['filters'] : decoded;
  if (raw is! List) {
    throw const FormatException(
      '--filters-json must be a JSON array or an object with a filters array.',
    );
  }
  final parsed = fromJsonFilterValuesToList(raw);
  if (parsed.length != raw.length) {
    throw const FormatException(
      '--filters-json contains an unknown or invalid filter type.',
    );
  }
  return parsed;
}

Map<String, dynamic> _sourceJson(_CatalogItem item) => {
  ...item.metadata,
  'id': item.source.id,
  'name': item.source.name,
  'lang': item.source.lang,
  'file': item.file,
  'type': _sourceType(item.source),
  'engine': item.source.sourceCodeLanguage.name,
};

dynamic _serialize(Object? value) {
  if (value is MPages) {
    return {
      'list': value.list.map(_serialize).toList(),
      'hasNextPage': value.hasNextPage,
    };
  }
  if (value is MManga) {
    return {
      'name': value.name,
      'previewUrl': value.previewUrl,
      'imageUrl': value.imageUrl,
      'link': value.link,
      'author': value.author,
      'artist': value.artist,
      'collectionId': value.collectionId,
      'description': value.description,
      'status': value.status?.name,
      'genre': value.genre,
      'chapters': value.chapters?.map(_serialize).toList() ?? [],
    };
  }
  if (value is FilterList) return _serialize(value.toJson());
  if (value is SourcePreference) return _serialize(value.toJson());
  if (value is MChapter) return value.toJson();
  if (value is Video) return value.toJson();
  if (value is PageUrl) return value.toJson();
  if (value is Iterable) return value.map(_serialize).toList();
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', _serialize(val)));
  }
  return value;
}

int? _count(Object? value) {
  if (value is MPages) return value.list.length;
  if (value is Iterable) return value.length;
  if (value is MManga) return value.chapters?.length ?? 0;
  return null;
}

String _shortError(Object error) {
  final value = sanitizeCliText(error.toString()).replaceAll('\n', ' ');
  return value.length > 500 ? '${value.substring(0, 497)}...' : value;
}

String _errorType(Object error) {
  if (error is TimeoutException) return 'timeout';
  if (error is SocketException || error is HttpException) return 'network';
  if (error is UnsupportedError) return 'unsupported';
  if (error is FormatException || error is ArgumentError) return 'input';
  return 'runtime';
}

Future<int> _probeHttp(String url) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    request.followRedirects = true;
    final response = await request.close().timeout(const Duration(seconds: 20));
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

void _printJsonOrLines(Object value, WatchtowerCliOptions options) {
  final safeValue = redactCliOutput(value);
  if (options.json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(safeValue));
  } else if (safeValue is Map) {
    for (final entry in safeValue.entries) {
      stdout.writeln('${entry.key}: ${entry.value}');
    }
  } else {
    stdout.writeln(safeValue);
  }
}
