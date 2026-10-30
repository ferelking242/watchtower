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
-i <joined file> -map 0 -c copy -f mp4 -movflags +faststart <output>
```

Assembly is a single method with no fallback:

1. The downloader concatenates the completed fragments in playlist order into a
   temporary `<name>.mp4.part.joined` file. MPEG-TS fragments are defined to be
   joined this way, and a fragmented-MP4/CMAF playlist (its initialization
   fragment first) joins into a valid fragmented MP4 stream.
2. FFmpeg stream-copies the joined file into `<name>.mp4.part`, which is then
   renamed to the final file.

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
that the selected runtime still contains every required demuxer and muxer.

There is deliberately no fallback path. When no verified FFmpeg runtime is
available, assembly fails with an actionable error instead of silently writing
a raw concatenation that may not be a valid MP4.

## Runtime release procedure

1. Review the upstream source, release, license, Android ABI, and minimum API.
2. Publish an immutable ARM64 Android executable and its SHA-256 digest.
3. Pass the URL and digest to `installFromUrl`; never activate a URL without a
   digest.
4. Run the HLS regression tests and an Android build for the relevant variant.
5. Confirm that a real TS-to-MP4 stream-copy mux succeeds.
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