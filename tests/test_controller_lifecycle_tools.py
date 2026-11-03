import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "controller_tools", ROOT / "scripts/test-controller-lifecycle.py"
)
TOOLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOLS)


class EvidenceGateTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".build").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="controller-gate-", dir=ROOT / ".build")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.report = self.root / "result.json"

    def completed(self, code=0, report=True):
        def run(*args, **kwargs):
            if report:
                self.report.write_text('{"complete":true}')
            return subprocess.CompletedProcess(args[0], code, b"stdout", b"stderr")
        return run

    def test_nonzero_with_green_report_fails(self):
        with patch.object(TOOLS.subprocess, "run", side_effect=self.completed(-11)):
            with self.assertRaisesRegex(RuntimeError, "exit=-11"):
                TOOLS.run_engine(["tool"], self.root, "run", self.report)
        self.assertEqual(json.loads((self.root / "run-exit.json").read_text())["returncode"], -11)

    def test_zero_without_fresh_report_fails(self):
        with patch.object(TOOLS.subprocess, "run", side_effect=self.completed(report=False)):
            with self.assertRaisesRegex(RuntimeError, "fresh report=False"):
                TOOLS.run_engine(["tool"], self.root, "run", self.report)

    def test_stale_report_is_rejected_before_launch(self):
        self.report.write_text("{}")
        with patch.object(TOOLS.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "stale report"):
                TOOLS.run_engine(["tool"], self.root, "run", self.report)
            run.assert_not_called()

    def test_timeout_preserves_partial_output(self):
        with patch.object(TOOLS.subprocess, "run", side_effect=subprocess.TimeoutExpired(
            ["tool"], 30, output=b"checkpoint", stderr=b"diagnostic",
        )):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                TOOLS.run_engine(["tool"], self.root, "run", self.report)
        self.assertEqual((self.root / "run-stdout.log").read_bytes(), b"checkpoint")
        self.assertTrue(json.loads((self.root / "run-exit.json").read_text())["timedOut"])

    def test_clean_report_is_returned(self):
        with patch.object(TOOLS.subprocess, "run", side_effect=self.completed()):
            self.assertEqual(
                TOOLS.run_engine(["tool"], self.root, "run", self.report),
                {"complete": True},
            )

    def test_incomplete_or_interpreted_or_duplicate_checks_fail(self):
        good = {"complete": True, "compiledMode": True, "errors": [],
                "checks": [{"id": "a", "passed": True}]}
        TOOLS.validate_checks(good, {"a"})
        for field in ("complete", "compiledMode"):
            bad = copy.deepcopy(good)
            bad[field] = False
            with self.assertRaises(RuntimeError):
                TOOLS.validate_checks(bad, {"a"})
        for checks in ([], good["checks"] * 2, [{"id": "a", "passed": False}]):
            with self.assertRaises(RuntimeError):
                TOOLS.validate_checks({**good, "checks": checks}, {"a"})

    def test_native_error_without_response_is_not_a_green_repro(self):
        cases = [
            {"name": name, "accepted": True, "terminated": True, "pid": index,
             "events": [{"name": event, "pid": index}
                        for event in ("response", "termination")]}
            for index, name in enumerate(("success", "nonzero", "signal-attempt", "timeout"))
        ]
        cases[0]["exitCode"] = 0
        cases[1]["exitCode"] = 1
        cases.append({"name": "missing", "accepted": False, "events": []})
        report = {"complete": True, "compiledMode": True, "errors": [], "cases": cases,
                  "checks": [{"id": name, "passed": True}
                             for name in ("native-events", "synchronous-rejection")]}
        rejection = [{"errCode": 2, "componentSignature": "POSX"}]
        TOOLS.validate_native(report, rejection)
        with self.assertRaisesRegex(RuntimeError, "POSX2"):
            TOOLS.validate_native(report, rejection + [{"errCode": 99}])
        cases[2]["events"][0]["name"] = "error"
        with self.assertRaisesRegex(RuntimeError, "sequence changed"):
            TOOLS.validate_native(report, rejection)


if __name__ == "__main__":
    unittest.main()
