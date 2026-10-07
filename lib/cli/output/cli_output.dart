import 'dart:convert';
import 'dart:io';

/// Output modes supported by the Watchtower CLI.
enum CliOutputFormat { human, json, ndjson }

/// Central sink for every CLI write. Commands never call `print` directly so
/// the `--json` / `--quiet` contract stays consistent across the whole surface
/// (the same way the app routes everything through AppLogger).
class CliOutput {
  CliOutput({
    this.format = CliOutputFormat.human,
    this.quiet = false,
    IOSink? out,
    IOSink? err,
  }) : _out = out ?? stdout,
       _err = err ?? stderr;

  final CliOutputFormat format;
  final bool quiet;
  final IOSink _out;
  final IOSink _err;

  bool get isJson => format != CliOutputFormat.human;

  /// Emits a structured result. In JSON mode the value is serialised as a
  /// single JSON document; in human mode a readable rendering is used.
  void result(Object? value, {String? title}) {
    if (quiet && !isJson) return;
    if (isJson) {
      _out.writeln(jsonEncode(value));
      return;
    }
    if (title != null) _out.writeln(title);
    _out.writeln(renderHuman(value));
  }

  /// Streams one record at a time (NDJSON), used for long-running operations
  /// such as downloads so a caller can follow progress line by line.
  void event(Object? value) {
    if (quiet && !isJson) return;
    if (isJson) {
      _out.writeln(jsonEncode(value));
      return;
    }
    _out.writeln(renderHuman(value));
  }

  void info(String message) {
    if (quiet) return;
    if (isJson) return;
    _out.writeln(message);
  }

  void warn(String message) {
    _err.writeln(message);
  }

  void error(String message) {
    if (isJson) {
      _err.writeln(jsonEncode({'error': message}));
      return;
    }
    _err.writeln('error: $message');
  }

  Future<void> flush() async {
    await _out.flush();
    await _err.flush();
  }
}

/// Renders an arbitrary value as stable, readable text for a terminal.
String renderHuman(Object? value, {int indent = 0}) {
  final pad = '  ' * indent;
  if (value == null) return '$pad(null)';
  if (value is String) return '$pad$value';
  if (value is num || value is bool) return '$pad$value';
  if (value is Map) {
    if (value.isEmpty) return '$pad{}';
    final buffer = StringBuffer();
    value.forEach((key, entry) {
      if (entry is Map || entry is Iterable) {
        buffer.writeln('$pad$key:');
        buffer.write(renderHuman(entry, indent: indent + 1));
      } else {
        buffer.writeln('$pad$key: ${renderScalar(entry)}');
      }
    });
    return buffer.toString().trimRight();
  }
  if (value is Iterable) {
    if (value.isEmpty) return '$pad[]';
    final buffer = StringBuffer();
    var index = 0;
    for (final entry in value) {
      buffer.writeln('$pad- [${index++}]');
      buffer.write(renderHuman(entry, indent: indent + 1));
    }
    return buffer.toString().trimRight();
  }
  return '$pad$value';
}

String renderScalar(Object? value) {
  if (value == null) return 'null';
  if (value is String) {
    final flat = value.replaceAll('\n', '\\n');
    return flat.length > 200 ? '${flat.substring(0, 197)}...' : flat;
  }
  return '$value';
}

/// Table rendering for list-oriented commands in human mode.
String renderTable(List<String> headers, List<List<Object?>> rows) {
  final widths = List<int>.generate(headers.length, (i) => headers[i].length);
  for (final row in rows) {
    for (var i = 0; i < headers.length; i++) {
      final cell = renderScalar(i < row.length ? row[i] : '').length;
      if (cell > widths[i]) widths[i] = cell;
    }
  }
  final buffer = StringBuffer();
  buffer.writeln(_tableRow(headers, widths));
  buffer.writeln(widths.map((w) => '-' * w).join('  '));
  for (final row in rows) {
    buffer.writeln(_tableRow(row, widths));
  }
  return buffer.toString().trimRight();
}

String _tableRow(List<Object?> cells, List<int> widths) {
  final parts = <String>[];
  for (var i = 0; i < widths.length; i++) {
    final text = renderScalar(i < cells.length ? cells[i] : '');
    parts.add(text.padRight(widths[i]));
  }
  return parts.join('  ');
}
