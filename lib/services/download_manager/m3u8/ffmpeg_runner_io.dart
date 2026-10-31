import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:watchtower/services/download_manager/m3u8/ffmpeg_run_result.dart';

/// Runs FFmpeg through the native library bundled in the application.
///
/// Android, iOS, macOS, Linux and Windows all ship the FFmpegKit native
/// libraries with the build, so no standalone `ffmpeg` executable and no
/// runtime download is involved. The arguments are passed as a list, not a
/// shell string, so a path containing spaces or quotes can never be re-split.
Future<FfmpegRunResult> runFfmpeg(List<String> arguments) async {
  final session = await FFmpegKit.executeWithArguments(arguments);
  return _toResult(session);
}

Future<FfmpegRunResult> _toResult(FFmpegSession session) async {
  final returnCode = await session.getReturnCode();
  final output = await session.getOutput() ?? '';
  return FfmpegRunResult(
    exitCode: returnCode?.getValue() ?? -1,
    output: ReturnCode.isSuccess(returnCode) ? '' : output.trim(),
  );
}
