# FlixQuest UI migration staging

This folder is an isolated staging copy from `flixquest/flixquest`, commit
`344c8f7`. It is not wired into Watchtower and is intentionally not a Flutter
target yet.

## Included

- Movie discovery, result/list and movie detail screens.
- Series/TV discovery, result/list and series detail screens.
- Actor/person detail screens and cast/crew detail entries.
- Profile, edit profile and profile sub-sections.
- Settings, language/provider settings, about, server status, update and sync
  screens.
- Discover and search/result screens.
- Non-player detail screens for seasons, episodes, collections and galleries.
- Shared visual widgets, media cards, person widgets, UI components and display
  models.
- Only the profile/logo/translation assets needed for the staged UI.

## Explicitly excluded

- Movie, TV and common player screens.
- Stream selection and video loader screens.
- TV player sources and `lib/video_providers`.
- FlixQuest API/network code, controllers, services and business providers.
- Firebase/Auth/Firestore, analytics, ads, downloads and destructive account
  operations.
- FlixQuest `main.dart`, platform projects and full dependency configuration.

Some copied shared widgets (`common_widgets.dart`, `movie_widgets.dart` and
`tv_widgets.dart`) mix visual code with playback/provider code. They are kept
as migration references because the copied detail screens import them, but
they must be split before integration. See `DEPENDENCIES.md`.

`COPIED_FILES.txt` is the exact Dart source selection. `SOURCE_COMMIT` records
the source revision.