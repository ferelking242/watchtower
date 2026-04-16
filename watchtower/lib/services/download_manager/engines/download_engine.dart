import 'package:watchtower/services/download_manager/m3u8/models/download.dart';

/// Unified interface for all download engines.
/// MDownloader (internal/FK) and ZeusDL both implement this.
abstract class DownloadEngine {
  /// Engine identifier shown in UI badges
  String get engineId;

  /// Human-readable engine name
  String get engineName;

  /// Start the download. Calls [onProgress] repeatedly.
  /// Throws [DownloadEngineException] on unrecoverable failure.
  Future<void> start(void Function(DownloadProgress) onProgress);

  /// Pause an in-progress download (if supported).
  Future<void> pause();

  /// Resume a paused download (if supported).
  Future<void> resume();

  /// Cancel and clean up the download.
  Future<void> cancel();

  /// Whether this engine supports pause/resume.
  bool get supportsPause;
}

class DownloadEngineException implements Exception {
  final String message;
  final dynamic originalError;
  final bool isRetryable;

  DownloadEngineException(
    this.message, [
    this.originalError,
    this.isRetryable = false,
  ]);

  @override
  String toString() =>
      'DownloadEngineException: $message${originalError != null ? ' ($originalError)' : ''}';
}
