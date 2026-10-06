"""Unit tests for the Eporner CLI smoke-test result validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("test-eporner.py")
SPEC = importlib.util.spec_from_file_location("eporner_cli_smoke_test", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
smoke_test = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke_test)


class EpornerValidationTests(unittest.TestCase):
    def test_accepts_only_absolute_http_urls(self) -> None:
        self.assertTrue(smoke_test.is_absolute_http_url("https://www.eporner.com/video/"))
        self.assertTrue(smoke_test.is_absolute_http_url("http://cdn.example/video.mp4"))
        self.assertFalse(smoke_test.is_absolute_http_url("/video/"))
        self.assertFalse(smoke_test.is_absolute_http_url("//cdn.example/video.mp4"))
        self.assertFalse(smoke_test.is_absolute_http_url("javascript:alert(1)"))
        self.assertFalse(smoke_test.is_absolute_http_url("https://bad host/video"))

    def test_accepts_named_results_with_absolute_links(self) -> None:
        step = {"status": "PASS"}
        items = [{"name": "A real video title", "link": "https://www.eporner.com/video/"}]
        self.assertEqual(smoke_test.list_result(step, {"list": items}), items)
        self.assertEqual(step["status"], "PASS")

    def test_rejects_generic_names_and_relative_links(self) -> None:
        step = {"status": "PASS"}
        result = smoke_test.list_result(
            step,
            {
                "list": [
                    {"name": "Unknown", "link": "https://www.eporner.com/video/"},
                    {"name": "Valid title", "link": "/video/"},
                ]
            },
        )
        self.assertEqual(result, [])
        self.assertEqual(step["status"], "FAIL")
        self.assertIn("missing or generic name", step["error"])
        self.assertIn("non-absolute HTTP(S) link", step["error"])

    def test_failed_validation_produces_a_failing_report(self) -> None:
        step = {"operation": "latest", "status": "FAIL", "duration_seconds": 0.0}
        with tempfile.TemporaryDirectory() as directory:
            passed = smoke_test.write_reports(
                Path(directory),
                "123",
                "build-sha",
                "extensions-sha",
                [step],
                [],
            )
            report = json.loads((Path(directory) / "report.json").read_text())
        self.assertFalse(passed)
        self.assertEqual(report["passed"], 0)
        self.assertEqual(report["failed"], 1)


if __name__ == "__main__":
    unittest.main()
