/// Pure helpers for the ZeusDL runtime: the stdout protocol and the exact
/// process invocation used to run a plugin script.
///
/// Watchtower streams the Python script's stdout and understands four
/// structured prefixes (see `docs/extensions_system.md` §4):
///
/// ```
/// PROGRESS:42           progress percentage (0–100)
/// STATUS:Downloading…   status text
/// DONE:/path/file.mp4   completion + produced file path
/// ERROR:message         failure message
/// ```
///
/// Anything else is a plain log line. Keeping this logic pure (no dart:io, no
/// Flutter) lets it be unit-tested without a device, exactly like
/// [FfmpegHlsEngine.buildArguments].
library;

/// The kind of a single line emitted by a ZeusDL script.
enum ZeusEventType { progress, status, done, error, log }

/// One parsed stdout line.
class ZeusEvent {
  final ZeusEventType type;

  /// The payload after the prefix. For [ZeusEventType.progress] this is the
  /// raw numeric string; for the others it is the text (or file path).
  final String payload;

  /// Convenience accessor: the parsed percentage for [ZeusEventType.progress],
  /// clamped to 0–100. Null for every other event type.
  final int? percent;

  const ZeusEvent(this.type, this.payload, {this.percent});

  @override
  String toString() => 'ZeusEvent(${type.name}: $payload)';
}

/// Parses ZeusDL stdout lines.
abstract final class ZeusProtocol {
  /// Parses a single raw line. Returns null for blank lines.
  static ZeusEvent? parseLine(String rawLine) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) return null;

    if (line.startsWith('PROGRESS:')) {
      final value = int.tryParse(line.substring('PROGRESS:'.length).trim());
      return ZeusEvent(
        ZeusEventType.progress,
        line.substring('PROGRESS:'.length).trim(),
        percent: (value ?? 0).clamp(0, 100),
      );
    }
    if (line.startsWith('STATUS:')) {
      return ZeusEvent(ZeusEventType.status, line.substring('STATUS:'.length));
    }
    if (line.startsWith('DONE:')) {
      return ZeusEvent(ZeusEventType.done, line.substring('DONE:'.length).trim());
    }
    if (line.startsWith('ERROR:')) {
      return ZeusEvent(ZeusEventType.error, line.substring('ERROR:'.length));
    }
    return ZeusEvent(ZeusEventType.log, line);
  }
}

/// Inputs collected by a plugin's native UI schema and forwarded to the script
/// as named arguments (`--url`, `--quality`, `--no_watermark`, …).
class ZeusParams {
  final String url;
  final String? quality;

  /// When true, `--no_watermark` is passed. Only meaningful for platforms that
  /// stamp a watermark (TikTok); ignored otherwise.
  final bool noWatermark;

  /// When true, `--audio_only` is passed so the script extracts the audio track.
  final bool audioOnly;

  /// Any additional free-form inputs, forwarded as `--<key> <value>`.
  final Map<String, String> extra;

  const ZeusParams({
    required this.url,
    this.quality,
    this.noWatermark = true,
    this.audioOnly = false,
    this.extra = const {},
  });
}

/// Builds the argv and environment for a ZeusDL script run.
abstract final class ZeusInvocation {
  /// The script path is always the first argument; the remaining flags mirror
  /// the schema input ids so a plugin author can read them with argparse.
  static List<String> buildArguments({
    required String scriptPath,
    required ZeusParams params,
  }) {
    final args = <String>[scriptPath, '--url', params.url];
    final quality = params.quality;
    if (quality != null && quality.isNotEmpty) {
      args.addAll(['--quality', quality]);
    }
    if (params.noWatermark) args.add('--no_watermark');
    if (params.audioOnly) args.add('--audio_only');
    for (final entry in params.extra.entries) {
      if (entry.value.isEmpty) continue;
      args.addAll(['--${entry.key}', entry.value]);
    }
    return args;
  }

  /// Environment variables injected by Watchtower, per the plugin contract.
  static Map<String, String> buildEnvironment({
    required String pluginId,
    required String downloadDir,
    required String cacheDir,
    required String action,
    String? runtimeDir,
    Map<String, String>? extra,
  }) {
    return {
      'WT_PLUGIN_ID': pluginId,
      'WT_DOWNLOAD_DIR': downloadDir,
      'WT_ZEUS_CACHE': cacheDir,
      'WT_ACTION': action,
      // The plugin script imports the zeusdl libraries from the runtime dir;
      // put it on PYTHONPATH so `import zeusdl` resolves without installation.
      if (runtimeDir != null && runtimeDir.isNotEmpty) 'PYTHONPATH': runtimeDir,
      ...?extra,
    };
  }
}
