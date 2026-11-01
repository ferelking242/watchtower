import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/http/extension_session_manager.dart';

void main() {
  test('malformed cookie paths do not break extension image requests', () {
    const extensionId = 987654321;
    ExtensionSessionManager.installWorkerSnapshot(extensionId, {
      'cookies': [
        {
          'name': 'session',
          'value': 'present',
          'domain': 'images.example',
          'hostOnly': true,
          'path': ['/'],
          'secure': true,
        },
      ],
    });

    expect(
      ExtensionSessionManager.cookieHeaderForUrl(
        extensionId,
        'https://images.example/cover.jpg',
      ),
      'session=present',
    );
  });
}
