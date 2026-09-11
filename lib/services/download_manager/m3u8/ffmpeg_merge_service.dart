import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:watchtower/services/download_manager/m3u8/ffmpeg_binary_manager.dart';

/// The only application-facing boundary for FFmpeg-backed HLS muxing.
///
/// Keeping the package-specific session API here makes it possible to replace
/// the Android implementation without coupling the downloader to an FFmpeg
/// distribution or its licensing details.
class FfmpegMergeService {
  FfmpegMergeService._();

  static Future<void> mergeTsToMp4({
    required String outputFile,
    required List<String> segmentPaths,
  }) async {
    final concatFile = File('$outputFile.concat.txt');
    await concatFile.writeAsString(
      segmentPaths
          .map((segmentPath) => "file '${_escapeConcatPath(segmentPath)}'")
          .join('\n'),
      flush: true,
    );

    try {
      final executable =
          await FfmpegBinaryManager.instance.resolveExecutable();
      if (executable == null) {
        throw const FfmpegMergeException(
          'FFmpeg n’est pas installé. Installez le runtime FFmpeg vérifié '
          'avant de fusionner des fragments HLS.',
        );
      }
      final result = await Process.run(executable, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatFile.path,
        '-map',
        '0',
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        '-y',
        outputFile,
      ]).timeout(const Duration(minutes: 10));
      if (result.exitCode != 0) {
        final output = '${result.stdout}\n${result.stderr}'.trim();
        throw FfmpegMergeException(
          'FFmpeg merge failed (exit code ${result.exitCode})'
          '${output.isEmpty ? '' : ': $output'}',
        );
      }
    } finally {
      if (await concatFile.exists()) {
        await concatFile.delete();
      }
    }
  }

  static String _escapeConcatPath(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "'\\''");
}

class FfmpegMergeException implements Exception {
  final String message;

  const FfmpegMergeException(this.message);

  @override
  String toString() => message;
}