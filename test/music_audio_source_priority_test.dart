import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';

/// The audio-source fallback chain depends on a deterministic priority order:
/// the user-selected default first, then every other installed audio-source
/// plugin, with metadata-only plugins excluded and no duplicates.
///
/// `orderAudioSourceConfigs` is the pure core of that ordering; the provider
/// then loads each entry into an `AudioSourceBackend` and playback walks the
/// resulting list so a dead provider is replaced by the next one.
PluginConfiguration _plugin(
  String name, {
  required List<PluginAbilities> abilities,
}) {
  return PluginConfiguration(
    name: name,
    description: "$name plugin",
    version: "1.0.0",
    author: "tester",
    entryPoint: "${name}Plugin",
    pluginApiVersion: "2.0.0",
    abilities: abilities,
  );
}

void main() {
  test('default audio source is placed first', () {
    final youtube = _plugin("YouTube", abilities: [PluginAbilities.audioSource]);
    final flac = _plugin("Flac", abilities: [PluginAbilities.audioSource]);

    // default is the *second* plugin in the list
    final state = MetadataPluginState(
      plugins: [youtube, flac],
      defaultAudioSourcePlugin: 1,
    );

    expect(
      orderAudioSourceConfigs(state).map((p) => p.slug).toList(),
      ["flac", "youtube"],
    );
  });

  test('metadata-only plugins are excluded', () {
    final youtube = _plugin("YouTube", abilities: [PluginAbilities.audioSource]);
    final brainz = _plugin(
      "Musicbrainz and Listenbrainz",
      abilities: [PluginAbilities.metadata, PluginAbilities.scrobbling],
    );

    final state = MetadataPluginState(
      plugins: [brainz, youtube],
      defaultAudioSourcePlugin: 1,
    );

    expect(
      orderAudioSourceConfigs(state).map((p) => p.slug).toList(),
      ["youtube"],
    );
  });

  test('the default is never duplicated', () {
    final youtube = _plugin("YouTube", abilities: [PluginAbilities.audioSource]);
    final flac = _plugin("Flac", abilities: [PluginAbilities.audioSource]);

    final state = MetadataPluginState(
      plugins: [youtube, flac],
      defaultAudioSourcePlugin: 0,
    );

    final slugs = orderAudioSourceConfigs(state).map((p) => p.slug).toList();
    expect(slugs, ["youtube", "flac"]);
    expect(slugs.toSet().length, slugs.length);
  });

  test('a plugin able to do both stays available as a fallback', () {
    final spotify = _plugin(
      "Spotify",
      abilities: [PluginAbilities.metadata, PluginAbilities.audioSource],
    );
    final youtube = _plugin("YouTube", abilities: [PluginAbilities.audioSource]);

    final state = MetadataPluginState(
      plugins: [spotify, youtube],
      defaultAudioSourcePlugin: 1,
    );

    expect(
      orderAudioSourceConfigs(state).map((p) => p.slug).toList(),
      ["youtube", "spotify"],
    );
  });

  test('no default and no audio-source plugin yields an empty list', () {
    final brainz = _plugin(
      "Musicbrainz and Listenbrainz",
      abilities: [PluginAbilities.metadata],
    );

    final state = MetadataPluginState(plugins: [brainz]);

    expect(orderAudioSourceConfigs(state), isEmpty);
  });

  test('an out-of-range default index still lists every audio source', () {
    final youtube = _plugin("YouTube", abilities: [PluginAbilities.audioSource]);
    final flac = _plugin("Flac", abilities: [PluginAbilities.audioSource]);

    // default index points past the end (stale DB state)
    final state = MetadataPluginState(
      plugins: [youtube, flac],
      defaultAudioSourcePlugin: 9,
    );

    expect(
      orderAudioSourceConfigs(state).map((p) => p.slug).toList(),
      ["youtube", "flac"],
    );
  });
}
