#!/bin/bash
# build_all.sh — Build all Watchtower music plugins
#
# Prerequisites:
#   dart pub global activate hetu_script_dev_tools
#
# Usage:
#   ./tools/plugins/build_all.sh                  # Build all plugins
#   ./tools/plugins/build_all.sh spotify           # Build one plugin
#   PLUGIN_REPOS_DIR=/path/to/repos ./tools/plugins/build_all.sh
#
# Output:
#   Each plugin gets build/<name>.smplug in its directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_DIR="${PLUGIN_REPOS_DIR:-/tmp/plugins_build}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PLUGINS=(
  "spotube-plugin-spotify"
  "spotube-plugin-applemusic"
  "spotube-plugin-deezer"
  "spotube-plugin-youtube-music"
)

FILTER="${1:-}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Watchtower Music Plugins — Build All            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v hetu &>/dev/null; then
  echo -e "${RED}✗ hetu compiler not found.${NC}"
  echo "  Install: dart pub global activate hetu_script_dev_tools"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}✗ python3 not found (needed for plugin.json parsing).${NC}"
  exit 1
fi

echo -e "${YELLOW}Compiler: hetu $(hetu --version)${NC}"
echo -e "${YELLOW}Repos dir: $REPOS_DIR${NC}"
echo ""

FAILED=0
BUILT=0
TOTAL=0

for plugin_dir in "${PLUGINS[@]}"; do
  # Apply filter if provided
  if [ -n "$FILTER" ] && [[ "$plugin_dir" != *"$FILTER"* ]]; then
    continue
  fi

  TOTAL=$((TOTAL + 1))
  FULL_PATH="$REPOS_DIR/$plugin_dir"

  if [ ! -d "$FULL_PATH" ]; then
    echo -e "${RED}✗ $plugin_dir — directory not found, skipping${NC}"
    FAILED=$((FAILED + 1))
    continue
  fi

  cd "$FULL_PATH"

  PLUGIN_NAME=$(python3 -c "import json; print(json.load(open('plugin.json'))['name'])" 2>/dev/null || echo "?")
  PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('plugin.json'))['version'])" 2>/dev/null || echo "?")
  PLUGIN_ABILITIES=$(python3 -c "import json; print(', '.join(json.load(open('plugin.json')).get('abilities',[])))" 2>/dev/null || echo "?")

  echo -e "${CYAN}┌─ $PLUGIN_NAME${NC} ($plugin_dir) v$PLUGIN_VERSION [$PLUGIN_ABILITIES]"

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
  STUB=$(head -c 11 build/plugin.out 2>/dev/null || echo "")
  if [ "$STUB" = "WTPLUG_STUB" ]; then
    echo -e "│  ${RED}✗ Output is a WTPLUG_STUB — not real bytecode${NC}"
    echo -e "└─"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Step 3: Package .smplug
  mkdir -p build/archive
  cp plugin.json build/archive/
  cp build/plugin.out build/archive/
  cp assets/logo.png build/archive/ 2>/dev/null || true
  cd build/archive
  rm -f ../plugin.smplug
  zip -q -r ../plugin.smplug .
  cd ../..

  BYTECODE_SIZE=$(wc -c < build/plugin.out)
  ARCHIVE_SIZE=$(wc -c < build/plugin.smplug)
  echo -e "│  ${GREEN}✓ Bytecode:${NC} ${BYTECODE_SIZE} bytes → ${GREEN}✓ Archive:${NC} ${ARCHIVE_SIZE} bytes"

  # Step 4: Verify archive contents
  CONTENTS=$(unzip -l build/plugin.smplug 2>/dev/null | grep -c "plugin\.\(json\|out\)")
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
