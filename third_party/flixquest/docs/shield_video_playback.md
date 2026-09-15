# NVIDIA Shield video compatibility

## Diagnosis and workaround

`player.dart` and `live_player.dart` both use the local `better_player_plus`
plugin. Its Android backend renders Media3/ExoPlayer output into a Flutter
`SurfaceTexture`. The app uses Flutter 3.35.7 and previously had no Impeller
opt-out. Flutter issue [159503](https://github.com/flutter/flutter/issues/159503)
reports missing video (with working audio) on NVIDIA Shield, with multiple
device owners confirming that switching to Skia restores the picture.
[162526](https://github.com/flutter/flutter/issues/162526) is a duplicate covering
the same symptom with multiple video plugins.

This is the leading explanation, not a confirmed reproduction of the FlixQuest
reports. If audio and playback position also fail, investigate the source,
network, DRM and decoder errors separately.

`FlixQuestApplication.attachBaseContext` installs a custom shared Flutter loader
only when all three conditions hold: the manufacturer is NVIDIA, the model
contains SHIELD (both case-insensitive), and Android reports television mode or
the Leanback feature. NVIDIA tablets and other manufacturers' TVs do not match.
Other devices retain Flutter's default loader and renderer selection; there is
no application-wide `EnableImpeller` manifest override.

The Shield loader passes `--enable-impeller=false` at native initialization,
preserving unrelated engine arguments and removing conflicting Impeller flags.
It is registered before content providers and services run, without loading
Flutter during application attachment. In Flutter 3.35.7, both synchronous and
asynchronous initialization use the overridden method. This includes Firebase
Messaging and home-widget background startup before the activity opens.

Skia applies throughout the app on Shield, including both streaming players;
ExoPlayer's hardware video decoding is unaffected. It requires a new APK and a
cold launch, not hot reload. Reassess the Flutter loader integration when
upgrading Flutter, and remove the workaround only after Shield validation.

Live playback also disables ambient glow in TV mode, matching the movie player.
Both settings listeners now preserve that TV restriction. This avoids costly
frame sampling; it is not the primary fix for the Impeller rendering issue.

## Validation with a Shield owner

1. Install a newly built APK and force-stop/relaunch the app.
2. Play a previously failing movie/episode and live channel. Verify the picture,
   audio, controls and advancing position. Record Shield model, Android version,
   app version and whether the original failure had audio.
3. Check pause/resume, seeking, quality/provider switching, channel switching,
   and returning from the home screen. Confirm video after any branded intro.
4. Smoke-test the same APK on a phone and a non-Shield Android TV. These should
   retain their previous renderer. Check Shield UI scrolling/animations as well
   as playback because its renderer change applies throughout the app.
5. Check a background messaging or widget launch before opening the activity,
   followed by playback, to confirm the renderer choice survives that path.

If video is still missing, enable the existing filtered diagnostics before
opening the stream:

```sh
adb shell setprop log.tag.BetterPlayerStreaming DEBUG
adb logcat -v time -s BetterPlayerStreaming:D '*:S'
```

Capture the first-frame event, playback states and error codes while reproducing.
A first-frame callback means ExoPlayer submitted a frame, not that Flutter
successfully displayed it. These filtered diagnostics exclude URLs and headers;
avoid sharing unfiltered logs containing stream credentials.

Disable diagnostics afterwards:

```sh
adb shell setprop log.tag.BetterPlayerStreaming INFO
```

Robolectric tests cover device matching, early loader registration, preservation
of the existing injector on other TVs, and the final JNI initialization arguments
for foreground and background startup. JNI is replaced with a recorder in these
tests; they cannot establish playback correctness on NVIDIA hardware.
