#!/usr/bin/env bash
set -euo pipefail

# Install a Flutter Linux bundle or a .7z archive containing one. The CLI is
# a mode of the real Watchtower executable, not a separate mock server.
#
# Examples:
#   sudo ./install-linux-headless.sh watchtower-linux-x64.7z
#   ./install-linux-headless.sh watchtower-linux-x64.7z --prefix "$HOME/.local/share/watchtower"
#   sudo PREFIX=/opt/watchtower ./install-linux-headless.sh ./bundle

usage() {
  cat >&2 <<'USAGE'
Usage: install-linux-headless.sh <bundle-dir|archive.7z> [--prefix DIR]

Installs the Watchtower Linux bundle and exposes:
  watchtower --cli help
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

INPUT="$1"
shift
if [[ "${1:-}" == "--prefix" ]]; then
  [[ -n "${2:-}" ]] || { usage; exit 2; }
  PREFIX="$2"
  shift 2
else
  PREFIX="${PREFIX:-${WATCHTOWER_PREFIX:-}}"
fi
[[ $# -eq 0 ]] || { usage; exit 2; }

if [[ -z "$PREFIX" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    PREFIX="/opt/watchtower"
  else
    PREFIX="${HOME}/.local/share/watchtower"
  fi
fi

TMP_DIR=""
cleanup() {
  [[ -z "$TMP_DIR" ]] || rm -rf "$TMP_DIR"
}
trap cleanup EXIT

BUNDLE="$INPUT"
if [[ -f "$INPUT" ]]; then
  case "$INPUT" in
    *.7z)
      command -v 7z >/dev/null 2>&1 || {
        echo "7z is required to install a .7z archive." >&2
        exit 1
      }
      TMP_DIR="$(mktemp -d)"
      7z x -y "$INPUT" "-o$TMP_DIR" >/dev/null
      BUNDLE="$(find "$TMP_DIR" -type f -name watchtower -print -quit)"
      [[ -n "$BUNDLE" ]] || {
        echo "Archive does not contain a watchtower executable." >&2
        exit 2
      }
      BUNDLE="$(dirname "$BUNDLE")"
      ;;
    *)
      echo "Input must be a bundle directory or a .7z archive." >&2
      exit 2
      ;;
  esac
fi

if [[ ! -x "$BUNDLE/watchtower" ]]; then
  echo "Invalid Flutter bundle: missing executable $BUNDLE/watchtower" >&2
  exit 2
fi
if [[ ! -r "$BUNDLE/data/icudtl.dat" ]]; then
  echo "Invalid Flutter bundle: missing data/icudtl.dat" >&2
  exit 2
fi

LINK_DIR="${WATCHTOWER_BIN_DIR:-}"
if [[ -z "$LINK_DIR" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    LINK_DIR="/usr/local/bin"
  else
    LINK_DIR="${HOME}/.local/bin"
  fi
fi

install -d "$PREFIX"
cp -a "$BUNDLE"/. "$PREFIX"/
install -d "$LINK_DIR"
ln -sfn "$PREFIX/watchtower" "$LINK_DIR/watchtower"

echo "Installed Watchtower at $PREFIX"
echo "Binary: $LINK_DIR/watchtower"
echo "Headless CLI: $LINK_DIR/watchtower --cli help"
if [[ ":$PATH:" != *":$LINK_DIR:"* ]]; then
  echo "Add $LINK_DIR to PATH if the watchtower command is not found."
fi