/// Classifies a libmpv error message so the player can tell an error the
/// pre-playback probe can fix from one it cannot.
///
/// The player skips `avformat_find_stream_info()` (`probe-info=nostreams`) to
/// stop ffmpeg fetching every HLS variant in parallel, which is what makes a
/// multi-rendition master slow to start. A few containers only expose their
/// codec parameters through that probe; when one does, the decoder fails with
/// a codec error and the only recovery is to put the probe back. Network, DRM
/// and URL-expiry errors look nothing like that and must not trigger it.
///
/// Pure and dependency-free so it can be unit-tested: the player itself needs
/// media_kit's native libraries, which a plain `flutter test` cannot load.
library;

/// True when [error] describes a decoder/codec failure.
bool isCodecError(String? error) {
  if (error == null || error.isEmpty) return false;
  final e = error.toLowerCase();
  return e.contains('could not open codec') ||
      e.contains('could not find codec') ||
      e.contains('failed to open codec') ||
      e.contains('failed to initialize') ||
      e.contains('codec not found') ||
      e.contains('no video or audio') ||
      e.contains('decoder');
}
