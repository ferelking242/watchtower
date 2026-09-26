---
name: Smart Library scan boundaries
description: Product boundary between the local Watch video scanner and the local Manga scanner.
---

Smart Library has two intentionally disjoint local scan modes:

- Watch indexes video extensions only.
- Manga indexes comic archives and manga page folders organized by chapter or volume.
- EPUB/MOBI and other novel formats are not part of either Smart Library surface.
- Manga page folders produce one representative index entry per chapter/volume folder, not one entry per image.
- The all-files Android permission is requested from the Permissions/onboarding page; Smart Library must not open a second permission dialog.

**Why:** The user needs separate Watch and Manga libraries, and broad shared discovery caused videos, novels, and page images to leak into the wrong surface.

**How to apply:** Any future local-indexer change should add an explicit mode/policy or preserve the existing mode boundary rather than expanding a shared "all media" extension set.