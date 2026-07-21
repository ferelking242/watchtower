import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent bytecode cache for QuickJS extensions.
///
/// On the first load of an extension JS source, the runtime compiles it to
/// QuickJS bytecode. The result is written to
/// `<cacheDir>/quickjs_bytecode/<sha256_of_source>.qbc`.
///
/// On subsequent launches the cached bytecode is loaded directly — no
/// re-parse, no re-compile (saves 5–50 ms per extension at startup).
///
/// The cache key is the SHA-256 of the normalised source string, so updating
/// the extension source automatically invalidates the old entry.
class BytecodeCache {
  static BytecodeCache? _instance;
  static BytecodeCache get instance => _instance ??= BytecodeCache._();
  BytecodeCache._();

  Directory? _cacheDir;

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/quickjs_bytecode');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _key(String source) =>
      sha256.convert(utf8.encode(source)).toString();

  Future<File> _file(String key) async {
    final dir = await _getDir();
    return File('${dir.path}/$key.qbc');
  }

  /// Returns cached bytecode for [source], or null on cache miss.
  Future<Uint8List?> get(String source) async {
    try {
      final f = await _file(_key(source));
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  /// Stores compiled [bytecode] for [source].
  Future<void> put(String source, Uint8List bytecode) async {
    try {
      final f = await _file(_key(source));
      await f.writeAsBytes(bytecode, flush: true);
    } catch (_) {}
  }

  /// Removes the cached bytecode for a specific [source] (e.g. after update).
  Future<void> invalidate(String source) async {
    try {
      final f = await _file(_key(source));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Clears all cached bytecode files.
  Future<void> clear() async {
    try {
      final dir = await _getDir();
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.qbc')) await f.delete();
      }
    } catch (_) {}
  }
}
