# FFmpeg management

Watchtower uses FFmpeg only for the final stream-copy mux of downloaded HLS
fragments (`MPEG-TS` or `fMP4` to `MP4`). FFmpeg is **bundled** in the app as a
native library (`ffmpeg_kit_flutter_new`), so assembly works offline on Android,
iOS, macOS, Linux and Windows. There is no runtime download and no dependency on
a standalone `ffmpeg` executable.

## Bundled native FFmpeg

- `FfmpegMergeService` is the only application-facing FFmpeg boundary.
- `runFfmpeg` (in `ffmpeg_runner_io.dart`, selected through
  `ffmpeg_runner.dart`) is the only place that calls the native library.
- The Android artifact is `com.antonkarpenko:ffmpeg-kit-min-gpl`. `android/build.gradle`
  substitutes the `full-gpl` artifact requested by the plugin with `min-gpl`,
  which still contains every demuxer, muxer and filter the mux needs while
  keeping the APK small. Do not remove that substitution.
- The plugin's Android AAR requires `minSdkVersion 24`, so
  `android/app/build.gradle` keeps the application minimum at 24.

The bundled build must support the current command:

```text
-i <joined file> -map 0 -c copy -f mp4 -movflags +faststart <output>
```

Assembly is a single method with no fallback:

1. The downloader concatenates the completed fragments in playlist order into a
   temporary `<name>.mp4.part.joined` file. MPEG-TS fragments are defined to be
   joined this way, and a fragmented-MP4/CMAF playlist (its initialization
   fragment first) joins into a valid fragmented MP4 stream.
2. FFmpeg stream-copies the joined file into `<name>.mp4.part`, which is then
   renamed to the final file.
3. The temporary segment directory is deleted once the final MP4 exists.

Concatenating before FFmpeg is what makes one mux pass correct for both
containers. FFmpeg's `concat` *demuxer* re-probes each input as its own
container, so a bare fMP4 media segment (`moof`/`mdat` without a `moov`) is
rejected; the mux then exits 0 while writing a streamless ~260-byte file, which
reached the user as a corrupt download.

`-f mp4` is required, not optional. The mux target is `<name>.mp4.part` so an
interrupted mux cannot leave a truncated file in place of the final download,
and FFmpeg chooses the muxer from the output extension. `.part` is not a known
extension, so omitting `-f mp4` makes FFmpeg abort with `Unable to choose an
output format` (exit 234) — the mux fails and the download ends at 100% with no
playable file.

No transcoding codec is intentionally used. If the mux command changes, verify
that the bundled runtime still contains every required demuxer and muxer.

There is deliberately no fallback path. A silent fallback is what let a corrupt
file reach the user: assembly fails with an actionable error instead of writing
a raw concatenation that may not be a valid MP4.

## Upgrading the bundled FFmpeg

1. Review the upstream source, release, license, Android ABI, and minimum API.
2. Bump `ffmpeg_kit_flutter_new` in `pubspec.yaml` and run `flutter pub get`.
3. Confirm the `android/build.gradle` substitution still maps the plugin's
   requested artifact to `ffmpeg-kit-min-gpl`.
4. Confirm the AAR still contains the `mpegts`, `mov`/`mp4`, `concat`, `hls` and
   `aac_adtstoasc` components.
5. Run the HLS regression tests and an Android build for the relevant variant.
6. Confirm that a real TS-to-MP4 stream-copy mux succeeds, and check the release
   APK size stays within the CI budget.

## Licensing and distribution

The bundled FFmpeg build is licensed under the GPL (it is built from the GPL
variant). Keep the corresponding notices and source-offer obligations with every
distributed build. Do not silently switch between GPL and LGPL artifacts: the
selected build, documentation, and release notices must agree.

The `BinariesSection` is for the separately managed `aria2c` download only.
