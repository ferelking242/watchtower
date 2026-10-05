---
name: Legacy extension removal
description: Compatibility boundaries when removing Mihon/APK extension runtime support.
---

Remove the Mihon/Aniyomi APK runtime and UI without changing the persisted Isar schema or deleting users' saved source records. Legacy APK source records must decode as unsupported and stay out of usable-source surfaces. Keep the proxy setting and old source metadata fields inert for database compatibility. Preserve Neko backup import; its historical protobuf schema may retain Mihon naming, but only Neko backups should be routed to it.

**Why:** Removing runtime support should not make existing local databases unreadable or discard the separately retained Neko backup-import path.

**How to apply:** When changing extension enums or settings, preserve serialized indices and schema fields unless there is a deliberate migration plan. Do not restore Mihon/Aniyomi runtime or backup-import routes unless the user changes scope.
