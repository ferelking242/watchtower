---
name: Stale filter indices
description: Prevent range errors when saved filter selections outlive dynamic option lists.
---

Persisted filter selections can outlive the current `values` list when extensions or other dynamic sources refresh their options. Treat every stored selection index as untrusted before using it to index the current options; clamp it to a valid item or show an explicit empty selection.

**Why:** A reported range mismatch involved index 62 with only 59 values available. The same state/options mismatch can recur after a refresh. The download error did not include symbolized Dart frames, so this risk should not be treated as the confirmed sole cause.

**How to apply:** Guard selection and sort index reads wherever option lists may change, and keep regression coverage where the stored index is outside the current list.