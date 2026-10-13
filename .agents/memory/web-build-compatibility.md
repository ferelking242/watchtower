---
name: Web build compatibility shims
description: Keep the GitHub Pages Web build's restored legacy stubs aligned with current source APIs.
---

The Pages workflow restores an older web-stub tree from repository history and applies build-only compatibility patches. Shared source can outgrow those stubs even when the native build still works.

**Why:** Re-enabling the Web workflow exposed a missing `HomeWidget` callback in the restored stub and a mismatch between the Web `dart:io` `RandomAccessFile` type and shared CBZ code that uses native sync methods.

**How to apply:** When Web CI reports API or type errors in conditional imports, inspect the compatibility script in the Pages workflow as well as application code. Keep native behavior intact; use a targeted Web shim or conditional implementation rather than masking unrelated failures.
