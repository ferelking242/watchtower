String stableWatchProgressKey(String title) {
  var hash = 0x811c9dc5;
  for (final unit in title.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}