import 'dart:convert';
import 'dart:io';

import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/search.dart';

/// Runs extension operations through the SAME Riverpod providers the app UI
/// calls (`getPopular`, `getLatestUpdates`, `search`, `getDetail`) and the
/// same extension runtime for the remaining operations. Any extension or app
/// bug therefore reproduces here verbatim.
class SourcesCommand extends CliCommand {
  @override
  String get name => 'sources';

  @override
  String get summary =>
      'Run extension operations (popular, search, detail, videos, pages…)';

  @override
  List<String> get usage => const [
    'sources <source|id> popular [--page N]',
    'sources <source|id> latest [--page N]',
    'sources <source|id> search --query TEXT [--page N] [--filters JSON]',
    'sources <source|id> detail --url URL',
    'sources <source|id> videos --url URL',
    'sources <source|id> pages --url URL',
    'sources <source|id> custom-list --list ID [--page N]',
    'sources <source|id> recommendations --url URL',
    'sources <source|id> comments --url URL',
    'sources <source|id> suggestions --query TEXT',
    'sources <source|id> filters',
    'sources <source|id> preferences',
    'sources <source|id> headers',
    'sources <source|id> supports-latest',
    'sources <source|id> html --name NAME --url URL',
    'sources <source|id> clean-html (--text HTML | --input-file FILE)',
    'sources <source|id> inspect',
    '',
    'Options: --type manga|anime|novel|music|game  --json  --timeout SECONDS',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    final operation = context.invocation.subcommand;
    if (operation == null) {
      throw CliUsageException('Usage: sources <source|id> <operation>');
    }

    final reference = context.requireArgument(0, '<source|id>');
    final itemType = _parseItemType(context.invocation.option('type'));
    final source = context.runtime.findSource(reference, itemType: itemType);
    if (source == null) {
      throw CliUsageException(
        'No source matches "$reference". Run `extensions list` first.',
      );
    }
    if (source.isAdded != true) {
      throw CliUsageException(
        'Source "${source.name}" is not installed. '
        'Run `extensions install "${source.name}"` first.',
      );
    }

    final page = context.invocation.intOption('page', fallback: 1);
    final timeout = Duration(
      seconds: context.invocation.intOption('timeout', fallback: 180),
    );

    final result = await _dispatch(
      context,
      operation,
      source,
      page,
    ).timeout(timeout);
    context.output.result(cliSerialize(result));
    return const CliResult.ok();
  }

  Future<Object?> _dispatch(
    CliContext context,
    String operation,
    Source source,
    int page,
  ) {
    final invocation = context.invocation;
    final container = context.runtime.container;
    switch (operation) {
      case 'popular':
        return container.read(
          getPopularProvider(source: source, page: page).future,
        );
      case 'latest':
        return container.read(
          getLatestUpdatesProvider(source: source, page: page).future,
        );
      case 'search':
        return container.read(
          searchProvider(
            source: source,
            query: context.requireOption('query'),
            page: page,
            filterList: _parseFilters(invocation.option('filters')),
          ).future,
        );
      case 'detail':
        return container.read(
          getDetailProvider(
            source: source,
            url: context.requireOption('url'),
          ).future,
        );
      case 'custom-list':
        return _customList(context, source, page);
      default:
        return _runDirect(context, operation, source);
    }
  }

  /// Custom browse tabs are an extension capability not wrapped in a provider
  /// in the app; it is executed through the shared extension registry.
  Future<Object?> _customList(CliContext context, Source source, int page) {
    final listId = context.requireOption('list');
    return withExtensionService(
      source,
      (service) => service.getCustomList(listId, page),
    );
  }

  /// Operations the app runs straight through the extension runtime.
  Future<Object?> _runDirect(
    CliContext context,
    String operation,
    Source source,
  ) {
    return withExtensionService(source, (service) async {
      switch (operation) {
        case 'videos':
          return service.getVideoList(context.requireOption('url'));
        case 'pages':
          return service.getPageList(context.requireOption('url'));
        case 'recommendations':
          return service.getRecommendations(context.requireOption('url'));
        case 'comments':
          return service.getComments(context.requireOption('url'));
        case 'suggestions':
          return service.getSuggestions(context.requireOption('query'));
        case 'html':
          return service.getHtmlContent(
            context.requireOption('name'),
            context.requireOption('url'),
          );
        case 'clean-html':
          return service.cleanHtmlContent(await _htmlInput(context));
        case 'filters':
          return service.getFilterList().filters;
        case 'preferences':
          return service.getSourcePreferences();
        case 'headers':
          return service.getHeaders();
        case 'supports-latest':
          return {'supported': service.supportsLatest};
        case 'inspect':
          return {
            'id': source.id,
            'name': source.name,
            'lang': source.lang,
            'type': source.itemType.name,
            'engine': source.sourceCodeLanguage.name,
            'version': source.version,
            'baseUrl': source.baseUrl,
            'supportsLatest': service.supportsLatest,
            'headers': service.getHeaders(),
            'filters': service.getFilterList().filters,
            'preferences': service.getSourcePreferences(),
          };
        default:
          throw CliUsageException('Unknown source operation: $operation');
      }
    });
  }

  Future<String> _htmlInput(CliContext context) async {
    final text = context.invocation.option('text');
    if (text != null) return text;
    final path = context.invocation.option('input-file');
    if (path == null) {
      throw CliUsageException(
        'clean-html requires --text HTML or --input-file FILE',
      );
    }
    final file = File(path);
    if (!file.existsSync()) throw CliUsageException('File not found: $path');
    return file.readAsString();
  }

  static ItemType? _parseItemType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final type in ItemType.values) {
      if (type.name == raw.toLowerCase()) return type;
    }
    throw CliUsageException('Unknown item type: $raw');
  }

  static List<dynamic> _parseFilters(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['filters'] is List) {
      return decoded['filters'] as List;
    }
    throw CliUsageException('--filters must be a JSON array of filters');
  }
}
