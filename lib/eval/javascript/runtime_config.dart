/// Resource limits applied to one JavaScript extension runtime.
///
/// These values protect the host from a broken or unexpectedly large
/// extension without changing the extension API. The Web runtime accepts the
/// same factory arguments but cannot enforce native QuickJS limits.
abstract final class JsRuntimeConfig {
  static const stackSizeBytes = 2 * 1024 * 1024;
  static const memoryLimitBytes = 64 * 1024 * 1024;
  static const gcThresholdBytes = 8 * 1024 * 1024;

  /// Maximum synchronous JavaScript execution time for one engine call.
  static const executionTimeoutMs = 15000;
}