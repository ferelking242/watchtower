import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/http/m_client.dart';

void main() {
  tearDown(MClient.clearWorkerSettingsSnapshot);

  test('extension worker sends scoped cookies and the configured user agent', () {
    MClient.installWorkerSettingsSnapshot({
      'cookies': [
        {
          'host': '.imhentai.xxx',
          'cookie': 'cf_clearance=clearance-value; session=session-value',
        },
        {'host': 'other.example', 'cookie': 'token=other-value'},
      ],
      'userAgent': 'Watchtower test agent',
    });

    expect(
      MClient.getCookiesPref('https://m.imhentai.xxx/chapter/1'),
      {
        HttpHeaders.cookieHeader:
            'cf_clearance=clearance-value; session=session-value',
      },
    );
    expect(MClient.getCookiesPref('https://unrelated.example/'), isEmpty);
    expect(MClient.userAgentForRequests(), 'Watchtower test agent');
  });

  test(
    'extension worker forwards the exact challenge URL to the UI isolate',
    () async {
      final events = ReceivePort();
      addTearDown(events.close);
      MClient.installWorkerAntiBotEventPort(events.sendPort);

      const failedUrl = 'https://source.example/api/search?page=3';
      expect(MClient.dispatchWorkerCloudflareChallenge(failedUrl), isTrue);

      final event = await events.first.timeout(const Duration(seconds: 1));
      expect(
        event,
        {
          'type': MClient.workerCloudflareChallengeEventType,
          'url': failedUrl,
        },
      );
    },
  );

  test(
    'challenge URL dispatch is unavailable outside an extension worker',
    () {
      MClient.clearWorkerSettingsSnapshot();
      expect(
        MClient.dispatchWorkerCloudflareChallenge(
          'https://source.example/api/search',
        ),
        isFalse,
      );
    },
  );
}
