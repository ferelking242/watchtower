#!/usr/bin/env bash
set -euo pipefail

# Install a previously built Flutter Linux bundle. This installs the actual
# Watchtower executable; the CLI is a mode of that executable, not a server.
PREFIX="${PREFIX:-/opt/watchtower}"
BUNDLE="${1:-}"

if [[ -z "$BUNDLE" || ! -x "$BUNDLE/watchtower" ]]; then
  echo "Usage: $0 /path/to/build/linux/x64/release/bundle" >&2
  exit 2
fi

if [[ ! -r "$BUNDLE/data/icudtl.dat" ]]; then
  echo "Invalid Flutter bundle: missing data/icudtl.dat" >&2
  exit 2
fi

if [[ "$(id -u)" -eq 0 ]]; then
  install -d "$PREFIX"
  cp -a "$BUNDLE"/. "$PREFIX"/
  install -d /usr/local/bin
  ln -sfn "$PREFIX/watchtower" /usr/local/bin/watchtower
else
  echo "Root is required to install into $PREFIX. Try:" >&2
  echo "  sudo PREFIX=$PREFIX $0 $BUNDLE" >&2
  exit 1
fi

echo "Installed Watchtower at $PREFIX"
echo "Headless CLI: /usr/local/bin/watchtower --cli help"