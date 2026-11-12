import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart' as spotube_plugin;
import 'package:hetu_std/hetu_std.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/modules/music/services/metadata/apis/localstorage.dart';

/// Bundled Spotube plugins ship compiled Hetu bytecode inside a `.smplug`
/// archive. `plugin.json#entryPoint` must name a class that the bytecode
/// actually exports, otherwise `MetadataPlugin.fromConfig` throws
/// `invalidPluginByteCode` and the app falls back to the "no default plugin"
/// screen even though the plugin "installed" fine.
///
/// This is a regression test for exactly that failure: both bundled plugins
/// exported the placeholder `TemplateMetadataProviderPlugin` while their
/// manifest pointed at the real class.
const _bundledPlugins = <String>[
  'spotube-plugin-youtube-audio',
  'spotube-plugin-musicbrainz-listenbrainz',
];

Future<Hetu> _newHetu() async {
  final prefs = await SharedPreferences.getInstance();
  final hetu = Hetu();
  hetu.init();
  HetuStdLoader.loadBindings(hetu);
  spotube_plugin.HetuSpotubePluginLoader.loadBindings(
    hetu,
    localStorageImpl: SharedPreferencesLocalStorage(prefs, 'entrypoint-test'),
    onNavigatorPush: (_) async {},
    onNavigatorPop: () {},
    onShowForm: (_, __) async => [],
    createYoutubeEngine: () => throw UnimplementedError(),
  );
  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await spotube_plugin.HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);
  return hetu;
}

Map<String, dynamic> _readManifest(List<int> archiveBytes) {
  final archive = ZipDecoder().decodeBytes(archiveBytes);
  final manifest = archive.firstWhere(
    (file) => file.isFile && file.name == 'plugin.json',
  );
  return jsonDecode(utf8.decode(manifest.content as List<int>))
      as Map<String, dynamic>;
}

Uint8List _readBytecode(List<int> archiveBytes) {
  final archive = ZipDecoder().decodeBytes(archiveBytes);
  final bytecode = archive.firstWhere(
    (file) => file.isFile && file.name == 'plugin.out',
  );
  return bytecode.content as Uint8List;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  for (final slug in _bundledPlugins) {
    group(slug, () {
      late List<int> archiveBytes;
      late Map<String, dynamic> manifest;

      setUpAll(() {
        archiveBytes = File(
          'assets/plugins/$slug/plugin.smplug',
        ).readAsBytesSync();
        manifest = _readManifest(archiveBytes);
      });

      test('manifest declares an entryPoint', () {
        expect(manifest['entryPoint'], isA<String>());
        expect((manifest['entryPoint'] as String).trim(), isNotEmpty);
      });

      test('the declared entryPoint is exported by the bytecode', () async {
        final hetu = await _newHetu();
        hetu.loadBytecode(
          bytes: _readBytecode(archiveBytes),
          moduleName: 'plugin',
        );

        final entryPoint = manifest['entryPoint'] as String;
        // Import the module and resolve the entry class. An undefined
        // identifier here means the bytecode does not export that class.
        hetu.eval('import "module:plugin" as plugin\n'
            'var EntryPoint = plugin.$entryPoint');
      });

      test('the entryPoint is not the placeholder template class', () {
        expect(manifest['entryPoint'], isNot('TemplateMetadataProviderPlugin'));
      });
    });
  }
}
