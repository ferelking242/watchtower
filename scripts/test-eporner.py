#!/usr/bin/env python3
"""Run a focused, sanitized Eporner smoke test using the Watchtower CLI."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen


SOURCE_ID = "1900000141"
SOURCE_NAME = "Eporner"
TIMEOUT_SECONDS = 60
ANSI_ESCAPE = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
SITE_HEADERS = {
    "Referer": "https://www.eporner.com/",
    "User-Agent": (
        "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
    ),
}


def safe_error(stderr: str, returncode: int | None) -> str:
    lines = [line.strip() for line in stderr.splitlines() if line.strip()]
    message = " | ".join(lines[-4:]) if lines else (
        f"CLI exited with code {returncode} without stderr"
    )
    message = re.sub(r"https?://\S+", "<url>", message)
    message = re.sub(r"\s+", " ", message)
    return message[:350]


def matches_operation(value: Any, operation: str) -> bool:
    if operation in {"popular", "latest", "search"}:
        return isinstance(value, dict) and isinstance(value.get("list"), list)
    if operation == "detail":
        return isinstance(value, dict) and (
            "name" in value or isinstance(value.get("chapters"), list)
        )
    if operation == "videos":
        return isinstance(value, list)
    return False


def decode_cli_json(stdout: str, operation: str) -> Any | None:
    clean = ANSI_ESCAPE.sub("", stdout).strip()
    try:
        value = json.loads(clean)
        if matches_operation(value, operation):
            return value
    except json.JSONDecodeError:
        pass

    decoder = json.JSONDecoder()
    for position, character in enumerate(clean):
        if character not in "[{":
            continue
        try:
            value, _ = decoder.raw_decode(clean, position)
        except json.JSONDecodeError:
            continue
        if matches_operation(value, operation):
            return value
    return None


def probe_site() -> list[dict[str, Any]]:
    routes = [
        ("popular", "https://www.eporner.com/"),
        ("latest", "https://www.eporner.com/new/"),
        ("search", "https://www.eporner.com/search/a/"),
    ]
    probes = []
    for name, url in routes:
        started = time.monotonic()
        request = Request(url, headers=SITE_HEADERS)
        try:
            with urlopen(request, timeout=20) as response:
                body = response.read(2 * 1024 * 1024)
                probes.append(
                    {
                        "route": name,
                        "http_status": response.status,
                        "bytes_read": len(body),
                        "duration_seconds": round(time.monotonic() - started, 2),
                    }
                )
        except HTTPError as error:
            body = error.read(2 * 1024 * 1024)
            probes.append(
                {
                    "route": name,
                    "http_status": error.code,
                    "bytes_read": len(body),
                    "duration_seconds": round(time.monotonic() - started, 2),
                }
            )
        except Exception as error:
            message = re.sub(r"https?://\S+", "<url>", str(error))
            probes.append(
                {
                    "route": name,
                    "http_status": None,
                    "bytes_read": 0,
                    "duration_seconds": round(time.monotonic() - started, 2),
                    "error": message[:250],
                }
            )
    return probes


def run_operation(
    binary: Path,
    repo: Path,
    operation: str,
    extra_args: list[str],
) -> tuple[dict[str, Any], Any | None]:
    command = [
        "xvfb-run",
        "--auto-servernum",
        "--server-args=-screen 0 1280x720x24",
        str(binary),
        "--cli",
        "source",
        SOURCE_ID,
        operation,
        "--repo",
        str(repo),
        "--timeout",
        str(TIMEOUT_SECONDS),
        "--json",
        *extra_args,
    ]
    started = time.monotonic()
    try:
        process = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS + 30,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {
            "operation": operation,
            "status": "FAIL",
            "duration_seconds": round(time.monotonic() - started, 2),
            "error": f"CLI exceeded {TIMEOUT_SECONDS + 30}s process timeout",
        }, None

    elapsed = round(time.monotonic() - started, 2)
    if process.returncode != 0:
        return {
            "operation": operation,
            "status": "FAIL",
            "duration_seconds": elapsed,
            "error": safe_error(process.stderr, process.returncode),
        }, None

    value = decode_cli_json(process.stdout, operation)
    if value is None:
        clean_output = ANSI_ESCAPE.sub("", process.stdout)
        nonblank = [line for line in clean_output.splitlines() if line.strip()]
        return {
            "operation": operation,
            "status": "FAIL",
            "duration_seconds": elapsed,
            "error": (
                "No JSON payload found "
                f"({len(process.stdout.encode())} bytes, {len(nonblank)} nonblank lines)"
            ),
        }, None

    return {
        "operation": operation,
        "status": "PASS",
        "duration_seconds": elapsed,
    }, value


def list_result(step: dict[str, Any], value: Any) -> list[Any]:
    items = value.get("list") if isinstance(value, dict) else None
    if not isinstance(items, list) or not items:
        step["status"] = "FAIL"
        step["count"] = len(items) if isinstance(items, list) else 0
        step["error"] = "No results returned"
        return []
    step["count"] = len(items)
    return items


def write_reports(
    output: Path,
    build_run_id: str,
    build_sha: str,
    extension_sha: str,
    steps: list[dict[str, Any]],
    site_probes: list[dict[str, Any]],
) -> bool:
    output.mkdir(parents=True, exist_ok=True)
    passed = all(step["status"] == "PASS" for step in steps)
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": {"name": SOURCE_NAME, "id": SOURCE_ID},
        "binary_build": {"run_id": build_run_id, "commit": build_sha},
        "extension_catalog_commit": extension_sha,
        "direct_site_http_probes": site_probes,
        "passed": sum(step["status"] == "PASS" for step in steps),
        "failed": sum(step["status"] != "PASS" for step in steps),
        "steps": steps,
    }
    (output / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# Eporner — Watchtower Linux CLI",
        "",
        f"- Source: `{SOURCE_NAME}` (`{SOURCE_ID}`)",
        f"- Binary build: [{build_run_id}](https://github.com/ferelking242/watchtower/actions/runs/{build_run_id})",
        f"- Build commit: `{build_sha}`",
        f"- Extension catalog commit: `{extension_sha}`",
        f"- Result: **{'PASS' if passed else 'FAIL'}** "
        f"({report['passed']} passed, {report['failed']} failed)",
        "",
        "| Operation | Status | Results | Time | Note |",
        "|---|---:|---:|---:|---|",
    ]
    for step in steps:
        count = step.get("count", "—")
        note = step.get("error", "")
        note = note.replace("|", "\\|")
        lines.append(
            f"| {step['operation']} | {step['status']} | {count} | "
            f"{step['duration_seconds']:.2f}s | {note} |"
        )
    lines.extend(
        [
            "",
            "## Direct site HTTP probes (diagnostic only; not extension results)",
            "",
            "| Route | HTTP | Bytes | Time | Note |",
            "|---|---:|---:|---:|---|",
        ]
    )
    for probe in site_probes:
        lines.append(
            f"| {probe['route']} | {probe.get('http_status') or 'ERROR'} | "
            f"{probe['bytes_read']} | {probe['duration_seconds']:.2f}s | "
            f"{probe.get('error', '')} |"
        )
    lines.append("")
    summary = "\n".join(lines)
    (output / "summary.md").write_text(summary, encoding="utf-8")

    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as stream:
            stream.write(summary)

    print(summary)
    return passed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--build-run-id", required=True)
    parser.add_argument("--build-sha", required=True)
    parser.add_argument("--extension-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    for path, label in ((args.binary, "CLI binary"), (args.repo / "index", "extension index")):
        if not path.exists():
            print(f"Missing {label}: {path}", file=sys.stderr)
            return 2

    steps: list[dict[str, Any]] = []
    popular, popular_data = run_operation(args.binary, args.repo, "popular", [])
    steps.append(popular)
    popular_items = list_result(popular, popular_data) if popular_data is not None else []

    latest, latest_data = run_operation(args.binary, args.repo, "latest", [])
    steps.append(latest)
    if latest_data is not None:
        list_result(latest, latest_data)

    search, search_data = run_operation(args.binary, args.repo, "search", ["--query", "a"])
    steps.append(search)
    if search_data is not None:
        list_result(search, search_data)

    detail_url = ""
    if popular_items:
        first = popular_items[0]
        if isinstance(first, dict):
            detail_url = str(first.get("link") or "")
    if not detail_url:
        steps.append(
            {
                "operation": "detail",
                "status": "BLOCKED",
                "duration_seconds": 0.0,
                "error": "popular returned no usable detail URL",
            }
        )
        steps.append(
            {
                "operation": "videos",
                "status": "BLOCKED",
                "duration_seconds": 0.0,
                "error": "detail was not available",
            }
        )
    else:
        detail, detail_data = run_operation(
            args.binary, args.repo, "detail", ["--url", detail_url]
        )
        steps.append(detail)
        chapters = detail_data.get("chapters") if isinstance(detail_data, dict) else None
        media_url = ""
        if isinstance(chapters, list) and chapters and isinstance(chapters[0], dict):
            media_url = str(chapters[0].get("url") or "")
        if detail["status"] == "PASS" and not media_url:
            detail["status"] = "FAIL"
            detail["error"] = "Detail had no usable episode URL"
        elif detail["status"] == "PASS":
            detail["count"] = len(chapters)

        if not media_url:
            steps.append(
                {
                    "operation": "videos",
                    "status": "BLOCKED",
                    "duration_seconds": 0.0,
                    "error": "detail returned no usable episode URL",
                }
            )
        else:
            videos, video_data = run_operation(
                args.binary, args.repo, "videos", ["--url", media_url]
            )
            steps.append(videos)
            if video_data is not None:
                valid_videos = [
                    item
                    for item in video_data
                    if isinstance(item, dict) and item.get("url")
                ] if isinstance(video_data, list) else []
                videos["count"] = len(valid_videos)
                if not valid_videos:
                    videos["status"] = "FAIL"
                    videos["error"] = "No playable video URLs returned"

    site_probes = probe_site()
    passed = write_reports(
        args.output,
        args.build_run_id,
        args.build_sha,
        args.extension_sha,
        steps,
        site_probes,
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
