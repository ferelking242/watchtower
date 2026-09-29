class TsInfo {
  final String name;
  final String url;
  /// MPEG-4 HLS playlists have an initialization fragment that must be
  /// concatenated before the media fragments. It must not be AES-decrypted
  /// with the media sequence number.
  final bool isInitialization;

  TsInfo(this.name, this.url, {this.isInitialization = false});

  @override
  String toString() =>
      'TsInfo(name: $name, url: $url, isInitialization: $isInitialization)';
}
