#!/bin/bash
# gen_l10n.sh — Regenerate BOTH localization sets.
#
# Watchtower has two independent ARB sets:
#   • lib/l10n                → the app's own strings (root l10n.yaml)
#   • lib/modules/music/l10n  → the embedded music module's strings
#
# `flutter gen-l10n` only reads the single l10n.yaml at the project root, so
# the music set can only be produced by temporarily pointing l10n.yaml at it.
# This script does that swap and restores the original file afterwards.
#
# Usage:  ./tools/gen_l10n.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

L10N_YAML="l10n.yaml"
BACKUP="$(mktemp)"
cp "$L10N_YAML" "$BACKUP"
restore() { cp "$BACKUP" "$L10N_YAML"; rm -f "$BACKUP"; }
trap restore EXIT

echo "▶ App strings (lib/l10n)"
flutter gen-l10n

echo "▶ Music module strings (lib/modules/music/l10n)"
cat > "$L10N_YAML" <<'YAML'
arb-dir: lib/modules/music/l10n
template-arb-file: app_en.arb
untranslated-messages-file: untranslated_music.txt
output-localization-file: app_localizations.dart
output-dir: lib/modules/music/l10n/generated
YAML
flutter gen-l10n

echo "✓ Localizations regenerated"
