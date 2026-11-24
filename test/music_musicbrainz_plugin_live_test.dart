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

/// Live smoke test for the bundled MusicBrainz / ListenBrainz plugin, run
/// **signed out** — the state every new install starts in.
///
/// ListenBrainz answers `401` on a few endpoints when no token is sent
/// (`/explore/lb-radio`, per-user stats and feedback). The plugin must fall
/// back to public APIs instead of surfacing that 401 to the Hub, so this test
/// exercises the endpoints the Hub's home and settings pages actually call.
///
///   flutter test test/music_musicbrainz_plugin_live_test.dart \
///     --dart-define=RUN_LIVE_PLUGIN_TESTS=true
const _runLive = bool.fromEnvironment('RUN_LIVE_PLUGIN_TESTS');

const _pluginPaths = <String>[
  'assets/plugins/spotube-plugin-musicbrainz-listenbrainz/plugin.smplug',
  '../watchtower-extensions/plugins/musicbrainz.smplug',
];

String? _locatePlugin() {
  for (final path in _pluginPaths) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

Future<Hetu> _newHetu() async {
  final prefs = await SharedPreferences.getInstance();
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);
  spotube_plugin.HetuSpotubePluginLoader.loadBindings(
    hetu,
    localStorageImpl: SharedPreferencesLocalStorage(prefs, 'brainz-live'),
    onNavigatorPush: (_) async {},
    onNavigatorPop: () {},
    onShowForm: (_, _) async => [],
    createYoutubeEngine: () => throw UnimplementedError(),
  );
  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await spotube_plugin.HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);
  return hetu;
}

ArchiveFile _entry(List<int> bytes, String name) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return archive.firstWhere((f) => f.isFile && f.name == name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  HttpOverrides.global = null;

  late HTInstance plugin;
  final pluginPath = _locatePlugin();

  setUpAll(() async {
    if (!_runLive) return;
    final path = pluginPath;
    if (path == null) {
      throw StateError('MusicBrainz .smplug not found');
    }
    final bytes = File(path).readAsBytesSync();
    final manifest =
        jsonDecode(utf8.decode(_entry(bytes, 'plugin.json').content as List<int>))
            as Map<String, dynamic>;
    final hetu = await _newHetu();
    hetu.loadBytecode(
      bytes: _entry(bytes, 'plugin.out').content as Uint8List,
      moduleName: 'plugin',
    );
    hetu.eval('import "module:plugin" as plugin\n'
        'var Plugin = plugin.${manifest['entryPoint']}\n'
        'var metadataPlugin = Plugin()');
    plugin = hetu.fetch('metadataPlugin') as HTInstance;
  });

  Future<dynamic> call(String segment, String method,
      {List<dynamic>? positionalArgs, Map<String, dynamic>? namedArgs}) async {
    final instance = plugin.memberGet(segment) as HTInstance;
    return instance.invoke(
      method,
      positionalArgs: positionalArgs ?? const [],
      namedArgs: namedArgs ?? const {},
    );
  }

  group('signed-out endpoints never leak a 401', () {
    test('browse.sections returns shelves', () async {
      final raw = await call('browse', 'sections',
          namedArgs: {'limit': 25, 'offset': 0}) as Map;
      final sections = raw.cast<String, dynamic>();
      expect((sections['items'] as List), isNotEmpty);
      for (final section in sections['items'] as List) {
        final s = (section as Map).cast<String, dynamic>();
        expect((s['items'] as List), isNotEmpty,
            reason: 'shelf ${s['title']} must not be empty');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('album.releases returns the public fresh releases', () async {
      final raw = await call('album', 'releases',
          namedArgs: {'limit': 10, 'offset': 0}) as Map;
      final page = raw.cast<String, dynamic>();
      expect((page['items'] as List), isNotEmpty);
      final first = (page['items'] as List).first as Map;
      expect(first['name'], isNotEmpty);
      expect((first['artists'] as List), isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('track.radio resolves a queue without a token', () async {
      final search = await call('search', 'tracks', positionalArgs: ['daft punk'],
          namedArgs: {'limit': 1, 'offset': 0}) as Map;
      final trackId = (((search as Map)['items'] as List).first as Map)['id'];
      final raw = await call('track', 'radio', positionalArgs: [trackId]) as List;
      expect(raw, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('search covers tracks, albums, artists and playlists', () async {
      for (final method in const ['tracks', 'albums', 'artists', 'playlists']) {
        final raw = await call('search', method, positionalArgs: ['daft punk'],
            namedArgs: {'limit': 3, 'offset': 0}) as Map;
        expect((raw.cast<String, dynamic>()['items'] as List), isNotEmpty,
            reason: 'search.$method must return rows');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }, skip: _runLive ? false : 'set RUN_LIVE_PLUGIN_TESTS=true to run');
}
