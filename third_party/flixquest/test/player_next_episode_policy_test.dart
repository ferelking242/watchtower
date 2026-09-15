import 'package:flixquest/screens/common/player/player_next_episode_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowNextEpisodeTeaser', () {
    test('uses the IntroDB outro start instead of progress fallback', () {
      expect(
        shouldShowNextEpisodeTeaser(
          progress: .99,
          introDbLookupSettled: true,
          hasIntroDbOutroTiming: true,
          introDbOutroReached: false,
        ),
        isFalse,
      );
      expect(
        shouldShowNextEpisodeTeaser(
          progress: .80,
          introDbLookupSettled: true,
          hasIntroDbOutroTiming: true,
          introDbOutroReached: true,
        ),
        isTrue,
      );
    });

    test('falls back to final five percent when no outro exists', () {
      expect(
        shouldShowNextEpisodeTeaser(
          progress: .94,
          introDbLookupSettled: true,
          hasIntroDbOutroTiming: false,
          introDbOutroReached: false,
        ),
        isFalse,
      );
      expect(
        shouldShowNextEpisodeTeaser(
          progress: .95,
          introDbLookupSettled: true,
          hasIntroDbOutroTiming: false,
          introDbOutroReached: false,
        ),
        isTrue,
      );
    });

    test('waits for IntroDB before applying the progress fallback', () {
      expect(
        shouldShowNextEpisodeTeaser(
          progress: .99,
          introDbLookupSettled: false,
          hasIntroDbOutroTiming: false,
          introDbOutroReached: false,
        ),
        isFalse,
      );
    });
  });
}
