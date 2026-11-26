import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Records the launch phase the app is currently in, on disk.
///
/// A native abort (Scudo reporting a corrupted chunk header, a SIGSEGV inside
/// a codec) kills the process without running a single Dart handler: the
/// session log stops mid-line and the tombstone has no app-side context, so
/// "it crashes at startup" cannot be attributed to a step. The phase written
/// here is flushed before the step runs, survives the abort, and is reported
/// by the next launch.
class StartupBreadcrumb {
  StartupBreadcrumb._();

  static const String cleanPhase = 'ready';
  static const String _fileName = 'startup_phase.txt';

  static File? _file;
  static String? _lastMarked;

  static Future<File?> _resolve() async {
    final cached = _file;
    if (cached != null) return cached;
    try {
      final directory = await getApplicationSupportDirectory();
      return _file = File(p.join(directory.path, _fileName));
    } catch (_) {
      return null;
    }
  }

  /// Writes [phase] and flushes it, so the record is on disk before the step
  /// it describes starts. Repeated marks of the same phase are no-ops.
  static Future<void> mark(String phase) async {
    if (_lastMarked == phase) return;
    _lastMarked = phase;
    final file = await _resolve();
    if (file == null) return;
    try {
      await file.writeAsString(
        '$phase\n${DateTime.now().toIso8601String()}',
        flush: true,
      );
    } catch (_) {
      // A read-only or full volume must never break the launch it instruments.
    }
  }

  /// Returns the phase a previous launch died in and clears the record.
  ///
  /// `null` when the previous launch reached [cleanPhase] (or wrote nothing).
  static Future<String?> takeUncleanPhase() async {
    final file = await _resolve();
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      await file.delete();
      final phase = text.split('\n').first.trim();
      if (phase.isEmpty || phase == cleanPhase) return null;
      return phase;
    } catch (_) {
      return null;
    }
  }
}
