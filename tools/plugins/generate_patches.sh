#!/bin/bash
# generate_patches.sh — Generate patch files for each plugin repo
#
# This script creates ready-to-apply patches for the 4 music plugin repos.
# Each patch includes: fixed Makefile, CI workflow, .gitignore
#
# Usage:
#   ./tools/plugins/generate_patches.sh
#
# Output:
#   tools/plugins/patches/<plugin-name>.patch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"
BUILD_DIR="/tmp/plugins_build"
REPOS_DIR="${PLUGIN_REPOS_DIR:-$BUILD_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

mkdir -p "$PATCHES_DIR"

PLUGINS=(
  "spotube-plugin-spotify"
  "spotube-plugin-applemusic"
  "spotube-plugin-deezer"
  "spotube-plugin-youtube-music"
)

echo "Generating patches..."

for plugin in "${PLUGINS[@]}"; do
  FULL_PATH="$REPOS_DIR/$plugin"
  if [ ! -d "$FULL_PATH" ]; then
    echo -e "${RED}✗ $plugin — not found, skipping${NC}"
    continue
  fi

  cd "$FULL_PATH"

  # Create the files that need to change
  # 1. Makefile
  cat > /tmp/makefile_new << 'ENDMAKE'
.PHONY: compile archive clean

compile:
	mkdir -p build
	hetu compile src/plugin.ht build/plugin.out

archive: compile
	mkdir -p build/archive
	cp plugin.json build/plugin.out build/archive/
	cp assets/logo.png build/archive/ 2>/dev/null || true
	cd build/archive && rm -f ../plugin.smplug && zip -q -r ../plugin.smplug .
	cp build/plugin.smplug .
	@echo "✓ plugin.smplug"

clean:
	rm -rf build plugin.smplug
ENDMAKE

  # 2. .gitignore
  cat > /tmp/gitignore_new << 'ENDGIT'
build/
dist/
plugin.smplug
*.smplug
ENDGIT

  # 3. CI workflow (copy from template)
  cp "$SCRIPT_DIR/ci_template.yml" /tmp/ci_new.yml

  # Generate patch
  PATCH_FILE="$PATCHES_DIR/$plugin.patch"
  {
    echo "--- a/Makefile"
    diff -u /dev/null /tmp/makefile_new 2>/dev/null || true
    echo "--- a/.gitignore"
    diff -u /dev/null /tmp/gitignore_new 2>/dev/null || true
    echo "--- a/.github/workflows/build.yml"
    diff -u /dev/null /tmp/ci_new.yml 2>/dev/null || true
  } > "$PATCH_FILE"

  echo -e "${GREEN}✓${NC} $PATCH_FILE"
done

echo ""
echo "Apply patches with:"
echo "  cd <plugin-repo>"
echo "  git apply < patch-file.patch"
