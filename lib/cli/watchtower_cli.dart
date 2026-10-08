import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/commands/downloads_command.dart';
import 'package:watchtower/cli/commands/extensions_command.dart';
import 'package:watchtower/cli/commands/library_command.dart';
import 'package:watchtower/cli/commands/meta_commands.dart';
import 'package:watchtower/cli/commands/plugins_command.dart';
import 'package:watchtower/cli/commands/sources_command.dart';
import 'package:watchtower/cli/commands/trackers_command.dart';
import 'package:watchtower/cli/output/cli_output.dart';
import 'package:watchtower/cli/runtime/cli_arguments.dart';
import 'package:watchtower/cli/runtime/cli_extension_catalog.dart';
import 'package:watchtower/cli/runtime/cli_extension_tester.dart';
import 'package:watchtower/cli/runtime/cli_runtime.dart';
import 'package:watchtower/cli/watchtower_cli_safety.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/services/isolate_service.dart';

/// Entry point for `watchtower --cli …`.
///
/// Boots the real application runtime (database, settings, extension workers,
/// download pool) and dispatches to a command. Because every command reuses
/// the app's own providers and services, the CLI is a faithful headless client
/// — and a faithful bug reproducer.
Future<int> runWatchtowerCli(List<String> args) async {
  final invocation = parseCliInvocation(args);
  final output = CliOutput(format: invocation.format, quiet: invocation.quiet);
  final registry = CliCommandRegistry([
    ExtensionsCommand(),
    SourcesCommand(),
    LibraryCommand(),
    DownloadsCommand(),
    TrackersCommand(),
    PluginsCommand(),
    DoctorCommand(),
    SettingsCommand(),
    VersionCommand(),
    HelpCommand(),
  ]);
  for (final command in registry.commands) {
    if (command is HelpCommand) command.registry = registry;
  }

  final commandName = invocation.command;

  // Help and version are answered without touching the database so they work
  // even when the data directory is unavailable.
  if (commandName == null || invocation.help || commandName == 'help') {
    final topic = commandName == 'help'
        ? (invocation.subcommand ?? invocation.arguments.firstOrNull)
        : commandName;
    output.info(buildCliHelp(registry, commandName: topic));
    return 0;
  }
  if (commandName == 'version') {
    output.result({'version': cliVersion});
    return 0;
  }

  // `source` is the legacy, repo-backed operation runner. It resolves the
  // extension from the local repository rather than the database, so it works
  // headlessly (and is what `scripts/test-eporner.py` drives). It is not a
  // registry command, so handle it before the lookup.
  if (commandName == 'source') {
    return _runLocalSource(invocation, output);
  }

  final command = registry.find(commandName);
  if (command == null) {
    output.error('Unknown command: $commandName');
    output.info(buildCliHelp(registry));
    return 64;
  }

  // `doctor` and the local-repository extension commands run the real engine
  // without opening the database, so they work on a machine where Isar is not
  // available (exactly like the app's pre-UI startup checks).
  if (commandName == 'doctor') {
    return _runWithoutRuntime(command, invocation, output);
  }
  if (commandName == 'extensions' &&
      const {'list', 'test'}.contains(invocation.subcommand)) {
    return _runLocalExtensions(invocation, output);
  }

  CliRuntime runtime;
  try {
    runtime = await CliRuntime.boot(
      dataDirectory: invocation.option('data-dir'),
      mock: invocation.hasFlag('mock'),
      verbose: invocation.hasFlag('verbose'),
    );
  } catch (error, stackTrace) {
    output.error('Failed to initialise Watchtower runtime: $error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 2;
  }

  final context = CliContext(
    runtime: runtime,
    invocation: invocation,
    output: output,
  );

  try {
    final result = await command.run(context);
    return result.exitCode;
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  } catch (error, stackTrace) {
    output.error('$error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 1;
  } finally {
    await output.flush();
    await runtime.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Runs a command that needs no database access (currently only `doctor`).
Future<int> _runWithoutRuntime(
  CliCommand command,
  CliInvocation invocation,
  CliOutput output,
) async {
  final context = CliContext(
    runtime: CliRuntime.lazy(),
    invocation: invocation,
    output: output,
  );
  try {
    final result = await command.run(context);
    return result.exitCode;
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  } catch (error, stackTrace) {
    output.error('$error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 1;
  } finally {
    await output.flush();
  }
}

/// Lists or tests extensions from a local `watchtower-extensions` checkout.
/// This path is file-only: it never opens the database.
Future<int> _runLocalExtensions(
  CliInvocation invocation,
  CliOutput output,
) async {
  final root =
      invocation.option('repo') ??
      invocation.option('extensions-dir') ??
      invocation.option('extensions') ??
      Platform.environment['WATCHTOWER_EXTENSIONS_DIR'] ??
      'watchtower-extensions';

  final CliExtensionFilter filter;
  try {
    filter = _extensionFilter(invocation);
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  }

  CliExtensionCatalog catalog;
  try {
    catalog = await loadCliExtensionCatalog(root: root, filter: filter);
  } on ArgumentError catch (error) {
    output.error(error.message);
    return 64;
  } catch (error, stackTrace) {
    output.error('$error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 1;
  }

  final subcommand = invocation.subcommand;
  if (subcommand == 'list') {
    final report = <String, Object?>{
      'root': catalog.root,
      'repositoryRevision': ?catalog.revision,
      'filters': filter.toJson(),
      'total': catalog.items.length,
      'failures': catalog.failures,
      'sources': catalog.items.map(_extensionJson).toList(),
    };
    if (!invocation.quiet && !output.isJson) {
      output.info('Selected ${catalog.items.length} extension(s).');
    }
    output.result(redactCliOutput(report));
    return catalog.failures.isEmpty ? 0 : 1;
  }

  final mode = invocation.option('mode') ?? 'load';
  if (!const {'load', 'smoke', 'deep'}.contains(mode)) {
    output.error(
      'Unknown test mode "$mode". Supported modes: load, smoke, deep.',
    );
    return 64;
  }
  final tester = CliExtensionTester(
    mode: mode,
    concurrency: invocation.intOption('concurrency', fallback: 4).clamp(1, 16),
    timeoutSeconds: invocation.intOption('timeout', fallback: 45).clamp(1, 300),
    filter: filter,
  );
  final report = await tester.run(catalog);
  await writeCliExtensionReport(report, invocation.option('report'));
  if (!invocation.quiet && !output.isJson) {
    final results = (report['results'] as List?) ?? const [];
    final failedNames = results
        .whereType<Map>()
        .where((result) => result['ok'] != true)
        .map((result) => result['name']?.toString() ?? '?')
        .toList();
    output.info(
      'Tested ${report['total']} extension(s) in $mode mode: '
      '${report['passed']} passed, ${report['failed']} failed.',
    );
    if (failedNames.isNotEmpty) {
      output.info('Failed: ${failedNames.join(', ')}');
    }
  }
  output.result(redactCliOutput(report));
  final failed = (report['failed'] as int?) ?? 0;
  return failed == 0 && catalog.failures.isEmpty ? 0 : 1;
}

Map<String, dynamic> _extensionJson(CliExtension item) => {
  ...item.metadata,
  'id': item.source.id,
  'name': item.source.name,
  'lang': item.source.lang,
  'file': item.file,
  'type': cliExtensionSourceType(item.source),
  'engine': item.source.sourceCodeLanguage.name,
};

/// Builds the extension selection filter from CLI options. Mirrors the app's
/// diagnostic-screen filters so the same subset can be tested headlessly.
CliExtensionFilter _extensionFilter(CliInvocation invocation) {
  final nsfw = switch (true) {
    _ when invocation.hasFlag('nsfw') => CliNsfwFilter.nsfw,
    _ when invocation.hasFlag('sfw') || invocation.hasFlag('exclude-nsfw') =>
      CliNsfwFilter.sfw,
    _ => CliNsfwFilter.all,
  };
  final engine = invocation.firstOption(['engine', 'code', 'source-code']);
  if (engine != null &&
      !const {'javascript', 'dart'}.contains(engine.toLowerCase())) {
    throw CliUsageException(
      'Unknown --engine "$engine". Supported engines: javascript, dart.',
    );
  }
  final tags = invocation.listOption(['tag', 'tags']);
  final unknownTags = tags.where(
    (tag) => !cliExtensionSourceTags.contains(tag),
  );
  if (unknownTags.isNotEmpty) {
    throw CliUsageException(
      'Unknown --tag "${unknownTags.first}". Supported tags: '
      '${cliExtensionSourceTags.toList()..sort()}.',
    );
  }
  return CliExtensionFilter(
    type: invocation.firstOption(['type', 'item-type']),
    languages: invocation.listOption(['lang', 'language', 'languages']),
    nsfw: nsfw,
    engine: engine?.toLowerCase(),
    tags: tags,
    query: invocation.firstOption(['query', 'search']),
    ids: invocation.listOption(['only', 'id', 'source']),
    includeUnindexed:
        invocation.hasFlag('include-unindexed') ||
        invocation.hasFlag('scan-unindexed'),
  );
}

/// Runs a single real extension operation resolved from the local repository.
/// Contract: `source <id|name> <operation> [list-id] [--repo DIR] [--url …]`.
Future<int> _runLocalSource(CliInvocation invocation, CliOutput output) async {
  final positional = invocation.positional;
  if (positional.length < 3) {
    output.error('Usage: source <id|name> <operation> [arguments]');
    return 64;
  }
  final needle = positional[1].toLowerCase();
  final operation = positional[2];
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
    output.error('Unknown source operation: $operation');
    return 64;
  }
  final customListId = positional.length > 3 ? positional[3] : null;
  if (operation == 'custom-list' &&
      (customListId == null || customListId.trim().isEmpty)) {
    output.error('Usage: source <id|name> custom-list <list-id>');
    return 64;
  }

  final root =
      invocation.option('repo') ??
      invocation.option('extensions-dir') ??
      Platform.environment['WATCHTOWER_EXTENSIONS_DIR'] ??
      'watchtower-extensions';
  CliExtensionCatalog catalog;
  try {
    catalog = await loadCliExtensionCatalog(
      root: root,
      filter: _extensionFilter(invocation),
    );
  } on ArgumentError catch (error) {
    output.error(error.message);
    return 64;
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  }
  final item = catalog.items
      .where(
        (candidate) =>
            candidate.source.name?.toLowerCase() == needle ||
            candidate.source.id.toString() == needle,
      )
      .firstOrNull;
  if (item == null) {
    output.error('Extension not found: $needle');
    return 64;
  }

  final page = invocation.intOption('page', fallback: 1);
  final timeoutSeconds = invocation.intOption('timeout', fallback: 45);
  final url = invocation.option('url');
  final query = invocation.option('query');
  final name = invocation.option('name');

  await getIsolateService.start();
  try {
    final value = await withExtensionService(item.source, (service) async {
      switch (operation) {
        case 'popular':
          return service.getPopular(page);
        case 'latest':
          if (!service.supportsLatest) {
            throw UnsupportedError(
              'This source does not support latest updates.',
            );
          }
          return service.getLatestUpdates(page);
        case 'search':
          if (query == null || query.trim().isEmpty) {
            throw ArgumentError('source search requires --query.');
          }
          return service.search(
            query,
            page,
            _filtersFromJson(
              invocation.option('filters'),
              service.getFilterList(),
            ),
          );
        case 'detail':
          return service.getDetail(_require(url, '--url', operation));
        case 'videos':
          return service.getVideoList(_require(url, '--url', operation));
        case 'pages':
          return service.getPageList(_require(url, '--url', operation));
        case 'filters':
          return service.getFilterList();
        case 'preferences':
          return service.getSourcePreferences();
        case 'headers':
          return service.getHeaders();
        case 'supports-latest':
          return {'supported': service.supportsLatest};
        case 'suggestions':
          return service.getSuggestions(_require(query, '--query', operation));
        case 'custom-list':
          return service.getCustomList(customListId!, page);
        case 'recommendations':
          return service.getRecommendations(_require(url, '--url', operation));
        case 'comments':
          return service.getComments(_require(url, '--url', operation));
        case 'html':
          return service.getHtmlContent(
            _require(name, '--name', operation),
            _require(url, '--url', operation),
          );
        case 'clean-html':
          final html =
              invocation.option('text') ??
              await _readTextFile(invocation.option('input-file'));
          return service.cleanHtmlContent(html);
        case 'inspect':
          return {
            'id': item.source.id,
            'name': item.source.name,
            'lang': item.source.lang,
            'type': cliExtensionSourceType(item.source),
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
    }).timeout(Duration(seconds: timeoutSeconds));
    output.result(redactCliOutput(cliSerializeEvalValue(value)));
    return 0;
  } on CliUsageException catch (error) {
    output.error(error.message);
    return 64;
  } catch (error, stackTrace) {
    output.error('$error');
    if (invocation.hasFlag('verbose')) output.warn('$stackTrace');
    return 1;
  } finally {
    await getIsolateService.stop();
    ExtensionServiceRegistry.disposeAll();
    await output.flush();
  }
}

String _require(String? value, String option, String operation) {
  if (value == null || value.trim().isEmpty) {
    throw CliUsageException('source $operation requires $option.');
  }
  return value;
}

Future<String> _readTextFile(String? path) async {
  if (path == null || path.isEmpty) {
    throw CliUsageException(
      'source clean-html requires --input-file FILE or --text HTML.',
    );
  }
  return File(path).readAsString();
}

List<dynamic> _filtersFromJson(String? source, FilterList defaults) {
  if (source == null || source.isEmpty) return defaults.filters;
  final decoded = jsonDecode(source);
  final raw = decoded is Map ? decoded['filters'] : decoded;
  if (raw is! List) {
    throw CliUsageException(
      '--filters must be a JSON array or an object with a filters array.',
    );
  }
  final parsed = fromJsonFilterValuesToList(raw);
  if (parsed.length != raw.length) {
    throw CliUsageException(
      '--filters contains an unknown or invalid filter type.',
    );
  }
  return parsed;
}
