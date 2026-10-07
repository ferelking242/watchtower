import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watchtower/cli/commands/cli_command.dart';

/// Reads the extension/plugin catalog shipped in a watchtower-extensions
/// checkout. This is the same `index/plugins.json` the app's marketplace
/// consumes, so plugin validation matches what the app would install.
class PluginsCommand extends CliCommand {
  @override
  String get name => 'plugins';

  @override
  String get summary => 'Inspect and validate the plugin catalog';

  @override
  List<String> get usage => const [
    'plugins list [--repo DIR]',
    'plugins show <id> [--repo DIR]',
    'plugins validate [--repo DIR]',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    final repo = context.invocation.option('repo');
    switch (context.invocation.subcommand) {
      case 'list':
        final catalog = _load(repo);
        context.output.result(catalog.summary());
        return const CliResult.ok();
      case 'show':
        final id = context.requireArgument(0, '<id>');
        final catalog = _load(repo);
        final plugin = catalog.plugins
            .where((e) => '${e['id']}' == id)
            .toList();
        if (plugin.isEmpty) {
          throw CliUsageException('No plugin with id "$id".');
        }
        context.output.result(plugin.first);
        return const CliResult.ok();
      case 'validate':
        final catalog = _load(repo);
        context.output.result(catalog.summary());
        return CliResult(catalog.failures.isEmpty ? 0 : 1);
      case null:
        throw CliUsageException('Usage: plugins <list|show|validate>');
      default:
        throw CliUsageException(
          'Unknown plugins subcommand: ${context.invocation.subcommand}',
        );
    }
  }

  PluginCatalog _load(String? repo) {
    if (repo == null || repo.isEmpty) {
      throw CliUsageException(
        'plugins requires --repo DIR pointing at a watchtower-extensions '
        'checkout (the app reads the same index/plugins.json).',
      );
    }
    return loadPluginCatalog(repo);
  }
}

/// Parses `<repo>/index/plugins.json`, the same catalog the app's marketplace
/// consumes, and reports structurally invalid entries instead of failing.
PluginCatalog loadPluginCatalog(String repo) {
  final indexFile = File(
    p.join(Directory(repo).absolute.path, 'index', 'plugins.json'),
  );
  if (!indexFile.existsSync()) {
    throw CliUsageException('Plugin index not found at ${indexFile.path}.');
  }
  final decoded = jsonDecode(indexFile.readAsStringSync());
  if (decoded is! Map || decoded['plugins'] is! List) {
    throw CliUsageException(
      'index/plugins.json must be an object containing a plugins array.',
    );
  }
  final plugins = <Map<String, dynamic>>[];
  final failures = <Map<String, Object?>>[];
  final seen = <String>{};
  final entries = decoded['plugins'] as List;
  for (var i = 0; i < entries.length; i++) {
    final raw = entries[i];
    if (raw is! Map) {
      failures.add({'index': i, 'error': 'entry must be a JSON object'});
      continue;
    }
    final id = '${raw['id'] ?? ''}';
    if (id.isEmpty) {
      failures.add({'index': i, 'error': 'missing id'});
      continue;
    }
    if (!seen.add(id)) {
      failures.add({'index': i, 'error': 'duplicate id "$id"'});
      continue;
    }
    plugins.add(raw.cast<String, dynamic>());
  }
  return PluginCatalog(
    root: Directory(repo).absolute.path,
    lastUpdated: decoded['lastUpdated']?.toString(),
    plugins: plugins,
    failures: failures,
  );
}

class PluginCatalog {
  PluginCatalog({
    required this.root,
    required this.lastUpdated,
    required this.plugins,
    required this.failures,
  });

  final String root;
  final String? lastUpdated;
  final List<Map<String, dynamic>> plugins;
  final List<Map<String, Object?>> failures;

  Map<String, Object?> summary() => {
    'root': root,
    if (lastUpdated != null) 'lastUpdated': lastUpdated,
    'total': plugins.length,
    'valid': failures.isEmpty,
    'failures': failures,
    'plugins': plugins,
  };
}
