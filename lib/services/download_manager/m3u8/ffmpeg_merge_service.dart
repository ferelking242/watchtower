import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:watchtower/services/download_manager/m3u8/ffmpeg_binary_manager.dart';

/// The only application-facing boundary for HLS assembly.
///
/// Assembly is a single, deterministic method: join the downloaded fragments
/// in playlist order, then hand the joined stream to FFmpeg for one
/// stream-copy mux into MP4. There is deliberately no second "raw
/// concatenation" path — a silent fallback is what let a corrupt file reach
/// the user in the first place.
class FfmpegMergeService {
  FfmpegMergeService._();

  /// Joins [segmentPaths] in order and muxes them into an MP4 at [outputFile].
  ///
  /// Step 1 concatenates the fragments byte-for-byte. MPEG-TS fragments are
  /// defined to be joined this way, and a fragmented-MP4/CMAF playlist (its
  /// initialization fragment first) concatenates into a valid fragmented MP4
  /// stream. Concatenating *before* FFmpeg is what makes one mux pass correct
  /// for both containers: FFmpeg's `concat` *demuxer* re-probes every input as
  /// its own container, so a bare fMP4 media segment (`moof`/`mdat` without a
  /// `moov`) is rejected, the mux "succeeds" with exit code 0 and writes a
  /// streamless ~260-byte file.
  ///
  /// Step 2 stream-copies the joined file into MP4. `-f mp4` is mandatory: the
  /// caller targets an intermediate `<name>.mp4.part` so a crash cannot leave a
  /// truncated file in place of the final download, and FFmpeg picks the muxer
  /// from the output extension. `.part` matches no format, so without an
  /// explicit `-f mp4` every mux aborts with "Unable to choose an output
  /// format" (exit 234).
  static Future<void> assembleToMp4({
    required String outputFile,
    required List<String> segmentPaths,
  }) async {
    final executable = await FfmpegBinaryManager.instance.resolveExecutable();
    if (executable == null) {
      throw const FfmpegMergeException(
        'FFmpeg n’est pas installé. Installez le runtime FFmpeg vérifié '
        'avant d’assembler une vidéo HLS.',
      );
    }

    final workFile = File('$outputFile.joined');
    try {
      await _concatenate(
        outputFile: workFile.path,
        segmentPaths: segmentPaths,
      );

      final result = await Process.run(
        executable,
        buildMuxArguments(
          inputFile: workFile.path,
          outputFile: outputFile,
        ),
      ).timeout(const Duration(minutes: 10));
      if (result.exitCode != 0) {
        final output = '${result.stdout}\n${result.stderr}'.trim();
        throw FfmpegMergeException(
          'FFmpeg mux failed (exit code ${result.exitCode})'
          '${output.isEmpty ? '' : ': $output'}',
        );
      }
    } finally {
      if (await workFile.exists()) {
        try {
          await workFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Builds the FFmpeg argument list for the final stream-copy mux.
  ///
  /// `-f mp4` is mandatory and must not be removed; see [assembleToMp4].
  @visibleForTesting
  static List<String> buildMuxArguments({
    required String inputFile,
    required String outputFile,
  }) => [
    '-hide_banner',
    '-loglevel',
    'error',
    '-i',
    inputFile,
    '-map',
    '0',
    '-c',
    'copy',
    // Force the MP4 muxer instead of relying on the output extension.
    '-f',
    'mp4',
    '-movflags',
    '+faststart',
    '-y',
    outputFile,
  ];

  static Future<void> _concatenate({
    required String outputFile,
    required List<String> segmentPaths,
  }) async {
    final sink = File(outputFile).openWrite();
    try {
      for (final segmentPath in segmentPaths) {
        await sink.addStream(File(segmentPath).openRead());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}

class FfmpegMergeException implements Exception {
  final String message;

  const FfmpegMergeException(this.message);

  @override
  String toString() => message;
}
