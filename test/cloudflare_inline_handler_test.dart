import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_bus.dart';

void main() {
  setUp(() => CloudflareChallengeBus.instance.reset());
  tearDown(() => CloudflareChallengeBus.instance.reset());

  test('an on-screen panel claims the challenge instead of a navigation', () {
    final bus = CloudflareChallengeBus.instance;
    CloudflareChallenge seen = const CloudflareChallenge(url: '');

    bus.inlineHandler = (challenge) {
      seen = challenge;
      return true;
    };

    bus.publish('https://surrit.com/abc/playlist.m3u8', sourceId: 7);
    final challenge = bus.challenge.value!;
    expect(bus.tryShowInline(challenge), isTrue);
    expect(seen.url, 'https://surrit.com/abc/playlist.m3u8');
    expect(seen.sourceId, 7);
  });

  test('a handler that cannot show it lets the caller navigate', () {
    final bus = CloudflareChallengeBus.instance;
    bus.inlineHandler = (_) => false;

    expect(
      bus.tryShowInline(const CloudflareChallenge(url: 'https://missav.ws/')),
      isFalse,
    );
  });

  test('no handler registered never throws', () {
    expect(
      CloudflareChallengeBus.instance
          .tryShowInline(const CloudflareChallenge(url: 'https://missav.ws/')),
      isFalse,
    );
  });

  test('a throwing handler falls back instead of breaking the action', () {
    final bus = CloudflareChallengeBus.instance;
    bus.inlineHandler = (_) => throw StateError('disposed mid-frame');

    expect(
      bus.tryShowInline(const CloudflareChallenge(url: 'https://missav.ws/')),
      isFalse,
    );
  });
}
