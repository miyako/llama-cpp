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

    def rejection_report(self):
        owner = {"number": 2, "ID": 73, "name": "isolated-probe", "type": 5,
                 "available": True}
        original = [{"errCode": 2, "componentSignature": "POSX",
                     "message": "No such file or directory"}]
        events = []
        for pid, context in enumerate((
            "reuse-single", "reuse-batch", "reuse-repeated", "first", "second",
        ), 100):
            events.extend([
                {"name": name, "pid": pid, "context": context, "exitCode": 0,
                 "receiver": True, "constructionActive": False, "process": owner.copy()}
                for name in ("response", "termination")
            ])
        states = []
        context_map = {"existing": {"retained": True}}
        for index, label in enumerate((
            "reject-single", "reject-batch", "reject-repeat-1", "reject-repeat-2",
        )):
            if index in (1, 2):
                context_map[str(99 + index)] = events[(index - 1) * 2]["context"]
            states.append({
                "label": label, "safeToReuse": True, "workerNull": True, "complete": True,
                "commands": [], "messages": [], "contexts": [],
                "publicResponseRestored": True, "publicTerminationRestored": True,
                "contextMap": copy.deepcopy(context_map),
            })
        return {
            "complete": True, "compiledMode": True, "errors": [],
            "checks": [{"id": name, "passed": True} for name in TOOLS.REJECTION_IDS],
            "rejectionCleanupVerified": True,
            "rejections": [{"errors": copy.deepcopy(original), "process": owner.copy()}
                           for _ in range(4)],
            "states": states,
            "ownerProcess": owner, "reportProcess": owner.copy(),
            "turns": [{"process": owner.copy()}, {"process": owner.copy()}],
            "events": events,
            "cleanup": [{"pid": pid, "terminated": True} for pid in range(100, 105)],
        }, original

    def test_worker_rejection_evidence_gates(self):
        report, original = self.rejection_report()
        TOOLS.validate_rejection(report, original)
        mutations = (
            lambda r: r.update(unsafeReusePrevented=True),
            lambda r: r["rejections"][0]["errors"][0].update(componentSignature="host"),
            lambda r: r["states"][0].update(safeToReuse=False),
            lambda r: r["states"][0].update(messages=[None]),
            lambda r: r["states"][0]["contextMap"].update(failed="failed"),
            lambda r: r["ownerProcess"].update(available=False),
            lambda r: r["ownerProcess"].update(ID=0),
            lambda r: r["ownerProcess"].update(number=0),
            lambda r: r["ownerProcess"].update(name=""),
            lambda r: r["reportProcess"].update(ID=74),
            lambda r: r["events"][0].update(receiver=False),
            lambda r: r["events"][0].update(constructionActive=True),
            lambda r: r["events"][0].update(context="failed"),
            lambda r: r["events"][1].update(pid=999),
            lambda r: r["cleanup"][0].update(terminated=False),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                bad = copy.deepcopy(report)
                mutate(bad)
                with self.assertRaises(RuntimeError):
                    TOOLS.validate_rejection(bad, original)

    def test_interpreted_tier_does_not_satisfy_compiled_gate(self):
        report, original = self.rejection_report()
        report["compiledMode"] = False
        TOOLS.validate_rejection(report, original, compiled_mode=False)
        with self.assertRaises(RuntimeError):
            TOOLS.validate_rejection(report, original)
        report["compiledMode"] = True
        with self.assertRaises(RuntimeError):
            TOOLS.validate_rejection(report, original, compiled_mode=False)

    def test_worker_identity_uses_lts_command(self):
        source = ROOT / "tests/controller/Project/Sources"
        fixture = "\n".join(path.read_text() for path in source.rglob("*.4dm"))
        self.assertNotIn("Process info(", fixture)
        helper = (source / "Methods/rejectionProcess.4dm").read_text()
        self.assertIn("PROCESS PROPERTIES:C336(", helper)
        self.assertIn("Current process:C322", helper)
        self.assertIn("$state:=-100", helper)
        self.assertIn("($ID#0) && ($origin=5)", helper)
        self.assertNotIn("Get process activity", helper)
        worker = (source / "Methods/rejectionWorker.4dm").read_text()
        self.assertIn("If (rejectionProbe.report.errors.length=0)", worker)

    def lifecycle_report(self):
        owner = {"number": 2, "ID": 73, "name": "isolated-lifecycle", "type": 5,
                 "available": True}
        cases = []
        pid = 100
        for index, name in enumerate((
            "nonzero-abort", "no-handler", "abort-active",
            "callback-unwind", "callback-resume",
        )):
            handler = ("probeError", "probeError", "probeError",
                       "lifecycleAbort", "lifecycleResume")[index]
            events = []
            for command in range(2 if index in (1, 4) else 1):
                names = ("termination",) if index == 1 else ("response", "termination")
                events.extend({
                    "name": event, "type": event, "pid": pid,
                    "receiver": True, "context": ("first", "second")[command],
                    "exitCode": 1 if index == 0 else 0,
                    "handler": handler, "process": owner.copy(),
                } for event in names)
                pid += 1
            cases.append({
                "name": name, "kind": "native-control", "events": events,
                "callbackErrors": [] if index < 3 else [{
                    "errors": [{"errCode": 2, "componentSignature": "POSX"}],
                    "handler": handler, "process": owner.copy(),
                }],
                "returned": 1 if index == 4 else 0,
            })
        return {
            "complete": True, "compiledMode": True, "errors": [],
            "checks": [{"id": name, "passed": True} for name in TOOLS.LIFECYCLE_IDS],
            "acceptedNativeErrorWithoutResponseReproduced": False,
            "cases": cases, "ownerProcess": owner, "reportProcess": owner.copy(),
            "turns": [{"process": owner.copy()} for _ in range(6)],
            "simulated": [{
                "receiver": True, "worker": True, "event": True,
                "context": "context-a", "launches": 1, "process": owner.copy(),
            } for _ in range(2)],
            "cleanup": [{"pid": p, "terminated": True} for p in range(98, 107)],
        }

    def test_persistent_lifecycle_evidence_gates(self):
        report = self.lifecycle_report()
        TOOLS.validate_lifecycle(report)
        mutations = (
            lambda r: r.update(acceptedNativeErrorWithoutResponseReproduced=True),
            lambda r: r["ownerProcess"].update(available=False),
            lambda r: r["reportProcess"].update(ID=74),
            lambda r: r["simulated"][0].update(event=False),
            lambda r: r["simulated"][0].update(launches=2),
            lambda r: r["cases"][0]["events"][0].update(exitCode=0),
            lambda r: r["cases"][0]["events"][0].update(handler="intercepted"),
            lambda r: r["cases"][3].update(returned=1),
            lambda r: r["cases"][4].update(returned=0),
            lambda r: r["cases"][3]["callbackErrors"][0]["errors"][0].update(errCode=99),
            lambda r: r["cases"][4]["events"][0]["process"].update(ID=74),
            lambda r: r["cleanup"][0].update(terminated=False),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                bad = copy.deepcopy(report)
                mutate(bad)
                with self.assertRaises(RuntimeError):
                    TOOLS.validate_lifecycle(bad)

    def test_production_keeps_quiet_streams_and_caller_error_routing(self):
        controller = (ROOT / "llama-cpp/Project/Sources/Classes/_CLI_Controller.4dm").read_text()
        terminal = controller.split("Function _onTerminal(", 1)[1].split(
            "Function _options(", 1,
        )[0]
        self.assertLess(terminal.index("$callback.call("), terminal.index("._execute()"))
        self.assertNotIn("ON ERR CALL", controller)
        self.assertNotIn("Last errors", controller)
        self.assertNotIn(".response", controller)
        self.assertIn('onData: This:C1470.onData; onDataError: This:C1470.onDataError', controller)
        llama = (ROOT / "llama-cpp/Project/Sources/Classes/_llama_Controller.4dm").read_text()
        self.assertNotIn("$instance.onResponse", llama)
        self.assertNotIn("$instance.onError", llama)


if __name__ == "__main__":
    unittest.main()
