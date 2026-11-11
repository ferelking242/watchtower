class TsInfo {
  final String name;
  final String url;
  /// MPEG-4 HLS playlists have an initialization fragment that must be
  /// concatenated before the media fragments. It must not be AES-decrypted
  /// with the media sequence number.
  final bool isInitialization;

  /// Duration declared by the segment's `#EXTINF`, in milliseconds. Zero when
  /// the playlist omits it (the fMP4 initialization fragment never has one).
  /// It is what lets a partially-downloaded episode be played back on the real
  /// timeline instead of a compressed one.
  final int durationMs;

  TsInfo(
    this.name,
    this.url, {
    this.isInitialization = false,
    this.durationMs = 0,
  });

  @override
  String toString() =>
      'TsInfo(name: $name, url: $url, isInitialization: $isInitialization, '
      'durationMs: $durationMs)';
}
