import 'package:watchtower/services/download_manager/m3u8/ffmpeg_run_result.dart';

/// Web has no native FFmpeg, so HLS assembly cannot run there.
Future<FfmpegRunResult> runFfmpeg(List<String> arguments) async =>
    throw const FfmpegRunnerUnsupportedException();

class FfmpegRunnerUnsupportedException implements Exception {
  const FfmpegRunnerUnsupportedException();

  @override
  String toString() =>
      'FFmpeg assembly is not available on this platform.';
}
