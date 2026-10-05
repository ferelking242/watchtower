import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/models/source.dart' show SourceCodeLanguage;

const _sourceLocales = {
  'all',
  'ar',
  'de',
  'en',
  'es',
  'fr',
  'id',
  'it',
  'ja',
  'ko',
  'multi',
  'pl',
  'pt',
  'ru',
  'ta',
  'th',
  'tr',
  'uk',
  'vi',
  'zh',
};

/// Resolves the language of an extension, preferring its source directory over
/// stale index metadata (for example, an `src/watch/fr` entry indexed as `en`).
String? watchtowerCliSourceLanguage(
  Map<String, dynamic> metadata,
  String sourcePath, {
  String? sourceCode,
}) {
  final pathLanguage = _sourceLanguageFromPath(sourcePath);
  if (pathLanguage != null &&
      pathLanguage != 'multi' &&
      pathLanguage != 'all') {
    return pathLanguage;
  }

  final declaration = sourceCode == null
      ? const <String, dynamic>{}
      : _sourceDeclaration(sourceCode);
  final sourceLanguages = _languages(declaration['langs']);
  final languages = sourceLanguages.isNotEmpty
      ? sourceLanguages
      : _languages(metadata['langs']);
  if (languages.length == 1) return languages.single;

  final declaredLanguage = metadata['lang']?.toString().trim().toLowerCase();
  if (declaredLanguage != null && declaredLanguage.isNotEmpty) {
    return declaredLanguage;
  }
  return pathLanguage;
}

/// Returns the Watchtower category encoded by a source path, including NSFW
/// paths such as `src/nsfw/watch/en/example.js`.
String? watchtowerCliSourceTypeFromPath(String sourcePath) {
  final parts = _sourceParts(sourcePath);
  if (parts == null) return null;
  final categoryIndex = parts.$1;
  return switch (parts.$2[categoryIndex]) {
    'manga' => 'manga',
    'watch' => 'watch',
    'novel' => 'novel',
    'music' => 'music',
    'game' => 'game',
    _ => null,
  };
}

