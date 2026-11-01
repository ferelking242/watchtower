---
name: Extension-owned behavior
description: Architectural boundary between extension-specific behavior and generic Watchtower UI.
---

Provider- and site-specific behavior (routes, filters, suggestions, and their visual options) belongs in that extension's code and layout. Watchtower should supply reusable UI and runtime APIs that any extension can opt into.

**Why:** the user asked that future extensions can declare their own filters and behaviors without adding provider-specific branches to the app.

**How to apply:** Add generic hooks and schema in Watchtower; implement site routes, option data, and opt-in layout metadata in `watchtower-extensions`.
