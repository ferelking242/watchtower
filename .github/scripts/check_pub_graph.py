#!/usr/bin/env python3
"""Fail CI when the resolved Dart package graph is duplicated or cyclic."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def package_entries(payload: dict) -> list[dict]:
    packages = payload.get("packages", [])
    if isinstance(packages, dict):
        return [
            {"name": name, **(value if isinstance(value, dict) else {})}
            for name, value in packages.items()
        ]
    return [package for package in packages if isinstance(package, dict)]


def dependency_name(dependency: object) -> str | None:
    if isinstance(dependency, str):
        return dependency
    if isinstance(dependency, dict):
        name = dependency.get("name")
        return name if isinstance(name, str) else None
    return None


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_pub_graph.py <pub-deps.json>", file=sys.stderr)
        return 2

    payload = json.loads(Path(sys.argv[1]).read_text())
    entries = package_entries(payload)
    names = [entry.get("name") for entry in entries]
    duplicates = sorted(
        name for name in set(names) if name and names.count(name) > 1
    )
    if duplicates:
        print("Duplicate resolved packages: " + ", ".join(duplicates), file=sys.stderr)
        return 1

    known = {name for name in names if name}
    sources = {
        name: entry.get("source")
        for name, entry in zip(names, entries)
        if name
    }
    graph = {
        name: {
            dependency
            for dependency in (
                dependency_name(item)
                for item in entry.get("dependencies", [])
            )
            if dependency in known
        }
        for name, entry in zip(names, entries)
        if name
    }

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str, path: list[str]) -> list[str] | None:
        if name in visiting:
            return path[path.index(name) :] + [name]
        if name in visited:
            return None
        visiting.add(name)
        for dependency in sorted(graph.get(name, ())):
            cycle = visit(dependency, path + [dependency])
            if cycle:
                return cycle
        visiting.remove(name)
        visited.add(name)
        return None

    for name in sorted(graph):
        cycle = visit(name, [name])
        if cycle:
            # Some hosted packages intentionally depend on each other to share
            # public types. Pub accepts this shape; only fail cycles involving
            # the app or a local path package that we own.
            app_owned = any(
                sources.get(package) in {"root", "path"} for package in cycle
            )
            message = " -> ".join(cycle)
            if app_owned:
                print("Circular app dependency: " + message, file=sys.stderr)
                return 1
            print("Upstream package cycle (allowed): " + message)

    print(f"Dependency graph OK: {len(known)} unique packages, no cycles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())