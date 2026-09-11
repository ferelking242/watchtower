import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

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
      final session = await FFmpegKit.executeWithArguments([
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
      ]);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        throw FfmpegMergeException(
          'FFmpeg merge failed (return code $returnCode)'
          '${output == null || output.trim().isEmpty ? '' : ': $output'}',
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