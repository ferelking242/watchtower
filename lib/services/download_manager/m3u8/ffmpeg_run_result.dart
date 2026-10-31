/// Outcome of one FFmpeg execution.
///
/// Shared by every platform implementation of the FFmpeg runner so the merge
/// service never depends on a platform-specific session type.
class FfmpegRunResult {
  /// FFmpeg return code. `0` means success.
  final int exitCode;

  /// Combined FFmpeg log output, used to explain a failure to the user.
  final String output;

  const FfmpegRunResult({required this.exitCode, required this.output});

  bool get isSuccess => exitCode == 0;
}
