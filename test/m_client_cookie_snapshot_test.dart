import 'dart:io';

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
}