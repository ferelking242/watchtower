#!/usr/bin/env bash
set -euo pipefail

# The migration preview intentionally builds through Watchtower's existing
# Android scaffold. It uses mig/lib/main.dart as its entrypoint, so no
# FlixQuest backend, Firebase, ads or player code is linked.
flutter pub get
flutter build apk \
  --release \
  --target mig/lib/main.dart \
  --target-platform android-arm64 \
  --tree-shake-icons \
  --split-debug-info=build/mig-symbols

echo "APK: build/app/outputs/flutter-apk/app-release.apk"