import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class WatchtowerCliPluginCatalog {
  final String root;
  final String? lastUpdated;
  final List<Map<String, dynamic>> plugins;
  final List<Map<String, dynamic>> failures;

  const WatchtowerCliPluginCatalog({
    required this.root,
    required this.lastUpdated,
    required this.plugins,
    required this.failures,
  });

  Map<String, dynamic> toJson() => {
    'root': root,
    if (lastUpdated != null) 'lastUpdated': lastUpdated,
    'total': plugins.length,
    'valid': failures.isEmpty,
    'failures': failures,
    'plugins': plugins,
  };
}

Future<WatchtowerCliPluginCatalog> loadWatchtowerCliPluginCatalog(
  String root,
) async {
  final absoluteRoot = Directory(root).absolute.path;
  final indexFile = File(p.join(absoluteRoot, 'index', 'plugins.json'));
  if (!await indexFile.exists()) {
    throw ArgumentError(
      'Plugin index not found at ${indexFile.path}. '
      'Use --repo /path/to/watchtower-extensions.',
    );
  }

  final decoded = jsonDecode(await indexFile.readAsString());
  if (decoded is! Map || decoded['plugins'] is! List) {
    throw const FormatException(
      'index/plugins.json must be an object containing a plugins array.',
    );
  }

  final plugins = <Map<String, dynamic>>[];
  final failures = <Map<String, dynamic>>[];
  final ids = <String>{};
  final entries = decoded['plugins'] as List;
  for (var index = 0; index < entries.length; index++) {
    final raw = entries[index];
    if (raw is! Map) {
      failures.add({
        'index': index,
        'error': 'plugin entry must be a JSON object',
      });
      continue;
    }

    final plugin = Map<String, dynamic>.from(raw);
    final id = plugin['id']?.toString().trim() ?? '';
    final entryFailures = _validatePlugin(plugin, index);
    if (id.isNotEmpty && !ids.add(id)) {
      entryFailures.add({
        'index': index,
        'id': id,
        'field': 'id',
        'error': 'duplicate plugin id',
      });
    }
    plugins.add(plugin);
    failures.addAll(entryFailures);
  }

  plugins.sort(
    (a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''),
  );
  failures.sort((a, b) {
    final left = a['index'] is int ? a['index'] as int : -1;
    final right = b['index'] is int ? b['index'] as int : -1;
    return left.compareTo(right);
  });
  return WatchtowerCliPluginCatalog(
    root: absoluteRoot,
    lastUpdated: decoded['_lastUpdated']?.toString(),
    plugins: plugins,
    failures: failures,
  );
}

List<Map<String, dynamic>> _validatePlugin(
  Map<String, dynamic> plugin,
  int index,
) {
  final issues = <Map<String, dynamic>>[];
  final id = plugin['id']?.toString();

  void issue(String field, String message) {
    issues.add({
      'index': index,
      if (id != null && id.isNotEmpty) 'id': id,
      'field': field,
      'error': message,
    });
  }

  for (final field in const [
    'id',
    'name',
    'version',
    'author',
    'description',
    'category',
    'runtime',
  ]) {
    final value = plugin[field];
    if (value is! String || value.trim().isEmpty) {
      issue(field, 'required non-empty string is missing');
    }
  }

  const stringArrayFields = [
    'tags',
    'screenshots',
    'permissions',
    'writePaths',
  ];
  for (final field in stringArrayFields) {
    if (plugin.containsKey(field) &&
        (plugin[field] is! List ||
            (plugin[field] as List).any((value) => value is! String))) {
      issue(field, 'must be an array of strings');
    }
  }

  const objectArrayFields = ['requirements', 'commandScopes'];
  for (final field in objectArrayFields) {
    if (plugin.containsKey(field) &&
        (plugin[field] is! List ||
            (plugin[field] as List).any((value) => value is! Map))) {
      issue(field, 'must be an array of objects');
    }
  }

  for (final field in const ['featured', 'isNsfw', 'requiresAccount']) {
    if (plugin.containsKey(field) && plugin[field] is! bool) {
      issue(field, 'must be a boolean');
    }
  }

  final networkAccess = plugin['networkAccess'];
  if (networkAccess != null) {
    final isDomainList =
        networkAccess is List &&
        networkAccess.every((value) => value is String);
    final isDomainObject =
        networkAccess is Map &&
        (networkAccess['allowedDomains'] == null ||
            (networkAccess['allowedDomains'] is List &&
                (networkAccess['allowedDomains'] as List).every(
                  (value) => value is String,
                )));
    if (!isDomainList && !isDomainObject) {
      issue(
        'networkAccess',
        'must be a string array or an allowedDomains object',
      );
    }
  }

  final userConfig = plugin['userConfig'];
  if (userConfig != null) {
    if (userConfig is! Map) {
      issue('userConfig', 'must be an object');
    } else if (userConfig['fields'] != null &&
        (userConfig['fields'] is! List ||
            (userConfig['fields'] as List).any((field) => field is! Map))) {
      issue('userConfig.fields', 'must be an array of objects');
    }
  }

  final watchtower = plugin['watchtower'];
  if (watchtower != null && watchtower is! Map) {
    issue('watchtower', 'must be an object');
  }
  return issues;
}
