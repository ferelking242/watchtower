import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/challenge_inbox.dart';

void main() {
  setUp(() => ChallengeInbox.instance.reset());
  tearDown(() => ChallengeInbox.instance.reset());

  test('forUrl matches the exact watched URL', () {
    final inbox = ChallengeInbox.instance;
    inbox.watch(chapterId: 683, url: 'https://missav.ws/en/mida-517');

    expect(inbox.forUrl('https://missav.ws/en/mida-517')?.chapterId, 683);
    expect(inbox.forUrl('https://missav.ws/en/other'), isNull);
  });

  test('forUrl falls back to host + path when the query string differs', () {
    final inbox = ChallengeInbox.instance;
    inbox.watch(
      chapterId: 42,
      url: 'https://surrit.com/abc/playlist.m3u8',
    );

    expect(
      inbox.forUrl('https://surrit.com/abc/playlist.m3u8?token=xyz')?.chapterId,
      42,
    );
  });

  test('forChapter returns the most recent refusal for a chapter', () {
    final inbox = ChallengeInbox.instance;
    inbox.watch(chapterId: 1, url: 'https://a.example/page');
    inbox.watch(chapterId: 1, url: 'https://cdn.example/playlist.m3u8');

    expect(inbox.forChapter(1)?.url, 'https://cdn.example/playlist.m3u8');
    expect(inbox.forChapter(2), isNull);
  });

  test('record queues a focus target that takeTarget consumes once', () {
    final inbox = ChallengeInbox.instance;
    inbox.record(chapterId: 7, url: 'https://a.example/page');

    expect(inbox.target.value?.chapterId, 7);
    expect(inbox.takeTarget()?.chapterId, 7);
    expect(inbox.takeTarget(), isNull);
  });

  test('the map is bounded, evicting the oldest URLs first', () {
    final inbox = ChallengeInbox.instance;
    for (var i = 0; i < 60; i++) {
      inbox.watch(chapterId: i, url: 'https://a.example/page-$i');
    }

    expect(inbox.forUrl('https://a.example/page-0'), isNull);
    expect(inbox.forUrl('https://a.example/page-59')?.chapterId, 59);
  });

  test('blank URLs are ignored', () {
    final inbox = ChallengeInbox.instance;
    inbox.watch(chapterId: 3, url: '   ');
    expect(inbox.forUrl(''), isNull);
    expect(inbox.forChapter(3), isNull);
  });
}
