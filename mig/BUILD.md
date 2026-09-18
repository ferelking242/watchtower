# ARM64 migration preview

This is a standalone UI entrypoint for testing the FlixQuest screen migration
before any integration into Watchtower.

From the repository root:

```bash
flutter pub get
bash mig/build_arm64.sh
```

The command builds only `mig/lib/main.dart` using the existing Android
scaffold and the existing Watchtower dependency graph. The preview contains
fixture data and the shared `shimmer` package. It does not connect Firebase,
ads, a backend, a downloader, metadata network services or any reader/player.

The original source selection remains available under `mig/flixquest/` for
comparison. The runnable preview is under `mig/lib/`.