---
name: Reader volume-key routing
description: Reliability constraints for Android hardware volume keys in the manga reader.
---

Android must consume volume keys as soon as the reader requests page navigation, even if the Dart `EventChannel` sink has not attached yet. Queue a short, bounded set of initial key-down directions and deliver them when the sink attaches. Clear the queue when the preference is disabled. Keep Flutter's global `HardwareKeyboard` handler as a fallback, and do not handle volume keys in the Focus callback; otherwise one physical press can turn two pages. Mihon uses a focused Compose root with `onPreviewKeyEvent` and explicitly requests focus; Watchtower's Android bridge must still protect the system-volume boundary independently of focus.

**Why:** The reader's focus-based fallback did not reliably claim hardware keys, and the later global handler alone did not eliminate the reported system-volume behavior. A requested key must never fall through to Android's system-volume behavior while the native bridge is waiting for Dart.

**How to apply:** Trace failures through the `ReaderVolumeKeys` logs: request state, sink readiness, native interception/queueing, Flutter delivery, and the reason navigation did or did not move. Keep handler registration and removal paired by callback identity.
