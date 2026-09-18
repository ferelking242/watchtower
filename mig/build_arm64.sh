#!/usr/bin/env bash
set -euo pipefail

# Build in a temporary Flutter project so Watchtower's Rust, media, backend
# and platform plugins cannot be linked accidentally.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

flutter create \
  --platforms=android \
  --project-name=watchtower_mig_preview \
  --org=com.watchtower \
  --no-pub \
  "$BUILD_DIR"
cp "$ROOT/mig/pubspec.yaml" "$BUILD_DIR/pubspec.yaml"
rm -rf "$BUILD_DIR/lib"
cp -R "$ROOT/mig/lib" "$BUILD_DIR/lib"

cd "$BUILD_DIR"
flutter pub get
flutter build apk \
  --release \
  --target-platform android-arm64 \
  --tree-shake-icons \
  --split-debug-info="$ROOT/build/mig-symbols"

cp build/app/outputs/flutter-apk/app-release.apk \
  "$ROOT/build/Watchtower-mig-arm64-preview.apk"
echo "APK: $ROOT/build/Watchtower-mig-arm64-preview.apk"