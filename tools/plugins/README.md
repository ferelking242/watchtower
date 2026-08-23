# 🎵 Watchtower Music Plugins — Build & Release Guide

## Overview

Music plugins extend Watchtower with metadata providers (Spotify, MusicBrainz, etc.) and audio sources (YouTube, FLAC, etc.). Each plugin is a `.smplug` archive containing:

```
plugin.smplug (ZIP)
├── plugin.json    # Plugin metadata (name, version, abilities, APIs)
├── plugin.out     # Compiled Hetu bytecode
└── logo.png       # Plugin icon (optional)
```

## Plugin Repos

| Plugin | Repo | Abilities | APIs |
|---|---|---|---|
| **Spotify** | [spotube-plugin-spotify](https://github.com/ferelking242/spotube-plugin-spotify) | authentication, metadata | webview, localstorage, timezone |
| **Apple Music** | [spotube-plugin-applemusic](https://github.com/ferelking242/spotube-plugin-applemusic) | authentication, metadata | webview, localstorage |
| **Deezer** | [spotube-plugin-deezer](https://github.com/ferelking242/spotube-plugin-deezer) | authentication, metadata | webview, localstorage |
| **YouTube Music** | [spotube-plugin-youtube-music](https://github.com/ferelking242/spotube-plugin-youtube-music) | authentication, metadata | webview, localstorage, timezone |

## Building Locally

### Prerequisites

```bash
# Install Dart SDK (if not present)
curl -sL -o /tmp/dart-sdk.zip "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip"
unzip /tmp/dart-sdk.zip -d /opt/
export PATH="/opt/dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"

# Install Hetu compiler
dart pub global activate hetu_script_dev_tools
```

### Build All Plugins

```bash
# From the watchtower repo
./tools/plugins/build_all.sh

# Or with custom repos directory
PLUGIN_REPOS_DIR=/path/to/repos ./tools/plugins/build_all.sh

# Build a single plugin
./tools/plugins/build_all.sh spotify
```

### Build One Plugin

```bash
cd spotube-plugin-spotify
make compile   # → build/plugin.out (Hetu bytecode)
make archive   # → plugin.smplug (ZIP with plugin.json + plugin.out + logo.png)
```

## Release Process

### Automated (via GitHub Actions)

1. Update `plugin.json` version
2. Commit and push to `main`
3. Create a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions will:
   - Compile the plugin
   - Package the `.smplug`
   - Create a GitHub Release with formatted notes

### Manual

```bash
# Build
make archive

# Create release
gh release create v1.0.0 plugin.smplug \
  --title "Plugin Name v1.0.0" \
  --notes "Release notes here"
```

## Distribution

Plugins are distributed via the **Watchtower Extensions** repository:

1. Each plugin's `.smplug` is hosted in its GitHub Releases
2. The `watchtower-extensions` repo has an `index/music.json` that lists all plugins with their download URLs
3. Watchtower's Marketplace fetches this index and shows available plugins
4. Users install plugins from the Marketplace → Music tab

### Plugin Index Format

```json
{
  "id": 3001,
  "name": "Spotify",
  "iconUrl": "https://cdn.simpleicons.org/spotify",
  "version": "1.0.0",
  "abilities": ["metadata", "audio-source"],
  "upstream": "https://github.com/ferelking242/spotube-plugin-spotify/releases/latest/download/plugin.smplug"
}
```

## Plugin API (Hetu Script)

Plugins are written in [Hetu Script](https://hetu.dev/) and implement these endpoints:

### Metadata Plugins
- `search.all(query)` → tracks, albums, artists, playlists
- `search.tracks(query)` → paginated tracks
- `album.getAlbum(id)` → full album details
- `artist.getArtist(id)` → artist info + discography
- `playlist.getPlaylist(id)` → playlist tracks
- `browse.home()` → curated content
- `auth.login()` → OAuth via WebView
- `core.checkUpdate(config)` → version check

### Audio Source Plugins
- `audioSource.matches(track)` → find matching audio sources
- `audioSource.streams(match)` → get streaming URLs
- `audioSource.supportedPresets` → available quality presets

## Dependencies

Some plugins depend on shared Hetu libraries:

| Dependency | Used By | Purpose |
|---|---|---|
| `hetu_std` | All | Standard library (HTTP, collections) |
| `hetu_spotube_plugin` | All | Plugin API bindings (YouTubeEngine, localStorage, WebView) |
| `hetu_otp_util` | Spotify, Deezer | OTP/TOTP for authentication |
| `hetu_spotify_gql_client` | Spotify, Deezer | Spotify GraphQL API client |

These are included as git submodules in each plugin's `dependencies/` directory.
