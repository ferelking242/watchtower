# Reel shell (vertical feed)

Reel is the TikTok-style shell: full-screen vertical feed, side actions, comments
sheet, creator profiles, live strip. It lives in its own repository
(`ferelking242/reel`) and is mounted here as a git submodule at `reel/`.

## Why a submodule and not a copy

The shell is a complete app: its own `main.dart`, its own tests, its own release
train. Copying the sources into `lib/` would fork it the first time either side
changes a widget. The submodule keeps one source of truth and makes updates an
explicit, reviewable commit (`git add reel`).

```bash
./scripts/update_reel.sh   # fetch the latest Reel, then commit the pointer
```

## How an extension picks the shell

The extension declares it in `ui-layouts/<slug>.json`:

```json
{
  "schemaVersion": 1,
  "renderer": "reel",
  "capabilities": {
    "live": true,
    "views": true,
    "likes": false,
    "comments": false,
    "shares": false,
    "sounds": true,
    "download": false,
    "follow": true
  }
}
```

- `renderer` — `reel` mounts the vertical shell, anything else (or a missing key)
  keeps the historical watch screens. Existing extensions are unaffected.
- `capabilities` — what the extension really supports. A surface must not show an
  action the extension does not declare: no like button on a source with no like
  endpoint, no live tab when the source has no live catalogue. Omitted keys stay
  permissive, `download` defaults to `false`.

## Wiring

| Piece | File |
| --- | --- |
| Route `reel` (unchanged name, new target) | `lib/router/router.dart` |
| Shell mount + layout read | `lib/modules/reel/reel_host_screen.dart` |
| API answered in-process | `lib/modules/reel/reel_local_transport.dart` |
| Layout schema | `lib/models/ui_layout.dart` |

`ReelLocalTransport` replays `/api/sources`, `.../popular`, `.../latest`,
`.../search`, `.../detail`, `.../videos`, `.../filters` through the same
`RemoteApiHandler` the embedded HTTP API uses. There is no server involved and
no second JSON format to keep in sync. The handler is created with
`allowNsfw: true` because this call path is in-process; the network API keeps its
hard NSFW exclusion.

## CI

Every workflow that runs `flutter pub get` checks out submodules
(`submodules: recursive`); without it the `reel` path dependency is missing and
pub fails.
