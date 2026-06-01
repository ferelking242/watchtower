import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';

/// Handles importing a `.wext` (Watchtower Extension) file.
///
/// A `.wext` file is a self-contained JSON bundle produced by
/// `tools/build_wext.py` in the watchtower-extensions repo:
///
/// ```json
/// {
///   "format": "wext/1.0",
///   "metadata": { ...all Source fields... },
///   "source":   "...JS source code as plain UTF-8 string..."
/// }
/// ```
///
/// Returns a human-readable result message, or null if the user cancelled.
Future<String?> importWextFile(BuildContext context) async {
  FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(
      dialogTitle: 'Import .wext extension',
      type: FileType.custom,
      allowedExtensions: const ['wext'],
      allowMultiple: false,
      withData: false,
    );
  } catch (_) {
    result = await FilePicker.pickFiles(
      dialogTitle: 'Import .wext extension',
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
  }

  if (result == null || result.files.isEmpty) return null;

  final path = result.files.single.path;
  if (path == null || path.isEmpty) {
    return 'Could not read the selected file path.';
  }

  late Map<String, dynamic> bundle;
  try {
    final raw = File(path).readAsStringSync();
    bundle = jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    return 'Invalid .wext file: $e';
  }

  final format = bundle['format'] as String?;
  if (format == null || !format.startsWith('wext/')) {
    return 'Not a valid .wext file (missing "format" field).';
  }

  final meta = bundle['metadata'] as Map<String, dynamic>?;
  final sourceCode = bundle['source'] as String?;
  if (meta == null || sourceCode == null || sourceCode.isEmpty) {
    return 'Malformed .wext file: missing metadata or source.';
  }

  late Source source;
  try {
    source = Source.fromJson(meta);
  } catch (e) {
    return 'Could not parse .wext metadata: $e';
  }

  if (source.id == null || source.id == 0) {
    source.id = 'watchtower-wext-${source.lang}.${source.name}'.hashCode;
  }
  source
    ..sourceCode = sourceCode
    ..isLocal = true
    ..isAdded = true
    ..isActive = true
    ..isObsolete = false;

  final existing = isar.sources.getSync(source.id!);
  if (existing != null) {
    final confirmed = await _confirmReplace(context, source.name ?? 'Unknown');
    if (!confirmed) return null;
  }

  try {
    isar.writeTxnSync(() {
      isar.sources.putSync(
        source..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
    return 'success:${source.name ?? 'Extension'}';
  } catch (e) {
    return 'Failed to save extension: $e';
  }
}

Future<bool> _confirmReplace(BuildContext context, String name) async {
  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Replace extension?'),
      content: Text(
        '"$name" is already installed. Do you want to replace it with the version from this .wext file?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Convenience wrapper: picks a file, imports it, and shows a snack bar.
Future<void> importWextAndNotify(BuildContext context) async {
  final msg = await importWextFile(context);
  if (msg == null) return;
  if (!context.mounted) return;
  if (msg.startsWith('success:')) {
    final name = msg.substring('success:'.length);
    botToast('Extension "$name" installed from .wext file.');
  } else {
    botToast(msg);
  }
}
