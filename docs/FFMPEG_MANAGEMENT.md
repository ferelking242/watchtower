# FFmpeg management

Watchtower uses FFmpeg only for the final stream-copy mux of downloaded HLS
fragments (`MPEG-TS` to `MP4`). The application does not download or execute a
third-party FFmpeg binary at runtime.

## Current implementation

- Dart package: `ffmpeg_kit_flutter_new`
- Reviewed version: `4.6.2`
- Package source: `https://github.com/sk3llo/ffmpeg_kit_flutter`
- Package archive: `https://pub.dev/packages/ffmpeg_kit_flutter_new/versions/4.6.2`
- Android artifact selected by Gradle: `com.antonkarpenko:ffmpeg-kit-min-gpl`
- Android ABI shipped by the application: `arm64-v8a`
- Minimum Android API: 24

The dependency is pinned in `pubspec.yaml`, rather than using a caret range.
The lockfile records the hosted package digest. FFmpeg calls are isolated in
`FfmpegMergeService`; the HLS downloader only depends on that application
boundary.

The min-GPL artifact is sufficient for the current command:

```text
-f concat -safe 0 -i <concat file> -map 0 -c copy -movflags +faststart
```

No transcoding codec is intentionally used. If the merge command changes,
verify that the selected artifact still contains every required demuxer and
muxer before changing the Gradle substitution.

## Upgrade procedure

1. Review the upstream release, source repository, package archive, and
   licensing information.
2. Verify the Android artifact coordinates, supported API level, and native
   ABIs. Do not replace this dependency with an unverified binary archive.
3. Update `pubspec.yaml` to one exact version and run `flutter pub get`.
4. Inspect the resulting `pubspec.lock` digest and the resolved Android
   dependencies.
5. Run the HLS regression tests and an Android build for the relevant variant.
6. Confirm the generated APK contains only the intended native ABI and that
   a real TS-to-MP4 stream-copy merge succeeds.
7. Update this document with the new version and re-check all license notices
   shipped with the application.

## Licensing and distribution

The FFmpeg package and Android artifact remain subject to their own licenses.
Keep the corresponding notices and source-offer obligations with every
distributed build. Do not silently switch between GPL and LGPL artifacts:
the selected artifact, Gradle rule, documentation, and release notices must
agree.

The `BinariesSection` is for the separately managed `aria2c` download only.
FFmpeg is not presented there as a downloadable or bundled user-managed
binary. A future replacement must provide a verified source, reproducible
build or immutable release asset, SHA-256 verification, architecture
coverage, and complete license information before it is considered.