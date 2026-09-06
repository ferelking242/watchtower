// Web stub for just_zstd — zstd compression not available on Flutter Web.
// NFile archive_service is never called on web, so throwing UnimplementedError
// is safe (code paths are guarded by kIsWeb or never reached).
import 'dart:typed_data';

class ZstdEncoder {
  const ZstdEncoder();
  Uint8List encodeBytes(Uint8List bytes) =>
      throw UnsupportedError('Zstd not available on Flutter Web');
  List<int> encode(List<int> bytes) =>
      throw UnsupportedError('Zstd not available on Flutter Web');
}

class ZstdDecoder {
  const ZstdDecoder();
  Uint8List decodeBytes(Uint8List bytes) =>
      throw UnsupportedError('Zstd not available on Flutter Web');
  List<int> decode(List<int> bytes) =>
      throw UnsupportedError('Zstd not available on Flutter Web');
}
