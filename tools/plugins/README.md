# 🎵 Watchtower Music Plugins — Build & Release

Music plugins extend Watchtower with metadata providers (Spotify, MusicBrainz,
…) and audio sources (YouTube, FLAC, …). They are Hetu scripts compiled to
bytecode and shipped as a `.smplug` archive:

```
plugin.smplug (ZIP)
├── plugin.json    # manifest: name, version, entryPoint, abilities, apis
├── plugin.out     # compiled Hetu bytecode (hetu_script_dev_tools 0.1.0+2)
└── logo.png       # optional icon
```

## One catalogue, one source tree

Every music plugin — sources, build script and published artifact — lives in the
single repository **`ferelking242/watchtower-extensions`**:

| Path | Contents |
|---|---|
| `plugin-sources/<name>/` | Hetu `.ht` sources + `plugin.json` + `logo.png` |
| `plugin-sources/build_all.sh` | Compiles every source into `plugins/<slug>.smplug` |
| `plugins/<slug>.smplug` | Published artifact, served over raw.githubusercontent |
| `index/music.json` | Marketplace extension index |

There are **no per-plugin repositories**. Adding a provider means dropping a
source directory under `plugin-sources/`, adding it to the `PLUGINS` array in
`plugin-sources/build_all.sh`, running the script, and committing the produced
`plugins/<slug>.smplug`.

## Building

```bash
# Prerequisites — the compiler version is PINNED. hetu_script_dev_tools >= 0.5
# emits bytecode the hetu_script 0.4.2 runtime bundled in Watchtower cannot
# load (LOAD_FAIL on import). Never bump it without re-testing in the app.
dart pub global activate hetu_script_dev_tools 0.1.0+2

# From a checkout of watchtower-extensions:
./plugin-sources/build_all.sh              # every plugin
./plugin-sources/build_all.sh spotify      # one plugin
```

The script refuses to publish when the manifest's `entryPoint` is absent from
the compiled bytecode — that mismatch makes the plugin install but fail to load
at runtime.

## Distribution

1. `plugins/<slug>.smplug` is committed to `watchtower-extensions`.
2. Watchtower's Marketplace reads its plugin list from the static
   `_kKnownRepos` table in
   `lib/modules/music/provider/metadata_plugin/core/repositories.dart`, which
   points each entry at
   `.../watchtower-extensions/main/plugins/<slug>.smplug`.
3. `build-plugins.yml` in the catalogue repo validates every `.smplug` on push.

## Bundled plugins

Two plugins ship inside the app bundle (declared in `pubspec.yaml` and loaded by
`_loadDefaultPlugins`), so the very first launch has a working audio source and
a working metadata provider with no download:

| Bundle slug | Catalogue source | entryPoint |
|---|---|---|
| `spotube-plugin-youtube-audio` | `plugin-sources/youtube-audio` | `YouTubeAudioSourcePlugin` |
| `spotube-plugin-musicbrainz-listenbrainz` | `plugin-sources/musicbrainz` | `BrainzMetadataProviderPlugin` |

`tools/plugins/sync_bundled.sh` refreshes those two bundled copies from the
catalogue. `test/music_plugin_entrypoint_test.dart` pins that each bundled
manifest's `entryPoint` is a class the bytecode actually exports.

## Plugin API (Hetu)

Metadata plugins:

- `search.all(query)` / `search.tracks(query)` → paginated results
- `album.getAlbum(id)` / `artist.getArtist(id)` / `playlist.getPlaylist(id)`
- `browse.home()` → curated sections
- `auth.login()` → OAuth via WebView
- `core.checkUpdate(config)` → version check

Audio-source plugins:

- `audioSource.matches(track)` → candidate matches
- `audioSource.streams(match)` → streaming URLs
- `audioSource.supportedPresets` → quality presets

Shared Hetu dependencies (`hetu_std`, `hetu_spotube_plugin`, `hetu_otp_util`,
`hetu_spotify_gql_client`) are vendored under each source's `dependencies/`.
