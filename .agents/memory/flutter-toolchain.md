---
name: Flutter toolchain verification
description: Version constraint for reliable local versus GitHub validation.
---

Use Flutter 3.47.2 (Dart 3.11+) for dependency resolution, analysis, and builds.

**Why:** The workspace-provided Flutter SDK can be older than the project's SDK constraint, so local `pub get` and analysis may produce misleading missing-package errors before Dart code is checked.

**How to apply:** Prefer the repository's GitHub Actions workflows for authoritative validation when the local SDK is below the `pubspec.yaml` minimum.