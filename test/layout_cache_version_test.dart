import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/layout_registry.dart';

/// Serves a throwaway temp directory so the registry writes real files.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

const _layoutV1 = '''
{"schemaVersion":1,"home":{"sections":[
  {"id":"spotlight","component":"spotlight","title":"A la une"}
]}}
''';

const _layoutV2 = '''
{"schemaVersion":1,"home":{"sections":[
  {"id":"spotlight","component":"spotlight","title":"A la une"},
  {"id":"popular","component":"ranked","title":"Les plus lus"},
  {"id":"latest","component":"compactRow","title":"Dernieres sorties"},
  {"id":"new","component":"grid","title":"Nouveautes","columns":3,"rows":2}
]}}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Source source;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('layout_cache_test');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    LayoutRegistry.instance.clear();
    source = Source()
      ..id = 2000001178
      ..name = 'MKissa'
      ..uiLayout = 'ui-layouts/mkissa.json'
      ..uiLayoutVersion = '1.1.0';
  });

  tearDown(() async {
    LayoutRegistry.instance.clear();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('a layout cached for another version is discarded, not served', () async {
    // Install time: the catalogue said 1.0.1 and the old 1-section JSON was
    // written. The catalogue then edits the layout and bumps the version.
    final installed = Source()
      ..id = source.id
      ..name = source.name
      ..uiLayout = source.uiLayout
      ..uiLayoutVersion = '1.0.1';
    expect(await LayoutRegistry.instance.save(installed, _layoutV1), isTrue);

    // A fresh process reloads the cache. The installed source now declares
    // 1.1.0, so the 1.0.1 file must be rejected — otherwise the home keeps
    // rendering the old sections forever, which is exactly the bug.
    LayoutRegistry.instance.clear();
    await LayoutRegistry.instance.load(source);

    expect(
      LayoutRegistry.instance.has(source),
      isFalse,
      reason: 'a stale layout must not be loaded from the cache',
    );
    expect(LayoutRegistry.instance.get(source).home.sections, isEmpty);

    // And the refetch that follows stores the new version.
    expect(await LayoutRegistry.instance.save(source, _layoutV2), isTrue);
    LayoutRegistry.instance.clear();
    await LayoutRegistry.instance.load(source);
    expect(LayoutRegistry.instance.has(source), isTrue);
    expect(LayoutRegistry.instance.get(source).home.sections.length, 4);
  });

  test('a layout cached for the current version is served', () async {
    expect(await LayoutRegistry.instance.save(source, _layoutV2), isTrue);

    LayoutRegistry.instance.clear();
    await LayoutRegistry.instance.load(source);

    expect(LayoutRegistry.instance.has(source), isTrue);
    expect(LayoutRegistry.instance.get(source).home.sections.length, 4);
  });

  test('an unversioned catalogue entry keeps its cached layout', () async {
    final unversioned = Source()
      ..id = source.id
      ..name = source.name
      ..uiLayout = source.uiLayout;
    expect(await LayoutRegistry.instance.save(unversioned, _layoutV2), isTrue);

    LayoutRegistry.instance.clear();
    await LayoutRegistry.instance.load(unversioned);

    expect(LayoutRegistry.instance.has(unversioned), isTrue);
  });
}
