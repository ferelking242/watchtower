"""Iteratively delete declarations the Dart analyzer proves unreachable.

`flutter analyze` reports the *root* of a dead subgraph: a legacy helper that
nothing calls, even when it still references other legacy widgets. Deleting that
root makes the next declaration in the chain unreachable, so repeating the
analyze/delete cycle peels the whole legacy surface without ever guessing at
reachability by hand.

Only `unused_element` warnings are acted on, and each round re-analyzes before
touching anything, so a declaration is removed only once the analyzer has
confirmed that nothing names it.
"""

from __future__ import annotations

import re
import subprocess
import sys

FILE = "lib/modules/browse/marketplace_screen.dart"
DECL_RE = re.compile(r"^(?:class|enum|mixin|typedef|extension)\s+(\w+)")
MEMBER_RE = re.compile(
    r"^  (?:@override\s+)?(?:static\s+)?(?:const\s+)?"
    r"[\w<>,\?\[\]\. ]+?\s(\w+)\s*(?:\(|=|=>|;)"
)
WARN_RE = re.compile(
    r"The declaration '(\w+)' isn't referenced.*?" + re.escape(FILE) + r":(\d+):"
)
SKIP = {"if", "for", "while", "switch", "return", "assert"}


def analyse() -> list[tuple[str, int]]:
    out = subprocess.run(
        ["flutter", "analyze", "--no-pub", FILE],
        capture_output=True,
        text=True,
    ).stdout
    return [(m.group(1), int(m.group(2))) for m in WARN_RE.finditer(out)]


def units(lines: list[str]) -> list[tuple[int, int, str]]:
    tops = [
        (i, DECL_RE.match(l).group(1)) for i, l in enumerate(lines) if DECL_RE.match(l)
    ]
    spans = [
        (i, tops[k + 1][0] if k + 1 < len(tops) else len(lines), name)
        for k, (i, name) in enumerate(tops)
    ]

    state = next(i for i, l in enumerate(lines) if l.startswith("class _MarketplaceScreenState"))
    end = next(i for i, l in enumerate(lines) if i > state and DECL_RE.match(l))
    body = lines[state:end]
    starts = [
        (idx, MEMBER_RE.match(l).group(1))
        for idx, l in enumerate(body)
        if MEMBER_RE.match(l)
        and not l.startswith("   ")
        and MEMBER_RE.match(l).group(1) not in SKIP
    ]
    for k, (idx, name) in enumerate(starts):
        stop = starts[k + 1][0] if k + 1 < len(starts) else len(body)
        spans.append((state + idx, state + stop, name))
    return spans


def main() -> int:
    rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    for round_no in range(1, rounds + 1):
        warned = analyse()
        if not warned:
            print(f"round {round_no}: nothing left to remove")
            break
        lines = open(FILE, encoding="utf-8").read().split("\n")
        spans = units(lines)
        spans.sort()

        targets = []
        for name, line in warned:
            match = [s for s in spans if s[2] == name]
            if not match:
                print(f"  ! could not locate span for {name} (line {line})")
                continue
            start, stop, _ = match[0]
            targets.append((start, stop, name))

        targets.sort()
        merged: list[list] = []
        for s, e, n in targets:
            if merged and s <= merged[-1][1]:
                merged[-1][1] = max(merged[-1][1], e)
                merged[-1][2].append(n)
            else:
                merged.append([s, e, [n]])
        for s, e, names in reversed(merged):
            del lines[s:e]
        open(FILE, "w", encoding="utf-8").write("\n".join(lines))
        removed = [n for _s, _e, ns in merged for n in ns]
        print(f"round {round_no}: removed {len(removed)} — {', '.join(sorted(set(removed)))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
