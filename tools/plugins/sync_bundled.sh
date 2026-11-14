#!/bin/bash
# sync_bundled.sh — Refresh the two bundled plugin artifacts from the catalogue.
#
# Watchtower ships two plugins inside the app bundle so the first launch has a
# working audio source and metadata provider without downloading anything.
# Their sources live in `ferelking242/watchtower-extensions` under
# `plugin-sources/`; this is a thin convenience wrapper around build_all.sh.
#
# Usage:
#   PLUGIN_SOURCES_DIR=/path/to/plugin-sources ./tools/plugins/sync_bundled.sh
#   ./tools/plugins/sync_bundled.sh            # auto-detect a sibling checkout

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/build_all.sh" "$@"
