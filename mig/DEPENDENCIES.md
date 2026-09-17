# Migration dependency decision list

Source: `flixquest/flixquest` at commit `344c8f7`.

The files in `mig/flixquest` are a visual extraction, not a drop-in module.
The original imports still point to FlixQuest packages so the screen layout
can be reviewed before adapting it to Watchtower. Do not add FlixQuest
dependencies to Watchtower just to make this snapshot compile.

## Use what Watchtower already has

These FlixQuest dependencies already exist in Watchtower and can be reused
when a screen is integrated:

| FlixQuest dependency | Watchtower replacement |
| --- | --- |
| `cached_network_image` | Keep it, or prefer Watchtower's existing image wrapper where one already exists. |
| `cupertino_icons` | Keep only where an existing Watchtower screen already uses it. |
| `device_info_plus` | Reuse the existing package for device/platform checks. |
| `dynamic_color` | Reuse Watchtower theme handling. |
| `file_picker` | Reuse only for profile/settings import or export UI that is retained. |
| `flutter_cache_manager` | Reuse the existing cache layer. |
| `flutter_local_notifications` | Reuse only for existing Watchtower notification flows. |
| `flutter_svg` | Reuse for SVG assets. |
| `home_widget` | Reuse only for an existing Watchtower widget flow; not needed by these screens. |
| `http` | Do not call it from the copied screens; use a Watchtower repository/fixture. |
| `intl` | Reuse for formatting. |
| `open_filex` | Keep only for a retained settings/about action. |
| `package_info_plus` | Reuse for the About screen version label. |
| `path`, `path_provider` | Reuse only for retained local settings/export UI. |
| `permission_handler` | Reuse only when a Watchtower feature really needs the permission. |
| `photo_view` | Reuse for the copied gallery/photo detail UI. |
| `provider` | Available in Watchtower, but do not carry over FlixQuest providers. |
| `share_plus` | Reuse only for explicit share actions that Watchtower supports. |
| `shared_preferences` | Use for local visual/settings preferences instead of Firebase. |
| `sqflite` | Use only through Watchtower's existing persistence layer, not by copying FlixQuest controllers. |
| `url_launcher` | Reuse for About/external links. |
| `wakelock_plus` | Not needed when the player is excluded. |
| `xml` | Keep only if a retained visual/settings import needs it. |

## Replace with Watchtower UI primitives

These packages are not needed as FlixQuest dependencies. Replace their visual
roles with existing Watchtower packages or Flutter primitives:

| FlixQuest dependency | Replacement |
| --- | --- |
| `easy_localization`, `flutter_localization` | Watchtower `flutter_localizations` and its generated l10n setup. |
| `phosphor_flutter` | Existing `font_awesome_flutter`, `fluentui_system_icons`, `feather_icon_font` or `simple_icons`. |
| `shimmer` | Existing `skeletonizer` or Watchtower loading/skeleton widgets. |
| `carousel_slider` | `PageView`, `CustomScrollView` or Watchtower list/carousel components. |
| `google_nav_bar` | Material `NavigationBar`/`NavigationRail` or Watchtower navigation. |
| `percent_indicator` | Material progress indicators or an existing Watchtower progress widget. |
| `readmore` | Existing expandable text pattern or a small local widget. |
| `flutter_colorpicker` | Watchtower theme/color controls using `flex_color_scheme` or Material controls. |
| `native_device_orientation` | Flutter `MediaQuery`/`Orientation` and existing window handling. |
| `retry` | A small repository-level retry policy, not screen code. |
| `animated_text_kit` | Existing Flutter animation primitives only if the visual effect is retained. |

## Remove or stub for this visual migration

These dependencies belong to backend, playback, account, telemetry or
distribution behavior and must not be brought into Watchtower for the copied
screens:

### Firebase and authentication

Remove all of these from the migration:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_analytics`
- `firebase_crashlytics`
- `firebase_in_app_messaging`
- `firebase_messaging`
- `firebase_remote_config`
- `google_sign_in`

Use a deterministic fixture user for the profile screen while staging the UI.
If Watchtower later needs account behavior, connect it to the authentication
system already selected for Watchtower rather than adding Firebase here.

### Playback and download

Exclude or stub:

- `better_player_plus`
- `flutter_download_manager`
- `flutter_downloader`
- all stream/video-loader/source selection code

The requested migration intentionally does not include the reader/player.

### Ads, analytics and environment services

Remove or replace with no-op visual placeholders:

- `unity_ads_plugin`
- `mixpanel_flutter`
- `flutter_dotenv`

Ads and analytics must not be required to render any copied screen.

## Files that need splitting before integration

These copied files combine UI with backend/player behavior:

- `mig/flixquest/lib/widgets/common_widgets.dart`
- `mig/flixquest/lib/widgets/movie_widgets.dart`
- `mig/flixquest/lib/widgets/tv_widgets.dart`
- `mig/flixquest/lib/widgets/person_widgets.dart`
- `mig/flixquest/lib/screens/movie/movie_detail.dart`
- `mig/flixquest/lib/screens/tv/tv_detail.dart`
- `mig/flixquest/lib/screens/person/searchedperson.dart`
- `mig/flixquest/lib/screens/user/user_info.dart`
- `mig/flixquest/lib/screens/common/settings.dart`

Keep the visual subwidgets and callbacks, then replace network/provider
callbacks with Watchtower fixture data. Do not copy these FlixQuest layers:

- `lib/api`
- `lib/functions/network.dart`
- `lib/provider`
- `lib/controllers`
- `lib/services`
- `lib/video_providers`
- any player/stream/video-loader file

## Current staging status

- `mig/flixquest/` contains the selected source and visual assets.
- Watchtower `lib/`, `pubspec.yaml` and platform folders were not modified.
- The staging snapshot is deliberately not claimed to compile yet because its
  original imports still identify the backend boundaries that must be replaced.