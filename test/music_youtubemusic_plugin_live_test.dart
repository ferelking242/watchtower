import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart' as spotube_plugin;
import 'package:hetu_std/hetu_std.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/modules/music/services/metadata/apis/localstorage.dart';

/// Live smoke test for the bundled YouTube Music metadata plugin.
///
/// The plugin talks to the public InnerTube API, so this test needs network
/// access. It is skipped by default; run it with
///
///   flutter test test/music_youtubemusic_plugin_live_test.dart --dart-define=RUN_LIVE_PLUGIN_TESTS=true
///
/// It verifies the real contracts the Dart side depends on: the endpoints must
/// return maps/lists that the `Spotube*Object.fromJson` factories accept, not
/// just syntactically valid bytecode.
const _runLive = bool.fromEnvironment('RUN_LIVE_PLUGIN_TESTS');

Future<Hetu> _newHetu() async {
  final prefs = await SharedPreferences.getInstance();
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);
  spotube_plugin.HetuSpotubePluginLoader.loadBindings(
    hetu,
    localStorageImpl: SharedPreferencesLocalStorage(prefs, 'live-test'),
    onNavigatorPush: (_) async {},
    onNavigatorPop: () {},
    onShowForm: (_, __) async => [],
    createYoutubeEngine: () => throw UnimplementedError(),
  );
  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await spotube_plugin.HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);
  return hetu;
}

Map<String, dynamic> _manifest(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.firstWhere(
    (f) => f.isFile && f.name == 'plugin.json',
  );
  return jsonDecode(utf8.decode(file.content as List<int>))
      as Map<String, dynamic>;
}

Uint8List _bytecode(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.firstWhere(
    (f) => f.isFile && f.name == 'plugin.out',
  );
  return file.content as Uint8List;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  // flutter_test installs an HttpOverrides that answers every request with a
  // canned 400. These tests are explicitly live, so drop it.
  HttpOverrides.global = null;

  late Hetu hetu;
  late HTInstance plugin;

  setUpAll(() async {
    final archiveBytes =
        _readBytes('assets/plugins/spotube-plugin-youtubemusic/plugin.smplug');
    final manifest = _manifest(archiveBytes);
    hetu = await _newHetu();
    hetu.loadBytecode(
      bytes: _bytecode(archiveBytes),
      moduleName: 'plugin',
    );
    hetu.eval('import "module:plugin" as plugin\n'
        'var Plugin = plugin.${manifest['entryPoint']}\n'
        'var metadataPlugin = Plugin()');
    plugin = hetu.fetch('metadataPlugin') as HTInstance;
  });

  group('endpoint surface', () {
    test('exposes every segment the Dart layer resolves', () {
      for (final name in const [
        'auth',
        'album',
        'artist',
        'browse',
        'search',
        'playlist',
        'track',
        'user',
        'core',
      ]) {
        expect(
          plugin.memberGet(name),
          isA<HTInstance>(),
          reason: 'metadataPlugin.$name must exist',
        );
      }
    });

    test('search.chips is a list of strings', () {
      final chips = (plugin.memberGet('search') as HTInstance)
          .memberGet('chips') as List;
      expect(chips, isNotEmpty);
      expect(chips.every((c) => c is String), isTrue);
    });
  });

  group('live InnerTube', () {
    test('search.tracks returns parseable rows', () async {
      final search = plugin.memberGet('search') as HTInstance;
      final raw = await search.invoke(
        'tracks',
        positionalArgs: ['daft punk'],
        namedArgs: {'limit': 10, 'offset': 0},
      ) as Map;
      final page = raw.cast<String, dynamic>();
      expect(page['items'], isA<List>());
      expect((page['items'] as List), isNotEmpty);
      final first = (page['items'] as List).first as Map;
      expect(first['id'], isA<String>());
      expect(first['name'], isA<String>());
      expect(first['artists'], isA<List>());
      expect((first['artists'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('search.artists / search.playlists return rows', () async {
      final search = plugin.memberGet('search') as HTInstance;
      final artists = (await search.invoke(
        'artists',
        positionalArgs: ['daft punk'],
        namedArgs: {'limit': 5, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((artists['items'] as List), isNotEmpty);

      final playlists = (await search.invoke(
        'playlists',
        positionalArgs: ['daft punk'],
        namedArgs: {'limit': 5, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((playlists['items'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('track.getTrack resolves a real duration', () async {
      final track = plugin.memberGet('track') as HTInstance;
      final raw = await track.invoke(
        'getTrack',
        positionalArgs: ['FxzBvqY5PP0'],
      ) as Map;
      final t = raw.cast<String, dynamic>();
      expect(t['name'], contains('Digital Love'));
      expect(t['durationMs'], greaterThan(200000));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('track.radio returns a real queue', () async {
      final track = plugin.memberGet('track') as HTInstance;
      final raw = await track.invoke(
        'radio',
        positionalArgs: ['FxzBvqY5PP0'],
      ) as List;
      expect(raw.length, greaterThan(5));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('browse.sections then sectionItems return real shelves', () async {
      final browse = plugin.memberGet('browse') as HTInstance;
      final sections = (await browse.invoke(
        'sections',
        namedArgs: {'limit': 20, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((sections['items'] as List), isNotEmpty);

      final first = (sections['items'] as List).first as Map;
      final items = (await browse.invoke(
        'sectionItems',
        positionalArgs: [first['id']],
        namedArgs: {'limit': 20, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((items['items'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('artist.getArtist + topTracks work for a known channel', () async {
      final search = plugin.memberGet('search') as HTInstance;
      final artists = (await search.invoke(
        'artists',
        positionalArgs: ['daft punk'],
        namedArgs: {'limit': 1, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      final artistId = ((artists['items'] as List).first as Map)['id'] as String;

      final artist = plugin.memberGet('artist') as HTInstance;
      final info = (await artist.invoke(
        'getArtist',
        positionalArgs: [artistId],
      ) as Map)
          .cast<String, dynamic>();
      expect(info['name'], isNotEmpty);

      final top = (await artist.invoke(
        'topTracks',
        positionalArgs: [artistId],
        namedArgs: {'limit': 5, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((top['items'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('playlist.getPlaylist + tracks work for a known playlist', () async {
      final search = plugin.memberGet('search') as HTInstance;
      final playlists = (await search.invoke(
        'playlists',
        positionalArgs: ['daft punk'],
        namedArgs: {'limit': 1, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      final id = ((playlists['items'] as List).first as Map)['id'] as String;

      final playlist = plugin.memberGet('playlist') as HTInstance;
      final info = (await playlist.invoke(
        'getPlaylist',
        positionalArgs: [id],
      ) as Map)
          .cast<String, dynamic>();
      expect(info['name'], isNotEmpty);

      final tracks = (await playlist.invoke(
        'tracks',
        positionalArgs: [id],
        namedArgs: {'limit': 5, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((tracks['items'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('album.releases returns the New releases shelf', () async {
      final album = plugin.memberGet('album') as HTInstance;
      final raw = (await album.invoke(
        'releases',
        namedArgs: {'limit': 10, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect((raw['items'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('user endpoints degrade to empty when signed out', () async {
      final user = plugin.memberGet('user') as HTInstance;
      final saved = (await user.invoke(
        'savedTracks',
        namedArgs: {'limit': 5, 'offset': 0},
      ) as Map)
          .cast<String, dynamic>();
      expect(saved['items'], isEmpty);
      expect(saved['hasMore'], isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));
  }, skip: _runLive ? false : 'set RUN_LIVE_PLUGIN_TESTS=true to run');
}

Uint8List _readBytes(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());
