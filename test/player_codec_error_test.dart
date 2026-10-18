import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/player_codec_error.dart';

void main() {
  group('isCodecError', () {
    test('recognises the failure the pre-playback probe fixes', () {
      expect(isCodecError('Could not open codec.'), isTrue);
      expect(
        isCodecError('Failed to initialize a decoder for codec \'h264\'.'),
        isTrue,
      );
      expect(isCodecError('Could not find codec parameters'), isTrue);
      expect(isCodecError('codec not found'), isTrue);
      expect(isCodecError('Failed to open codec'), isTrue);
      expect(isCodecError('No video or audio streams selected'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isCodecError('COULD NOT OPEN CODEC'), isTrue);
      expect(isCodecError('could not open codec'), isTrue);
    });

    test('does not fire on network, DRM or expiry failures', () {
      // Restoring the probe would only add latency to these.
      expect(
        isCodecError('Failed to open https://cdn.example/x.m3u8'),
        isFalse,
      );
      expect(isCodecError('HTTP error 403 Forbidden'), isFalse);
      expect(isCodecError('Connection timed out'), isFalse);
      expect(isCodecError('Invalid URL'), isFalse);
      expect(isCodecError('DRM protected'), isFalse);
      expect(
        isCodecError('This stream is not available in your region'),
        isFalse,
      );
    });

    test('handles a missing error', () {
      expect(isCodecError(null), isFalse);
      expect(isCodecError(''), isFalse);
    });
  });
}