/// Builds the minimal indexed-source metadata required to run a local JS
/// extension omitted from index/*.json.
Map<String, dynamic> watchtowerCliMetadataForUnindexedSource({
  required String relativePath,
  required String sourceCode,
  required String type,
  required String language,
}) {
  final declaration = _sourceDeclaration(sourceCode);
  final ids = declaration['ids'];
  final configuredId = ids is Map
      ? ids[language] ?? (ids.length == 1 ? ids.values.first : null)
      : declaration['id'];
  final id = configuredId is num
      ? configuredId.toInt()
      : _stableId(relativePath);
  final name =
      _stringValue(declaration['name']) ??
      _stringProperty(sourceCode, 'name') ??
      p.basenameWithoutExtension(relativePath);
  final configuredBaseUrl =
      _stringValue(declaration['baseUrl']) ??
      _stringProperty(sourceCode, 'baseUrl') ??
      _baseUrlConstant(sourceCode);

  return {
    'id': id,
    'name': name,
    'lang': language,
    'baseUrl': configuredBaseUrl ?? '',
    'apiUrl': _stringValue(declaration['apiUrl']) ?? '',
    'iconUrl': _stringValue(declaration['iconUrl']) ?? '',
    'typeSource': _stringValue(declaration['typeSource']) ?? 'single',
    'itemType': _itemTypeFor(type).index,
    'version': _stringValue(declaration['version']) ?? '0.0.1',
    'sourceCodeUrl': relativePath.replaceAll(r'\', '/'),
    'sourceCodeLanguage': SourceCodeLanguage.javascript.index,
    'isNsfw':
        declaration['isNsfw'] == true ||
        relativePath.replaceAll(r'\', '/').contains('/nsfw/'),
    'isAdded': true,
    'isActive': true,
    'isLocal': true,
  };
}

List<String> _languages(Object? value) {
  if (value is String) return [value.trim().toLowerCase()];
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
  return const [];
}

String? _sourceLanguageFromPath(String sourcePath) {
  final parts = _sourceParts(sourcePath);
  if (parts == null) return null;
  final localeIndex = parts.$1 + 1;
  if (localeIndex >= parts.$2.length - 1) return null;
  final locale = parts.$2[localeIndex].toLowerCase();
  return _sourceLocales.contains(locale) ? locale : null;
}

(int, List<String>)? _sourceParts(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.normalize(normalized).split('/');
  final sourceIndex = parts.lastIndexOf('src');
  if (sourceIndex < 0 || sourceIndex + 1 >= parts.length) return null;
  var categoryIndex = sourceIndex + 1;
  if (parts[categoryIndex] == 'nsfw') categoryIndex++;
  if (categoryIndex >= parts.length - 1) return null;
  return (categoryIndex, parts);
}

ItemType _itemTypeFor(String type) => switch (type) {
  'manga' => ItemType.manga,
  'watch' => ItemType.anime,
  'novel' => ItemType.novel,
  'music' => ItemType.music,
  'game' => ItemType.game,
  _ => throw ArgumentError('Unsupported local extension type: $type'),
};

Map<String, dynamic> _sourceDeclaration(String sourceCode) {
  final marker = sourceCode.indexOf('watchtowerSources');
  if (marker < 0) return const {};
  final start = sourceCode.indexOf('[', marker + 'watchtowerSources'.length);
  if (start < 0) return const {};

  final sourceArray = _balancedArray(sourceCode, start);
  if (sourceArray == null) return const {};
  try {
    final decoded = jsonDecode(sourceArray);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
  } on FormatException {
    // Some sources use a constant (for example BASE_URL) in the declaration.
    // Literal fields are still recovered below without evaluating extension JS.
  }

  final name = _stringProperty(sourceCode, 'name');
  final baseUrl = _stringOrConstant(sourceCode, 'baseUrl');
  final apiUrl = _stringOrConstant(sourceCode, 'apiUrl');
  final iconUrl = _stringProperty(sourceCode, 'iconUrl');
  final typeSource = _stringProperty(sourceCode, 'typeSource');
  final version = _stringProperty(sourceCode, 'version');
  final languages = _stringArrayProperty(sourceCode, 'langs');
  final configuredIds = _integerMapProperty(sourceCode, 'ids');
  final id = _integerProperty(sourceCode, 'id');
  return {
    if (name != null) 'name': name,
    if (baseUrl != null) 'baseUrl': baseUrl,
    if (apiUrl != null) 'apiUrl': apiUrl,
    if (iconUrl != null) 'iconUrl': iconUrl,
    if (typeSource != null) 'typeSource': typeSource,
    if (version != null) 'version': version,
    if (languages.isNotEmpty) 'langs': languages,
    if (configuredIds.isNotEmpty) 'ids': configuredIds,
    if (id != null) 'id': id,
  };
}

String? _balancedArray(String source, int start) {
  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var index = start; index < source.length; index++) {
    final character = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    if (lineComment) {
      if (character == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (character == '*' && next == '/') blockComment = false;
      continue;
    }
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (character == r'\') {
        escaped = true;
      } else if (character == quote) {
        quote = null;
      }
      continue;
    }
    if (character == '/' && next == '/') {
      lineComment = true;
      continue;
    }
    if (character == '/' && next == '*') {
      blockComment = true;
      continue;
    }
    if (character == '"' || character == "'" || character == '`') {
      quote = character;
      continue;
    }
    if (character == '[' || character == '{' || character == '(') {
      depth++;
    } else if (character == ']' || character == '}' || character == ')') {
      depth--;
      if (depth == 0) return source.substring(start, index + 1);
    }
  }
  return null;
}

String? _stringValue(Object? value) => value is String ? value : null;

String? _stringProperty(String source, String key) {
  final escapedKey = RegExp.escape(key);
  final match = RegExp(
    '"$escapedKey"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
    dotAll: true,
  ).firstMatch(source);
  if (match == null) return null;
  try {
    return jsonDecode('"${match.group(1)}"') as String;
  } on FormatException {
    return match.group(1);
  }
}

String? _stringOrConstant(String source, String key) {
  final literal = _stringProperty(source, key);
  if (literal != null) return literal;
  final match = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*([A-Z_][A-Z0-9_]*)',
  ).firstMatch(source);
  if (match == null) return null;
  final constantName = RegExp.escape(match.group(1)!);
  return RegExp(
    '(?:const|let|var)\\s+$constantName\\s*=\\s*["\\x27]([^"\\x27]+)["\\x27]',
  ).firstMatch(source)?.group(1);
}

List<String> _stringArrayProperty(String source, String key) {
  final marker = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*\\[',
  ).firstMatch(source);
  if (marker == null) return const [];
  final end = source.indexOf(']', marker.end);
  if (end < 0) return const [];
  return RegExp(r'''["']([^"']+)["']''')
      .allMatches(source.substring(marker.end, end))
      .map((match) => match.group(1)!.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

Map<String, int> _integerMapProperty(String source, String objectKey) {
  final marker = RegExp(
    '"${RegExp.escape(objectKey)}"\\s*:\\s*\\{',
  ).firstMatch(source);
  if (marker == null) return const {};
  final end = source.indexOf('}', marker.end);
  if (end < 0) return const {};
  final objectBody = source.substring(marker.end, end);
  final entries = <String, int>{};
  for (final match in RegExp(
    r'''["']([^"']+)["']\s*:\s*(-?\d+)''',
  ).allMatches(objectBody)) {
    final value = int.tryParse(match.group(2)!);
    if (value != null) entries[match.group(1)!] = value;
  }
  return entries;
}

int? _integerProperty(String source, String key) {
  final match = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*(-?\\d+)',
  ).firstMatch(source);
  return match == null ? null : int.tryParse(match.group(1)!);
}

String? _baseUrlConstant(String source) {
  final match = RegExp(
    r'''(?:const|let|var)\s+BASE_URL\s*=\s*["']([^"']+)["']''',
  ).firstMatch(source);
  return match?.group(1);
}

int _stableId(String path) {
  var hash = 0x811c9dc5;
  for (final unit in path.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
