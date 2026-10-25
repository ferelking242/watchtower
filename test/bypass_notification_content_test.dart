import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_content.dart';

/// The notification used to count *requests*: one extension firing ten parallel
/// calls announced “10 sources bloquées”, which is both wrong and useless. It
/// must name the blocked extensions instead.
void main() {
  group('Bypass notification content', () {
    test('one blocked extension is named, not counted', () {
      final content = buildBypassNotificationContent(const [
        BlockedSourceAlert(
          name: 'MissAV',
          url: 'https://missav.ws/en/new?sort=views',
          sourceId: 1900000218,
        ),
      ]);

      expect(content.title, contains('MissAV'));
      expect(content.title, contains('Cloudflare'));
      expect(
        content.title,
        isNot(matches(RegExp(r'\d+ (sources?|extensions?)'))),
      );
      expect(content.body, contains('Battre le challenge'));
      expect(content.primary.url, 'https://missav.ws/en/new?sort=views');
    });

    test('ten refused requests from one extension stay one extension', () {
      final alerts = [
        for (var i = 0; i < 10; i++)
          BlockedSourceAlert(
            name: 'MissAV',
            url: 'https://missav.ws/en/list/$i',
            sourceId: 1900000218,
          ),
      ];

      final content = buildBypassNotificationContent(alerts);

      expect(content.alerts, hasLength(1));
      expect(content.title, isNot(contains('10')));
      expect(content.title, contains('MissAV'));
    });

    test('three extensions are counted and named', () {
      final content = buildBypassNotificationContent(const [
        BlockedSourceAlert(
          name: 'MissAV',
          url: 'https://missav.ws/a',
          sourceId: 1,
        ),
        BlockedSourceAlert(
          name: 'XNXX',
          url: 'https://xnxx.com/a',
          sourceId: 2,
        ),
        BlockedSourceAlert(
          name: 'JAVMost',
          url: 'https://javmost.com/a',
          sourceId: 3,
        ),
      ]);

      expect(content.title, contains('3'));
      expect(content.body, contains('MissAV'));
      expect(content.body, contains('XNXX'));
      expect(content.body, contains('JAVMost'));
      expect(content.primary.name, 'MissAV');
    });

    test('more than three extensions are truncated in the body', () {
      final content = buildBypassNotificationContent([
        for (var i = 0; i < 6; i++)
          BlockedSourceAlert(
            name: 'Source $i',
            url: 'https://host$i.test/page',
            sourceId: i,
          ),
      ]);

      expect(content.alerts, hasLength(6));
      expect(content.body, contains('Source 0, Source 1, Source 2'));
      expect(content.body, contains('…'));
      expect(content.body, isNot(contains('Source 3')));
    });

    test('an empty batch is rejected instead of notifying nonsense', () {
      expect(
        () => buildBypassNotificationContent(const []),
        throwsArgumentError,
      );
    });
  });
}
