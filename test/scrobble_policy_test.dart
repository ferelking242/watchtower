import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobble_policy.dart';

void main() {
  group('minimumScrobbleSeconds', () {
    test('is half the track for short tracks', () {
      expect(minimumScrobbleSeconds(const Duration(seconds: 200)), 100);
    });

    test('is capped at four minutes for long tracks', () {
      expect(minimumScrobbleSeconds(const Duration(minutes: 10)), 240);
    });

    test('never exceeds the track duration for very short tracks', () {
      expect(minimumScrobbleSeconds(const Duration(seconds: 30)), 15);
    });
  });

  group('scrobbleTrackKey', () {
    test('uses the path for local files', () {
      expect(
        scrobbleTrackKey(id: '/music/a.mp3', isLocal: true, path: '/music/a.mp3'),
        '/music/a.mp3',
      );
    });

    test('uses the provider id for catalogue tracks', () {
      expect(
        scrobbleTrackKey(id: 'abc123', isLocal: false, path: null),
        'abc123',
      );
    });
  });

  group('shouldScrobble', () {
    test('is false before half the track has played', () {
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: const Duration(seconds: 60),
          duration: const Duration(seconds: 200),
        ),
        isFalse,
      );
    });

    test('is true at half the track for short tracks', () {
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: const Duration(seconds: 100),
          duration: const Duration(seconds: 200),
        ),
        isTrue,
      );
    });

    test('waits four minutes for long tracks', () {
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: const Duration(minutes: 3),
          duration: const Duration(minutes: 10),
        ),
        isFalse,
      );
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: const Duration(minutes: 4),
          duration: const Duration(minutes: 10),
        ),
        isTrue,
      );
    });

    test('does not repeat a track already scrobbled', () {
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: 'abc',
          position: const Duration(minutes: 9),
          duration: const Duration(minutes: 10),
        ),
        isFalse,
      );
    });

    test('is false without a track, duration or position', () {
      expect(
        shouldScrobble(
          trackKey: null,
          lastScrobbledKey: null,
          position: const Duration(minutes: 9),
          duration: const Duration(minutes: 10),
        ),
        isFalse,
      );
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: Duration.zero,
          duration: const Duration(minutes: 10),
        ),
        isFalse,
      );
      expect(
        shouldScrobble(
          trackKey: 'abc',
          lastScrobbledKey: null,
          position: const Duration(minutes: 1),
          duration: Duration.zero,
        ),
        isFalse,
      );
    });
  });
}
