#!/usr/bin/env bash
set -euo pipefail

# Post-merge setup must be safe in both Replit and GitHub-style environments.
# Dependencies are already cached in most merges; refresh them when Flutter is
# available, but do not make a merge fail merely because this lightweight
# workspace has no Flutter SDK installed.
if command -v flutter >/dev/null 2>&1; then
  flutter pub get --no-example
elif command -v dart >/dev/null 2>&1; then
  dart pub get
else
  echo "Flutter/Dart SDK not available; dependency refresh skipped."
fi