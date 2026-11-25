import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:watchtower/remote/remote_server_service.dart';
import 'package:watchtower/remote/tunnel_service.dart';

void main() {
  group('apiKeyFromRequest', () {
    Request req({
      String url = 'http://localhost:4567/api/sources',
      Map<String, String> headers = const {},
    }) =>
        Request('GET', Uri.parse(url), headers: headers);

    test('reads X-Api-Key, the header the Dart SDK sends', () {
      expect(
        apiKeyFromRequest(req(headers: {'x-api-key': 'SECRET'})),
        'SECRET',
      );
    });

    test('reads Authorization: Bearer, used by the web client', () {
      expect(
        apiKeyFromRequest(req(headers: {'authorization': 'Bearer SECRET'})),
        'SECRET',
      );
    });

    test('reads ?key=, used by images in the browser', () {
      expect(
        apiKeyFromRequest(req(url: 'http://localhost:4567/api/x?key=SECRET')),
        'SECRET',
      );
    });

    test('returns null when no key is presented', () {
      expect(apiKeyFromRequest(req()), isNull);
    });
  });

  group('tunnel URL detection', () {
    test('matches a cloudflared quick tunnel URL', () {
      const line = 'INF |  https://finished-adaptation-coming-bonus.trycloudflare.com  |';
      expect(
        TunnelService.cloudflarePattern.firstMatch(line)?.group(0),
        'https://finished-adaptation-coming-bonus.trycloudflare.com',
      );
    });

    test('matches localhost.run and serveo URLs', () {
      expect(
        TunnelService.sshRelayPattern
            .firstMatch('abc123.lhr.life tunneled with tls termination, '
                'https://abc123.lhr.life')
            ?.group(0),
        'https://abc123.lhr.life',
      );
      expect(
        TunnelService.sshRelayPattern
            .firstMatch('Forwarding HTTP traffic from https://abcd.serveo.net')
            ?.group(0),
        'https://abcd.serveo.net',
      );
    });
  });

  group('TunnelService', () {
    test('uses a custom public URL without spawning a process', () async {
      final service = TunnelService(customUrl: 'https://watchtower.example.com');
      String? url;
      String? provider;
      service.onUrlChanged = (u, p) {
        url = u;
        provider = p;
      };

      await service.start();
      addTearDown(service.stop);

      expect(url, 'https://watchtower.example.com');
      expect(provider, 'custom');
    });
  });
}
