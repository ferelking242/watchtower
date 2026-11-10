import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/engines/download_engine.dart';
import 'package:watchtower/services/download_manager/m3u8/models/download.dart';
import 'package:watchtower/utils/log/logger.dart';

/// HLS download performed by FFmpeg's own HTTP stack.
///
/// Some media CDNs (MissAV's Surrit, most visibly) answer the app's native
/// Dart/Rust clients with a Cloudflare block while the very same URL plays in
/// the bundled player: both go through FFmpeg's libavformat, whose TLS/HTTP
/// fingerprint the CDN accepts. The segment-by-segment isolate downloader and
/// the in-page browser replay both dead-end there, so this engine hands the
/// whole playlist to FFmpeg — it fetches the playlist and every segment with
/// the headers the extension attached, remuxes to MP4 and writes the file.
///
/// Generic by construction: any source whose stream FFmpeg can open benefits,
/// with no per-source branch. It is also self-tuning — the caller only reaches
/// it after the isolate downloader (and its browser replay) have failed, so it
/// costs a normal source nothing.
class FfmpegHlsEngine implements DownloadEngine {
  FfmpegHlsEngine({
    required this.url,
    required this.outputPath,
    required this.headers,
    required this.itemType,
    required this.chapterId,
    this.totalTimeout = const Duration(minutes: 60),
  });

  final String url;
  final String outputPath;
  final Map<String, String> headers;
  final ItemType itemType;
  final String chapterId;

  /// Hard ceiling so a stalled CDN cannot pin the queue forever; FFmpeg's own
  /// `-rw_timeout` handles the common "no bytes for a while" case first.
  final Duration totalTimeout;

  FFmpegSession? _session;
  bool _cancelled = false;

  @override
  String get engineId => 'ffmpeg';

  @override
  String get engineName => 'FFmpeg';

  @override
  bool get supportsPause => false;

  @override
  Future<void> start(void Function(DownloadProgress) onProgress) async {
    final partFile = File('$outputPath.part');
    await _deleteQuietly(partFile);

    final completer = Completer<void>();
    final arguments = buildArguments(
      url: url,
      outputPath: outputPath,
      headers: headers,
    );
    AppLogger.log(
      '[FfmpegHlsEngine][ch:$chapterId] start origin=${_safeOrigin(url)}',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );

    _session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) {
        if (!completer.isCompleted) completer.complete();
      },
      null,
      (statistics) {
        if (_cancelled) return;
        onProgress(
          DownloadProgress(
            0,
            0,
            itemType,
            downloadedBytes: statistics.getSize(),
            isIndeterminate: true,
          ),
        );
      },
    );

    try {
      await completer.future.timeout(totalTimeout);
    } on TimeoutException {
      await cancel();
      throw DownloadEngineException(
        'FFmpeg HLS download timed out after ${totalTimeout.inMinutes} min',
      );
    }

    if (_cancelled) {
      await _deleteQuietly(partFile);
      throw DownloadEngineException('FFmpeg HLS download cancelled');
    }

    final returnCode = await _session!.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await _session!.getOutput();
      await _deleteQuietly(partFile);
      throw DownloadEngineException(
        'FFmpeg HLS download failed (exit ${returnCode?.getValue()})'
        '${_lastLogLine(output)}',
      );
    }

    // FFmpeg targets `<output>.part` so a crash cannot leave a truncated file
    // in place of the final download; promote it only when it holds bytes.
    if (await partFile.length() <= 0) {
      await _deleteQuietly(partFile);
      throw DownloadEngineException('FFmpeg HLS download produced an empty file');
    }
    final outFile = File(outputPath);
    await _deleteQuietly(outFile);
    await partFile.rename(outputPath);

    AppLogger.log(
      '[FfmpegHlsEngine][ch:$chapterId] completed',
      logLevel: LogLevel.info,
      tag: LogTag.download,
    );
    onProgress(DownloadProgress(1, 1, itemType, isCompleted: true));
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final session = _session;
    if (session != null) {
      try {
        await FFmpegKit.cancel(session.getSessionId());
      } catch (_) {}
    }
  }

  /// Builds the FFmpeg argument list for a stream-copy HLS→MP4 download.
  ///
  /// `-headers`/`-user_agent`/`-referer` are forwarded by the HLS demuxer to
  /// every segment request, not just the playlist, which is what the CDN
  /// checks. `-f mp4` is explicit because the output is a `.part` file whose
  /// extension matches no muxer.
  static List<String> buildArguments({
    required String url,
    required String outputPath,
    required Map<String, String> headers,
  }) {
    final userAgent = _userAgentOf(headers);
    final referer = _valueOf(headers, 'referer');
    return [
      '-hide_banner',
      '-loglevel',
      'warning',
      if (userAgent != null) ...['-user_agent', userAgent],
      if (referer != null) ...['-referer', referer],
      if (_headerBlock(headers).isNotEmpty) ...['-headers', _headerBlock(headers)],
      // Abort instead of hanging when the CDN stalls (microseconds).
      '-rw_timeout',
      '60000000',
      '-i',
      url,
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      '-f',
      'mp4',
      '-y',
      '$outputPath.part',
    ];
  }

  /// Headers handed to FFmpeg as one CRLF-separated block.
  ///
  /// `User-Agent` and `Referer` are owned by the `-user_agent`/`-referer`
  /// options, and `Host`/`Connection`/`Content-Length`/`Accept-Encoding` by the
  /// transport, so those are dropped here to avoid a duplicated or conflicting
  /// value. Everything else the extension attached — `Origin`, `Cookie`,
  /// `Authorization`, `Accept*`, `Sec-Fetch-*` — is kept verbatim, because the
  /// CDN checks them.
  static String _headerBlock(Map<String, String> headers) {
    const forbidden = {
      'user-agent',
      'referer',
      'host',
      'connection',
      'content-length',
      'accept-encoding',
    };
    final lines = <String>[];
    headers.forEach((name, value) {
      final key = name.trim();
      if (key.isEmpty || value.isEmpty) return;
      if (forbidden.contains(key.toLowerCase())) return;
      if (key.contains('\n') || key.contains('\r')) return;
      if (value.contains('\n') || value.contains('\r')) return;
      lines.add('$key: $value');
    });
    return lines.join('\r\n');
  }

  static String? _userAgentOf(Map<String, String> headers) =>
      _valueOf(headers, 'user-agent');

  static String? _valueOf(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return null;
  }

  static String _safeOrigin(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? url : '${uri.scheme}://${uri.host}';
  }

  static String _lastLogLine(String? output) {
    final text = output?.trim() ?? '';
    if (text.isEmpty) return '';
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isEmpty ? '' : ': ${lines.last.trim()}';
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
