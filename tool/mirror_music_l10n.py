#!/usr/bin/env python3
"""Mirrors the music module's template keys into every music locale ARB.

`lib/modules/music/l10n/app_en.arb` is the gen-l10n template. A locale that
omits a key still compiles (gen-l10n emits an English fallback), but the key
never appears in the locale file, so translators never see it and
`untranslated_music.txt` keeps reporting it. This tool appends every template
key a locale is missing with the English wording, preserving the file's
hand-maintained key order.

Idempotent: only absent keys are appended. Run from the repository root, then
`./tools/gen_l10n.sh`.
"""
import json
import os

MUSIC_DIR = "lib/modules/music/l10n"
TEMPLATE = "app_en.arb"


def template_entries():
    raw = open(os.path.join(MUSIC_DIR, TEMPLATE), encoding="utf-8").read()
    data = json.loads(raw)
    # Keep declaration order; drop the "@key" metadata entries.
    return [(k, v) for k, v in data.items() if not k.startswith("@")]


def append_missing(path, entries):
    raw = open(path, encoding="utf-8").read()
    data = json.loads(raw)
    missing = [(k, v) for k, v in entries if k not in data]
    if not missing:
        return None
    prefix = raw.rstrip()[:-1].rstrip()
    if not prefix.endswith(","):
        prefix += ","
    block = "\n".join(
        "  " + json.dumps(k, ensure_ascii=False) + ": " + json.dumps(v, ensure_ascii=False) + ","
        for k, v in missing
    ).rstrip(",")
    out = prefix + "\n" + block + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    return [k for k, _ in missing]


def main():
    entries = template_entries()
    for name in sorted(os.listdir(MUSIC_DIR)):
        if not name.endswith(".arb") or name == TEMPLATE:
            continue
        added = append_missing(os.path.join(MUSIC_DIR, name), entries)
        if added:
            print(f"{name}: +{len(added)} keys")
        else:
            print(f"{name}: up to date")


if __name__ == "__main__":
    main()
