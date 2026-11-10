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

/// Upper bound for a trusted manga chapter page count.
///
/// Real chapters stay far below this (a few hundred pages at most). A value
/// above it means a byte count or a stale counter leaked into the page
/// denominator — a manga row once stored `succeeded/total` in bytes, so a
/// single downloaded page could surface as "1/1048576 pages" (a million).
const int maxTrustedMangaPages = 10000;

/// Returns [value] when it can be a real chapter page count, otherwise null.
///
/// Callers use the null to drop the bogus denominator and fall back to a live
/// count (or to an indeterminate bar) instead of printing an impossible total.
int? trustedMangaPageCount(int? value) {
  if (value == null || value < 0 || value > maxTrustedMangaPages) return null;
  return value;
}
