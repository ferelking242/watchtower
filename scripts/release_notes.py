#!/usr/bin/env python3
"""Generate clean, Mihon-style release notes from the git history.

Groups commits between the previous release tag and HEAD by conventional
commit type, drops the noise (merge commits, release/tag bookkeeping), and
renders a tidy Markdown body with a download table.

Usage:
    release_notes.py --version 8.1.729 --build 729 --sha abc1234 \
        --from-tag v8.1.728-b728 --output notes.md \
        --asset "Android arm64:Watchtower-8.1.729-android-arm64.apk" ...

The commit range defaults to the most recent `v*` tag reachable from HEAD,
so an untagged repository simply shows the full history.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

# Conventional-commit type -> (section title, order, emoji).
# Only user-facing types are listed; docs/chore/ci/test/build/style are
# deliberately omitted so the notes stay clean (no bookkeeping noise).
SECTIONS = {
    "feat": ("Nouveautés", 0, "✨"),
    "fix": ("Corrections", 1, "🐛"),
    "perf": ("Performances", 2, "⚡"),
    "refactor": ("Améliorations", 3, "♻️"),
}
OTHER = ("Autres", 4, "🔹")

# Per-section cap so one busy area cannot turn the notes into a wall of text.
MAX_PER_SECTION = 30

# Hard cap on the number of commits considered. The last version tag can be
# hundreds of commits behind, and a rolling release should describe what
# changed recently — not replay the whole history.
MAX_COMMITS = 60

# Subjects that are pure release bookkeeping and must never reach the notes.
NOISE = re.compile(
    r"^(merge\b|revert \"?merge|source update:|chore\(release\)|"
    r"add files via upload|upload files|initial commit|"
    r"(create|update|delete) [\w./-]+\.[A-Za-z0-9]+$|"
    r"release:\s|v?\d+\.\d+\.\d+\+?\d*\s*$)",
    re.IGNORECASE,
)

HEADER = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?:\s*(?P<desc>.+)$"
)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout.strip()


def latest_tag() -> str | None:
    try:
        tags = git("tag", "--sort=-creatordate", "--merged", "HEAD").splitlines()
    except subprocess.CalledProcessError:
        return None
    for tag in tags:
        if re.match(r"^v\d", tag):
            return tag
    return None


def commit_subjects(rev_range: str | None) -> list[str]:
    args = ["log", "--no-merges", "--pretty=format:%s", f"-{MAX_COMMITS}"]
    if rev_range:
        args.append(rev_range)
    out = git(*args)
    return [line for line in out.splitlines() if line.strip()]


def classify(subjects: list[str]) -> dict[str, list[str]]:
    buckets: dict[str, list[str]] = {}
    for subject in subjects:
        subject = subject.strip()
        if NOISE.match(subject):
            continue
        match = HEADER.match(subject)
        if match:
            ctype = match.group("type").lower()
            # Drop bookkeeping types entirely (docs/chore/ci/test/build/style…)
            if ctype not in SECTIONS:
                continue
            scope = match.group("scope")
            desc = match.group("desc").strip()
            key = ctype
            text = f"**{scope}** — {desc}" if scope else desc
            if match.group("breaking"):
                text = f"⚠️ **rupture** — {text}"
        else:
            # Untyped commits are usually user-facing changes; keep them in a
            # catch-all rather than lose a real fix.
            key = "__other__"
            text = subject
        buckets.setdefault(key, []).append(text[0].upper() + text[1:])
    return buckets


def render(
    version: str,
    build: str,
    sha: str,
    buckets: dict[str, list[str]],
    assets: list[tuple[str, str]],
    date: str,
) -> str:
    lines = [f"# Watchtower {version}", ""]
    short = sha[:7] if sha else "local"
    lines.append(
        f"Build automatique depuis `main` — commit `{short}` — {date}."
    )
    lines.append("")

    ordered = sorted(
        buckets.items(),
        key=lambda kv: SECTIONS.get(kv[0], OTHER)[1],
    )
    for key, items in ordered:
        if not items:
            continue
        title, _, emoji = SECTIONS.get(key, OTHER)
        lines.append(f"## {emoji} {title}")
        shown = items[:MAX_PER_SECTION]
        lines.extend(f"- {item}" for item in shown)
        if len(items) > MAX_PER_SECTION:
            lines.append(f"- … et {len(items) - MAX_PER_SECTION} autre(s)")
        lines.append("")

    if assets:
        lines.append("## 📥 Téléchargements")
        lines.append("")
        lines.append("| Plateforme | Fichier |")
        lines.append("| --- | --- |")
        for label, name in assets:
            lines.append(f"| {label} | `{name}` |")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(
        "_Notes générées automatiquement à partir des commits "
        "conventionnels._"
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", default="")
    parser.add_argument("--sha", default="")
    parser.add_argument("--date", default="")
    parser.add_argument("--from-tag", default="")
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--asset",
        action="append",
        default=[],
        help="Label:filename pairs attached to the release.",
    )
    args = parser.parse_args()

    base = args.from_tag.strip() or latest_tag()
    rev_range = f"{base}..HEAD" if base else None
    subjects = commit_subjects(rev_range)
    buckets = classify(subjects)

    assets: list[tuple[str, str]] = []
    for raw in args.asset:
        label, _, name = raw.partition(":")
        assets.append((label.strip(), name.strip() or label.strip()))

    body = render(
        args.version, args.build, args.sha, buckets, assets, args.date
    )
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(body + "\n")
    sys.stderr.write(f"release notes written to {args.output}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
