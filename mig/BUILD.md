# ARM64 migration preview

This is a standalone UI entrypoint for testing the FlixQuest screen migration
before any integration into Watchtower.

From the repository root:

```bash
bash mig/build_arm64.sh
```

The script creates a temporary minimal Flutter Android project and copies only
`mig/pubspec.yaml` and `mig/lib/` into it. The preview therefore does not load
Watchtower's Rust, media, downloader, backend or platform plugins. It contains
fixture data and the shared `shimmer` package. It does not connect Firebase,
ads, a backend, a downloader, metadata network services or any reader/player.

The original source selection remains available under `mig/flixquest/` for
comparison. The runnable preview is under `mig/lib/`.