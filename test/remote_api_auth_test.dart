// ignore: depend_on_referenced_packages
import 'package:watchtower_client/watchtower_client.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:watchtower/remote/remote_server_service.dart';

/// End-to-end check of the API surface Reel talks to: a real shelf server
/// behind [apiKeyMiddleware], driven by the official `watchtower_client` SDK.
void main() {
  const key = 'ECEAciXeSzD3wBNnk2bM1XgEx6';

  late HttpServer server;
  late String baseUrl;

  setUpAll(() async {
    final router = Router()
      ..get(
        '/api/ping',
        (_) => corsify(Response.ok(jsonEncode({
          'ok': true,
          'status': 'ok',
          'app': 'Watchtower',
          'version': '1.2.3',
        }))),
      )
      ..get(
        '/api/sources',
        (_) => corsify(Response.ok(jsonEncode({
          'sources': [
            {'id': 'redgifs', 'name': 'RedGifs'},
          ],
          'hiddenNsfw': 2,
        }))),
      );

    final pipeline = const Pipeline()
        .addMiddleware(apiKeyMiddleware(() => key))
        .addHandler(router.call);

    server = await shelf_io.serve(pipeline, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.host}:${server.port}';
  });

  tearDownAll(() => server.close(force: true));

  test('the SDK reaches /api/sources with its X-Api-Key header', () async {
    final client = WatchtowerClient(url: baseUrl, apiKey: key, maxRetries: 1);
    addTearDown(client.close);

    final data = await client.getRaw('/api/sources');
    expect(data['hiddenNsfw'], 2);
    expect((data['sources'] as List).length, 1);
  });

  test('a wrong key is refused with 401', () async {
    final client =
        WatchtowerClient(url: baseUrl, apiKey: 'wrong', maxRetries: 1);
    addTearDown(client.close);

    await expectLater(
      client.getRaw('/api/sources'),
      throwsA(isA<WatchtowerApiException>()),
    );
  });

  test('/api/ping stays public and satisfies the SDK contract', () async {
    final client = WatchtowerClient(url: baseUrl, maxRetries: 1);
    addTearDown(client.close);

    expect(await client.ping(), isTrue);
    final raw = await client.getRaw('/api/ping');
    expect(raw['version'], '1.2.3');
  });

  test('responses carry CORS headers for the web client', () async {
    final response = await HttpClient()
        .getUrl(Uri.parse('$baseUrl/api/sources'))
        .then((request) {
      request.headers.set('X-Api-Key', key);
      return request.close();
    });

    expect(response.statusCode, 200);
    expect(response.headers.value('access-control-allow-origin'), '*');
    final allowed = response.headers.value('access-control-allow-headers') ?? '';
    expect(allowed.toLowerCase(), contains('x-api-key'));
    await response.drain<void>();
  });

  test('OPTIONS preflight is answered without a key', () async {
    final response = await HttpClient()
        .openUrl('OPTIONS', Uri.parse('$baseUrl/api/sources'))
        .then((request) => request.close());

    expect(response.statusCode, 200);
    expect(response.headers.value('access-control-allow-headers'), isNotNull);
    await response.drain<void>();
  });
}
