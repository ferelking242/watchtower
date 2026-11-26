#!/usr/bin/env python3
"""Build the changelog published with each Android release.

The in-app update screen renders this markdown, so the output is limited to
section headings, bullets and one short detail line per bullet.
"""

from __future__ import annotations

import re
import subprocess
import sys

SECTIONS = (
    ("✨ Nouveautés", {"feat", "feature"}),
    ("🚀 Améliorations", {"perf", "polish", "refactor", "improve", "ui", "style"}),
    ("🐛 Corrections", {"fix", "hotfix", "bugfix"}),
    ("🔧 Maintenance", {"chore", "docs", "build", "ci", "test", "revert"}),
)

SUBJECT = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?!?:\s*(?P<text>.+)$"
)
SKIPPED_DETAIL_PREFIXES = ("co-authored-by:", "signed-off-by:", "see ", "refs ")


def read_commits(rev_range: str) -> list[tuple[str, str]]:
    """Subjects and bodies of the commits in [rev_range], oldest first."""
    output = subprocess.run(
        ["git", "log", "--no-merges", "--pretty=format:%s%x1f%b%x1e", rev_range],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    commits: list[tuple[str, str]] = []
    for record in output.split("\x1e"):
        record = record.strip("\n")
        if not record.strip():
            continue
        subject, _, body = record.partition("\x1f")
        commits.append((subject.strip(), body.strip()))
    commits.reverse()
    return commits


def first_detail(body: str) -> str | None:
    for line in body.splitlines():
        line = line.strip().lstrip("-*+ ").strip()
        if not line or line.startswith("#"):
            continue
        if line.lower().startswith(SKIPPED_DETAIL_PREFIXES):
            continue
        line = " ".join(line.split())
        if len(line) < 25:
            continue
        if len(line) > 180:
            line = line[:177].rsplit(" ", 1)[0] + "…"
        return line
    return None


def bullet(subject: str, body: str) -> tuple[str, str]:
    """(type, markdown bullet) for one commit."""
    match = SUBJECT.match(subject)
    if not match:
        text = subject.strip()
        return "", f"- {text[0].upper() + text[1:]}" if text else ""

    kind = match.group("type").lower()
    scope = match.group("scope")
    text = match.group("text").strip()
    text = text[0].upper() + text[1:]
    entry = f"- **{scope}** : {text}" if scope else f"- {text}"
    detail = first_detail(body)
    if detail:
        entry += f"\n  {detail}"
    return kind, entry


def render(rev_range: str) -> str:
    buckets: dict[str, list[str]] = {title: [] for title, _ in SECTIONS}
    others: list[str] = []
    try:
        commits = read_commits(rev_range)
    except subprocess.CalledProcessError as error:
        print(error, file=sys.stderr)
        commits = []
    # `android-latest` is moved to the commit being released, so the range is
    # empty on a rolling-release build. Fall back to the recent history.
    for subject, body in commits or read_commits("-20"):
        kind, entry = bullet(subject, body)
        if not entry:
            continue
        target = next((title for title, kinds in SECTIONS if kind in kinds), None)
        (buckets[target] if target else others).append(entry)

    parts = [
        f"### {title}\n\n" + "\n".join(buckets[title])
        for title, _ in SECTIONS
        if buckets[title]
    ]
    if others:
        parts.append("### 📦 Autres\n\n" + "\n".join(others))
    return "\n\n".join(parts)


def main() -> int:
    rev_range = sys.argv[1] if len(sys.argv) > 1 else "-20"
    print(render(rev_range))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
