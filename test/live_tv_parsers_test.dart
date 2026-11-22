import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/live_tv/data/live_defaults.dart';
import 'package:watchtower/modules/live_tv/sources/json_channel_parser.dart';
import 'package:watchtower/modules/live_tv/sources/m3u_parser.dart';
import 'package:watchtower/modules/live_tv/sources/xtream_parser.dart';

void main() {
  group('M3U', () {
    test('reads name, group, logo and url', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="france24.fr" tvg-logo="https://logo/f24.png" group-title="News",France 24
https://stream/f24.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'iptv-pro');

      expect(channels, hasLength(1));
      final channel = channels.single;
      expect(channel.name, 'France 24');
      expect(channel.group, 'News');
      expect(channel.logoUrl, 'https://logo/f24.png');
      expect(channel.primaryUrl, 'https://stream/f24.m3u8');
      expect(channel.id, 'iptv-pro:france24.fr');
    });

    test('a comma inside a quoted attribute does not split the name', () {
      const playlist = '''
#EXTINF:-1 group-title="News, World",BFM TV
https://stream/bfm.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'p');

      expect(channels.single.name, 'BFM TV');
      expect(channels.single.group, 'News, World');
    });

    test('accepts bare attribute values and missing attributes', () {
      const playlist = '''
#EXTINF:-1 tvg-id=arte.fr,Arte
https://stream/arte.m3u8
#EXTINF:-1,Channel Without Attributes
https://stream/plain.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'p');

      expect(channels, hasLength(2));
      expect(channels.first.tvgId, 'arte.fr');
      expect(channels.last.name, 'Channel Without Attributes');
    });

    test('skips a malformed entry but keeps the rest', () {
      const playlist = '''
#EXTINF:-1,Broken
not-a-url
#EXTINF:-1,Good
https://stream/good.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'p');

      expect(channels, hasLength(1));
      expect(channels.single.name, 'Good');
    });

    test('an entry with no url is dropped', () {
      const playlist = '''
#EXTINF:-1,Orphan
#EXTINF:-1,Next
https://stream/next.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'p');

      expect(channels.map((c) => c.name), ['Next']);
    });

    test('same tvg-id becomes one channel with mirror urls', () {
      const playlist = '''
#EXTINF:-1 tvg-id="tf1.fr",TF1
https://a/tf1.m3u8
#EXTINF:-1 tvg-id="tf1.fr",TF1 Backup
https://b/tf1.m3u8
''';
      final channels = M3uParser.parse(playlist, providerId: 'p');

      expect(channels, hasLength(1));
      expect(channels.single.urls, ['https://a/tf1.m3u8', 'https://b/tf1.m3u8']);
    });

    test('the same url listed twice is not duplicated', () {
      const playlist = '''
#EXTINF:-1 tvg-id="x",X
https://a/x.m3u8
#EXTINF:-1 tvg-id="x",X
https://a/x.m3u8
''';
      expect(
        M3uParser.parse(playlist, providerId: 'p').single.urls,
        ['https://a/x.m3u8'],
      );
    });

    test('handles CRLF playlists and blank lines', () {
      const playlist =
          '#EXTM3U\r\n\r\n#EXTINF:-1,A\r\nhttps://a/a.m3u8\r\n\r\n';
      expect(M3uParser.parse(playlist, providerId: 'p'), hasLength(1));
    });

    test('two providers expose the same channel under distinct ids', () {
      const playlist = '''
#EXTINF:-1 tvg-id="cnn.us",CNN
https://a/cnn.m3u8
''';
      final one = M3uParser.parse(playlist, providerId: 'p1').single;
      final two = M3uParser.parse(playlist, providerId: 'p2').single;

      expect(one.id, isNot(two.id));
    });

    test('an empty or header-only playlist yields no channels', () {
      expect(M3uParser.parse('', providerId: 'p'), isEmpty);
      expect(M3uParser.parse('#EXTM3U\n', providerId: 'p'), isEmpty);
    });
  });

  group('Xtream', () {
    test('joins streams to their category name', () {
      final channels = XtreamParser.parse(
        providerId: 'panel',
        categoriesJson: [
          {'category_id': '1', 'category_name': 'Sport'},
        ],
        streamsJson: [
          {
            'num': 1,
            'name': 'Eurosport',
            'stream_id': 42,
            'stream_icon': 'https://logo/euro.png',
            'category_id': '1',
            'epg_channel_id': 'eurosport.fr',
          },
        ],
      );

      expect(channels, hasLength(1));
      expect(channels.single.group, 'Sport');
      expect(channels.single.logoUrl, 'https://logo/euro.png');
      expect(channels.single.id, 'panel:eurosport.fr');
    });

    test('builds the panel url with credentials', () {
      final parsed = XtreamParser.parse(
        providerId: 'panel',
        categoriesJson: const [],
        streamsJson: [
          {'name': 'A', 'stream_id': 7},
        ],
      );
      final resolved = XtreamParser.withResolvedUrls(
        parsed,
        baseUrl: 'http://panel.example:8080/',
        username: 'user',
        password: 'pass',
      );

      expect(
        resolved.single.primaryUrl,
        'http://panel.example:8080/live/user/pass/7.m3u8',
      );
    });

    test('an error object instead of a list yields no channels', () {
      final channels = XtreamParser.parse(
        providerId: 'panel',
        categoriesJson: {'user_info': {'auth': 0}},
        streamsJson: {'user_info': {'auth': 0}},
      );

      expect(channels, isEmpty);
    });

    test('detects an auth failure', () {
      expect(XtreamParser.isAuthFailure({'user_info': {'auth': 0}}), isTrue);
      expect(XtreamParser.isAuthFailure({'status': 'Failed'}), isTrue);
      expect(XtreamParser.isAuthFailure([1, 2]), isFalse);
    });

    test('a stream without an id is dropped', () {
      final channels = XtreamParser.parse(
        providerId: 'p',
        categoriesJson: const [],
        streamsJson: [
          {'name': 'No id'},
          {'name': 'Has id', 'stream_id': 1},
        ],
      );

      expect(channels.map((c) => c.name), ['Has id']);
    });

    test('malformed json decodes to null rather than throwing', () {
      expect(XtreamParser.tryDecode('<html>'), isNull);
    });
  });

  group('JSON channels', () {
    test('reads a bare list', () {
      final channels = JsonChannelParser.parse(
        '[{"name":"A","url":"https://a/a.m3u8","group":"G"}]',
        providerId: 'p',
      );

      expect(channels.single.name, 'A');
      expect(channels.single.group, 'G');
    });

    test('reads a list wrapped under channels/items/data', () {
      for (final key in const ['channels', 'items', 'data']) {
        final channels = JsonChannelParser.parse(
          '{"$key":[{"name":"A","url":"https://a/a.m3u8"}]}',
          providerId: 'p',
        );
        expect(channels, hasLength(1), reason: key);
      }
    });

    test('collects mirrors from urls and objects', () {
      final channels = JsonChannelParser.parse(
        '{"channels":[{"name":"A","url":"https://a/a.m3u8",'
        '"mirrors":["https://b/a.m3u8",{"url":"https://c/a.m3u8"}]}]}',
        providerId: 'p',
      );

      expect(channels.single.urls, [
        'https://a/a.m3u8',
        'https://b/a.m3u8',
        'https://c/a.m3u8',
      ]);
    });

    test('skips entries without a name or url', () {
      final channels = JsonChannelParser.parse(
        '{"channels":[{"name":"No url"},{"url":"https://a"},'
        '{"name":"Ok","url":"https://ok"}]}',
        providerId: 'p',
      );

      expect(channels.map((c) => c.name), ['Ok']);
    });


    test('reads a grouped catalogue keyed by country', () {
      const body = '{"countries":{"France":[{"n":"TF1","u":["https://tf1.m3u8"],'
          '"l":"https://logo/tf1.png"}]},"categories":{"Sport":[{"n":"L Equipe",'
          '"u":["https://lequipe.m3u8"]}]}}';
      final channels = JsonChannelParser.parse(body, providerId: 'world');

      expect(channels.map((c) => c.name), ['TF1', 'L Equipe']);
      expect(channels.map((c) => c.group), ['France', 'Sport']);
      expect(channels.first.logoUrl, 'https://logo/tf1.png');
    });

    test('a grouped entry keeps every mirror url', () {
      const body = '{"countries":{"FR":[{"n":"C","u":["https://a","https://b"]}]}}';
      final channels = JsonChannelParser.parse(body, providerId: 'p');

      expect(channels.single.urls, ['https://a', 'https://b']);
    });

    test('an explicit group on a channel wins over its container', () {
      const body = '{"countries":{"France":[{"n":"C","u":["https://a"],'
          '"group":"Custom"}]}}';
      final channels = JsonChannelParser.parse(body, providerId: 'p');

      expect(channels.single.group, 'Custom');
    });

    test('a grouped catalogue skips malformed channels but keeps the rest', () {
      const body = '{"countries":{"FR":[{"n":"NoUrl"},{"n":"Ok","u":["https://ok"]}]}}';
      final channels = JsonChannelParser.parse(body, providerId: 'p');

      expect(channels.map((c) => c.name), ['Ok']);
    });

    test('invalid json yields no channels', () {
      expect(JsonChannelParser.parse('nope', providerId: 'p'), isEmpty);
      expect(JsonChannelParser.parse('{}', providerId: 'p'), isEmpty);
    });
  });

  group('bundled world catalogue', () {
  test('the bundled world catalogue is readable and grouped', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final body = await rootBundle.loadString(LiveDefaults.bundledAsset);
    final channels = JsonChannelParser.parse(
      body,
      providerId: LiveDefaults.bundledId,
    );

    expect(channels.length, greaterThan(1000));
    expect(channels.any((c) => c.group == 'France'), isTrue);
    expect(channels.any((c) => c.urls.length > 1), isTrue,
        reason: 'mirrors are what make a dead stream survivable');
  }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
