# FFmpeg management

Watchtower uses FFmpeg only for the final stream-copy mux of downloaded HLS
fragments (`MPEG-TS` to `MP4`). FFmpeg is not bundled in the Android APK.
The old FFmpeg AAR added a large native payload and made the release depend on
an abandoned packaging path.

## Runtime policy

- `FfmpegMergeService` is the only application-facing FFmpeg boundary.
- `FfmpegBinaryManager` checks an app-private executable on Android.
- Desktop builds may use the `ffmpeg` executable from the system PATH.
- Runtime downloads must use HTTPS and an immutable release URL.
- The downloaded file must match its published SHA-256 digest before activation.
- Downloads are written to a temporary file and renamed only after verification.

The Android app fails with an actionable message when no verified runtime is
present; it never executes an arbitrary or partially downloaded file.

The runtime binary must support the current command:

```text
-f concat -safe 0 -i <concat file> -map 0 -c copy -movflags +faststart
```

No transcoding codec is intentionally used. If the merge command changes,
verify that the selected runtime still contains every required demuxer and
muxer.

## Fallback without FFmpeg

FFmpeg is optional. When no verified executable is available, the downloader
concatenates the completed HLS fragments in playlist order. This is valid for
MPEG-TS streams and for fragmented MP4 playlists when the initialization
fragment is first. Online playback is unaffected, and the fallback avoids
blocking downloads on an external runtime.

## Runtime release procedure

1. Review the upstream source, release, license, Android ABI, and minimum API.
2. Publish an immutable ARM64 Android executable and its SHA-256 digest.
3. Pass the URL and digest to `installFromUrl`; never activate a URL without a
   digest.
4. Run the HLS regression tests and an Android build for the relevant variant.
5. Confirm that a real TS-to-MP4 stream-copy merge succeeds.
6. Keep the executable license and source-offer notices with the release.

## Licensing and distribution

Every FFmpeg runtime remains subject to its own license. Keep the corresponding
notices and source-offer obligations with every distributed build. Do not
silently switch between GPL and LGPL artifacts: the selected runtime,
documentation, and release notices must agree.

The `BinariesSection` is for the separately managed `aria2c` download only.
Any FFmpeg runtime release must provide a verified source, reproducible build or
immutable release asset, SHA-256 verification, architecture coverage, and
complete license information before it is used.