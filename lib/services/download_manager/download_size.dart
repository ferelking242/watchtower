/// Upper bound for a trusted single-file download size.
///
/// This is deliberately far above any expected episode or page download, but
/// keeps malformed HTTP headers and corrupted persisted counters from
/// producing impossible progress values or arithmetic overflows.
const int maxTrustedDownloadBytes = 1024 * 1024 * 1024 * 1024;

int? trustedDownloadByteCount(int? value, {bool allowZero = false}) {
  if (value == null ||
      value < (allowZero ? 0 : 1) ||
      value > maxTrustedDownloadBytes) {
    return null;
  }
  return value;
}

int? trustedDownloadBytesFromKilobytes(
  int? value, {
  bool allowZero = true,
}) {
  if (value == null ||
      value < (allowZero ? 0 : 1) ||
      value > maxTrustedDownloadBytes ~/ 1024) {
    return null;
  }
  return value * 1024;
}