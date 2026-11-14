#!/bin/bash
# build_all.sh — Build the plugins Watchtower bundles into the app.
#
# Prerequisites:
#   dart pub global activate hetu_script_dev_tools 0.1.0+2
#
# The compiler version is PINNED on purpose. hetu_script_dev_tools >= 0.5
# emits bytecode in a format the hetu_script 0.4.2 runtime bundled in
# Watchtower cannot load ("LOAD_FAIL" on import). Never bump it without
# re-testing that the produced .smplug still loads in the app.
#
# Every plugin source lives in the single catalogue repository
# `ferelking242/watchtower-extensions` under `plugin-sources/<name>/`.
# This script compiles the two plugins that ship INSIDE the app bundle and
# writes them to `assets/plugins/<bundle-slug>/plugin.smplug`. The full
# catalogue build (all nine published plugins) is `plugin-sources/build_all.sh`
# in that repository.
#
# Usage:
#   ./tools/plugins/build_all.sh                 # both bundled plugins
#   ./tools/plugins/build_all.sh youtube         # one (substring match)
#   PLUGIN_SOURCES_DIR=/path/to/plugin-sources ./tools/plugins/build_all.sh
#
# Output:
#   assets/plugins/<bundle-slug>/plugin.smplug

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCES_DIR="${PLUGIN_SOURCES_DIR:-$REPO_ROOT/../watchtower-extensions/plugin-sources}"
HETU_DEV_TOOLS_VERSION="0.1.0+2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# <catalogue source dir>:<bundle slug written under assets/plugins/>
PLUGINS=(
  "youtube-audio:spotube-plugin-youtube-audio"
  "musicbrainz:spotube-plugin-musicbrainz-listenbrainz"
)

FILTER="${1:-}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Watchtower Bundled Music Plugins — Build        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

if ! command -v hetu &>/dev/null; then
  echo -e "${RED}✗ hetu compiler not found.${NC}"
  echo "  Install: dart pub global activate hetu_script_dev_tools $HETU_DEV_TOOLS_VERSION"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}✗ python3 not found (needed for plugin.json parsing + archive).${NC}"
  exit 1
fi

if [ ! -d "$SOURCES_DIR" ]; then
  echo -e "${RED}✗ plugin sources not found at: $SOURCES_DIR${NC}"
  echo "  Clone ferelking242/watchtower-extensions, or set PLUGIN_SOURCES_DIR."
  exit 1
fi

HETU_VERSION="$(hetu --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if [ "$HETU_VERSION" != "0.4.2" ]; then
  echo -e "${YELLOW}⚠ hetu compiler is $HETU_VERSION, expected 0.4.2.${NC}"
  echo -e "${YELLOW}  Bytecode from a newer compiler may not load in the app.${NC}"
  echo -e "${YELLOW}  Re-activate: dart pub global activate hetu_script_dev_tools $HETU_DEV_TOOLS_VERSION${NC}"
fi

echo -e "${YELLOW}Compiler: hetu $HETU_VERSION${NC}"
echo -e "${YELLOW}Sources:  $SOURCES_DIR${NC}"
echo ""

FAILED=0
BUILT=0
TOTAL=0

