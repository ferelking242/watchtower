import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel/features/feed/feed_screen.dart';
import 'package:reel/app.dart';
import 'package:reel/core/contract/ui_contract.dart';
import 'package:reel/core/host/reel_host.dart';
import 'package:reel/remote/reel_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the in-process transport: same paths, canned payloads.
class _FakeTransport implements ReelTransport {
  _FakeTransport(this.calls);

  final List<String> calls;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    calls.add(path);
    if (path == '/api/sources') {
      return {
        'sources': [
          {'id': 7, 'name': 'RedGIFs'},
        ],
      };
    }
    if (path.endsWith('/popular') || path.endsWith('/latest')) {
      return {'mangas': <dynamic>[], 'hasNextPage': false};
    }
    return <String, dynamic>{};
  }

  @override
  void close() {}
}

void main() {
  testWidgets('mounts the Reel shell on a host transport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calls = <String>[];
    await tester.pumpWidget(
      ReelHostedApp(
        host: ReelHost(
          sourceId: '7',
          sourceName: 'RedGIFs',
          transport: _FakeTransport(calls),
          contract: UiContract.fromJson({
            'schemaVersion': 1,
            'renderer': 'reel',
            'capabilities': {
              'live': true,
              'likes': false,
              'comments': false,
              'shares': false,
              'download': false,
            },
          }),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // The shell owns the screen, not Watchtower's own home.
    expect(find.byType(FeedScreen), findsOneWidget);
    // And it talks to the host transport, scoped to the mounted extension.
    expect(calls, contains('/api/sources'));
    expect(
      calls.any((c) => c.startsWith('/api/sources/7/')),
      isTrue,
      reason: 'the feed must query the mounted extension: $calls',
    );
  });
}
