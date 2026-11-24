#!/usr/bin/env bash
# Pulls the latest Reel shell into this checkout.
#
# Reel lives in its own repository (ferelking242/reel) and is mounted here as a
# submodule: the app ships one copy of the shell, tests and releases included.
# Run this after a Reel release, then commit the new pointer.
set -euo pipefail

cd "$(dirname "$0")/.."

git submodule update --init --recursive reel
git submodule update --remote -- reel
flutter pub get

echo "Reel: $(git -C reel log --oneline -1)"
echo "Commit the 'reel' pointer with: git add reel && git commit -m 'chore(reel): bump shell'"