for entry in "${PLUGINS[@]}"; do
  SOURCE_NAME="${entry%%:*}"
  BUNDLE_SLUG="${entry##*:}"

  if [ -n "$FILTER" ] && [[ "$SOURCE_NAME" != *"$FILTER"* ]]; then
    continue
  fi

  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SOURCES_DIR/$SOURCE_NAME"

  if [ ! -d "$FULL_PATH" ]; then
    echo -e "${RED}✗ $SOURCE_NAME — source dir not found, skipping${NC}"
    FAILED=$((FAILED + 1))
    continue
  fi

  cd "$FULL_PATH"

  PLUGIN_NAME=$(python3 -c "import json; print(json.load(open('plugin.json'))['name'])" 2>/dev/null || echo "?")
  PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('plugin.json'))['version'])" 2>/dev/null || echo "?")
  PLUGIN_ABILITIES=$(python3 -c "import json; print(', '.join(json.load(open('plugin.json')).get('abilities',[])))" 2>/dev/null || echo "?")
  PLUGIN_ENTRY=$(python3 -c "import json; print(json.load(open('plugin.json')).get('entryPoint',''))" 2>/dev/null || echo "")

  echo -e "${CYAN}┌─ $PLUGIN_NAME${NC} ($SOURCE_NAME) v$PLUGIN_VERSION [$PLUGIN_ABILITIES]"

  # Step 1: Compile
  echo -n "│  Compiling... "
  mkdir -p build
  if OUTPUT=$(hetu compile src/plugin.ht build/plugin.out 2>&1); then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    echo "│  $OUTPUT" | head -5
    echo -e "└─"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Step 2: Verify not a stub
  STUB=$(head -c 11 build/plugin.out 2>/dev/null | tr -d '\0' || echo "")
  if [ "$STUB" = "WTPLUG_STUB" ]; then
    echo -e "│  ${RED}✗ Output is a WTPLUG_STUB — not real bytecode${NC}"
    echo -e "└─"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Step 3: Verify the manifest entryPoint is actually present in the bytecode.
  # The plugin loader looks the class up by name; a mismatch between
  # plugin.json#entryPoint and the class exported by src/plugin.ht makes the
  # plugin fail to load at runtime.
  if [ -n "$PLUGIN_ENTRY" ] && ! grep -q "$PLUGIN_ENTRY" build/plugin.out; then
    echo -e "│  ${RED}✗ entryPoint '$PLUGIN_ENTRY' not found in bytecode${NC}"
    echo -e "│    Check the export list in src/plugin.ht"
    echo -e "└─"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Step 4: Package .smplug (python3 zipfile — no system `zip` dependency)
  mkdir -p build/archive
  cp plugin.json build/archive/
  cp build/plugin.out build/archive/
  cp assets/logo.png build/archive/ 2>/dev/null || cp logo.png build/archive/ 2>/dev/null || true
  rm -f build/plugin.smplug
  python3 - "$PWD/build/archive" "$PWD/build/plugin.smplug" <<'PY'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(src)):
        z.write(os.path.join(src, name), name)
PY

  # Step 5: Install into the app bundle
  DEST_DIR="$REPO_ROOT/assets/plugins/$BUNDLE_SLUG"
  mkdir -p "$DEST_DIR"
  cp build/plugin.smplug "$DEST_DIR/plugin.smplug"

  BYTECODE_SIZE=$(wc -c < build/plugin.out)
  ARCHIVE_SIZE=$(wc -c < "$DEST_DIR/plugin.smplug")
  echo -e "│  ${GREEN}✓ Bytecode:${NC} ${BYTECODE_SIZE} bytes → ${GREEN}✓ assets/plugins/$BUNDLE_SLUG/plugin.smplug${NC} (${ARCHIVE_SIZE} bytes)"

  CONTENTS=$(python3 -c "import zipfile,sys; print(sum(n in ('plugin.json','plugin.out') for n in zipfile.ZipFile(sys.argv[1]).namelist()))" "$DEST_DIR/plugin.smplug" 2>/dev/null || echo 0)
  if [ "$CONTENTS" -ge 2 ]; then
    echo -e "│  ${GREEN}✓ Archive valid${NC} (plugin.json + plugin.out)"
  else
    echo -e "│  ${YELLOW}⚠ Archive may be incomplete${NC}"
  fi

  echo -e "└─"
  BUILT=$((BUILT + 1))
done

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "Total: $TOTAL  Built: ${GREEN}$BUILT${NC}  Failed: ${RED}$FAILED${NC}"
echo "═══════════════════════════════════════════════════"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
