#!/usr/bin/env python3
"""Verify controller lifecycle regressions with separate synthetic/native evidence."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "integrity_fixture", ROOT / "scripts/test-download-integrity.py"
)
FIXTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURE)

SCHEDULE_IDS = {
    "reference-controls",
    "response-dispatch", "old-termination", "final-release", "callbacks",
    "context", "reuse", "handler-restoration", "old-handler-ownership",
    "callback-before-dispatch",
    "error-default-continue", "error-parallel-queues", "error-old-termination",
    "error-final-release", "error-later-execute", "stale-generation",
    "explicit-abort", "abort-parallel-queues", "very-late-termination",
    "duplicate-termination", "lifecycle-release", "worker-argument-ownership",
    "callback-abort", "callback-enqueue", "callback-abort-enqueue",
    "callback-terminate", "callback-restart", "false-return-ignored",
    "error-callback-abort", "error-abort-termination", "nonzero-callback-abort",
    "enqueue-after-response", "enqueue-after-response-ownership",
    *{f"reentrant-{mode}-{check}"
      for mode in ("abort", "enqueue", "abort-enqueue", "terminate", "restart", "continue")
      for check in ("callback", "duplicate")},
    *{f"native-{kind}-{check}" for kind in ("true", "false", "timeout")
      for check in ("drain", "reuse")},
}
CANDIDATE_IDS = set()
REJECTION_IDS = {
    *{f"reject-{case}-{check}" for case in ("single", "batch", "repeat-1", "repeat-2")
      for check in ("error", "state")},
    "reuse-single", "reuse-batch", "reuse-repeated", "normal-queue",
    "native-old-termination", "late-event-window", "final-cleanup",
    "constructor-callback-order", "worker-owner-lifetime",
}
LIFECYCLE_IDS = {
    "persistent-synthetic-error-continue", "persistent-synthetic-old-termination",
    "persistent-synthetic-final-release", "persistent-synthetic-error-abort",
    "persistent-synthetic-callbacks", "abort-does-not-terminate",
    "native-nonzero-abort-before-sideeffect", "native-no-handler-continues",
    "native-abort-preserves-callbacks", "callback-unwind-no-dispatch",
    "unwind-handler-unchanged", "callback-resume-continues",
    "resume-handler-unchanged", "persistent-late-sideeffects",
    "persistent-native-cleanup", "persistent-lifecycle-owner",
}


def run_engine(command, directory, label, report, timeout=30):
    """Keep failures observable, including a report followed by a shutdown crash."""
    if report.exists():
        raise RuntimeError(f"Refusing stale report: {report}")
    (directory / f"{label}-invocation.json").write_text(json.dumps(command, indent=2))
    try:
        completed = subprocess.run(command, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        (directory / f"{label}-stdout.log").write_bytes(error.stdout or b"")
        (directory / f"{label}-stderr.log").write_bytes(error.stderr or b"")
        (directory / f"{label}-exit.json").write_text(json.dumps({"timedOut": True}))
        raise RuntimeError(f"{label} timed out; evidence: {directory}") from error
    (directory / f"{label}-stdout.log").write_bytes(completed.stdout)
    (directory / f"{label}-stderr.log").write_bytes(completed.stderr)
    (directory / f"{label}-exit.json").write_text(json.dumps({
        "returncode": completed.returncode, "timedOut": False,
    }))
    if completed.returncode or not report.is_file():
        raise RuntimeError(
            f"{label} exit={completed.returncode}, fresh report={report.is_file()}: {directory}"
        )
    return json.loads(report.read_text())


def validate_checks(report, expected, *, compiled_mode=True):
    if report.get("complete") is not True or report.get("compiledMode") is not compiled_mode:
        raise RuntimeError("Missing complete checkpoint or expected execution mode")
    if report.get("errors") != []:
        raise RuntimeError(f"4D assertions failed: {report.get('errors')}")
    checks = report.get("checks", [])
    identifiers = [check.get("id") for check in checks]
    if len(identifiers) != len(expected) or set(identifiers) != expected:
        raise RuntimeError(f"Missing, duplicate or unknown checks: {identifiers}")
    if any(check.get("passed") is not True for check in checks):
        raise RuntimeError("A required characterization check failed")


def validate_native(report, rejection, *, compiled_mode=True):
    validate_checks(report, {"native-events", "synchronous-rejection"},
                    compiled_mode=compiled_mode)
    cases = report.get("cases", [])
    if [case.get("name") for case in cases] != [
        "success", "nonzero", "signal-attempt", "timeout", "missing",
    ]:
        raise RuntimeError("Incomplete native command matrix")
    for case in cases[:4]:
        if case.get("accepted") is not True or case.get("terminated") is not True:
            raise RuntimeError(f"Native command was not accepted and terminated: {case}")
        events = case.get("events", [])
        if [event.get("name") for event in events] != ["response", "termination"]:
            raise RuntimeError(f"Native sequence changed; investigate, not a cleanup fix: {case}")
        if any(event.get("pid") != case.get("pid") for event in events):
            raise RuntimeError("Native callback worker identity changed")
    if cases[0].get("exitCode") != 0 or cases[1].get("exitCode") != 1:
        raise RuntimeError("Success/nonzero controls did not produce expected exit codes")
    if cases[4].get("accepted") is not False or cases[4].get("events") != []:
        raise RuntimeError("Missing executable was not a synchronous rejection")
    if not rejection or any(
        error.get("errCode") != 2 or error.get("componentSignature") != "POSX"
        for error in rejection
    ):
        raise RuntimeError("Missing executable did not report expected POSX2 rejection")


def validate_rejection(report, original, *, compiled_mode=True):
    validate_checks(report, REJECTION_IDS, compiled_mode=compiled_mode)
    if report.get("rejectionCleanupVerified") is not True:
        raise RuntimeError("Guarded worker rejection/reuse did not complete successfully")
    if report.get("unsafeReusePrevented"):
        raise RuntimeError("Unsafe baseline state prevented reuse; cleanup is not fixed")
    rejections = report.get("rejections", [])
    if len(rejections) != 4 or any(case.get("errors") != original for case in rejections):
        raise RuntimeError("Original native constructor error stack was not preserved")
    states = report.get("states", [])
    if [state.get("label") for state in states] != [
        "reject-single", "reject-batch", "reject-repeat-1", "reject-repeat-2",
    ] or any(state.get("safeToReuse") is not True for state in states):
        raise RuntimeError("Missing guarded initial-idle rejection state")
    owner = report.get("ownerProcess", {})
    final = report.get("reportProcess", {})
    if (owner.get("available") is not True or owner.get("type") != 5
            or type(owner.get("number")) is not int or owner["number"] in (0, 1)
            or type(owner.get("ID")) is not int or owner["ID"] == 0
            or not isinstance(owner.get("name"), str) or not owner["name"]):
        raise RuntimeError("Missing dedicated persistent worker identity")
    for process in [final, *[turn.get("process", {}) for turn in report.get("turns", [])]]:
        if any(process.get(key) != owner.get(key) for key in ("ID", "number", "name", "type")):
            raise RuntimeError("Owning worker identity changed between mailbox turns")
    events = report.get("events", [])
    if len(events) != 10 or [event.get("name") for event in events] != [
        "response", "termination",
    ] * 5:
        raise RuntimeError("Guarded reuse/normal queue callback sequence changed")
    for event in events:
        if event.get("receiver") is not True or event.get("constructionActive") is not False:
            raise RuntimeError("Callback receiver or constructor/commit ordering changed")
        if any(event.get("process", {}).get(key) != owner.get(key)
               for key in ("ID", "number", "name", "type")):
            raise RuntimeError("Callback did not run in the owning persistent worker")
    for rejection in rejections:
        if any(rejection.get("process", {}).get(key) != owner.get(key)
               for key in ("ID", "number", "name", "type")):
            raise RuntimeError("Native rejection did not reach the owning worker's handler")
    expected_map = {"existing": {"retained": True}}
    for index, state in enumerate(states):
        if index in (1, 2):
            event = events[(index - 1) * 2]
            expected_map[str(event["pid"])] = event["context"]
        if (any(state.get(key) is not True for key in (
                "workerNull", "complete", "publicResponseRestored", "publicTerminationRestored"))
                or any(state.get(key) != [] for key in ("commands", "messages", "contexts"))
                or state.get("contextMap") != expected_map):
            raise RuntimeError("Rejected batch changed queues, callbacks or the prior context map")
    if [event.get("context") for event in events[::2]] != [
        "reuse-single", "reuse-batch", "reuse-repeated", "first", "second",
    ]:
        raise RuntimeError("Rejected message/context leaked into a later command")
    for response, termination in zip(events[::2], events[1::2]):
        if (response.get("pid") != termination.get("pid")
                or termination.get("exitCode") != 0):
            raise RuntimeError("Worker argument identity or successful exit changed")
    cleanup = report.get("cleanup", [])
    if len(cleanup) != 5 or any(worker.get("terminated") is not True for worker in cleanup):
        raise RuntimeError("Directly owned test workers did not terminate")


def validate_lifecycle(report):
    validate_checks(report, LIFECYCLE_IDS)
    if report.get("acceptedNativeErrorWithoutResponseReproduced") is not False:
        raise RuntimeError("Synthetic accepted-error schedules are not native proof")
    owner = report.get("ownerProcess", {})
    if (owner.get("available") is not True or owner.get("type") != 5
            or type(owner.get("number")) is not int or owner["number"] in (0, 1)
            or type(owner.get("ID")) is not int or owner["ID"] == 0
            or not owner.get("name")):
        raise RuntimeError("Missing persistent lifecycle owner")
    cases = report.get("cases", [])
    names = ("nonzero-abort", "no-handler", "abort-active",
             "callback-unwind", "callback-resume")
    if [case.get("name") for case in cases] != list(names):
        raise RuntimeError("Missing persistent lifecycle native controls")
    processes = [report.get("reportProcess", {})]
    turns = report.get("turns", [])
    if len(turns) <= 5:
        raise RuntimeError("Persistent owner did not survive later mailbox turns")
    processes.extend(turn.get("process", {}) for turn in turns)
    simulated = report.get("simulated", [])
    if len(simulated) != 2 or any(
        any(event.get(key) is not True for key in ("receiver", "worker", "event"))
        or event.get("context") != "context-a" or event.get("launches") != 1
        for event in simulated
    ):
        raise RuntimeError("Synthetic callback identity/context/order changed")
    processes.extend(event.get("process", {}) for event in simulated)
    expected_names = (
        ["response", "termination"], ["termination", "termination"],
        ["response", "termination"], ["response", "termination"],
        ["response", "termination", "response", "termination"],
    )
    expected_handlers = ("probeError", "probeError", "probeError",
                         "lifecycleAbort", "lifecycleResume")
    pids = set()
    for index, (case, expected, handler) in enumerate(
        zip(cases, expected_names, expected_handlers)
    ):
        if case.get("kind") != "native-control":
            raise RuntimeError("Native callback-error controls misclassified")
        events = case.get("events", [])
        if [event.get("name") for event in events] != expected:
            raise RuntimeError("Persistent native callback sequence changed")
        for event in events:
            if (event.get("receiver") is not True or event.get("handler") != handler
                    or event.get("type") != event.get("name")):
                raise RuntimeError("Public receiver, event or caller error routing changed")
            processes.append(event.get("process", {}))
            pids.add(event.get("pid"))
        if index != 1:
            for response, termination in zip(events[::2], events[1::2]):
                if (response.get("pid") != termination.get("pid")
                        or response.get("context") not in ("first", "second")):
                    raise RuntimeError("Public worker/context arguments changed")
        errors = case.get("callbackErrors", [])
        if index < 3:
            if errors or case.get("returned") != 0:
                raise RuntimeError("Unexpected callback errors")
        else:
            if len(errors) != 1 or case.get("returned") != index - 3:
                raise RuntimeError("ABORT and intentional resumption were not distinguished")
            error = errors[0]
            stack = error.get("errors", [])
            if (len(stack) != 1 or stack[0].get("errCode") != 2
                    or stack[0].get("componentSignature") != "POSX"
                    or error.get("handler") != handler):
                raise RuntimeError("Original callback error did not reach caller's handler")
            processes.append(error.get("process", {}))
    if cases[0]["events"][0].get("exitCode") != 1:
        raise RuntimeError("Native nonzero abort did not observe exit 1")
    for process in processes:
        if any(process.get(key) != owner.get(key) for key in ("ID", "number", "name", "type")):
            raise RuntimeError("Lifecycle callback/turn owner identity changed")
    cleanup = report.get("cleanup", [])
    if (len(cleanup) != 9 or any(worker.get("terminated") is not True for worker in cleanup)
            or not pids.issubset({worker.get("pid") for worker in cleanup})):
        raise RuntimeError("Lifecycle test workers did not terminate")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", required=True, type=Path)
    parser.add_argument(
        "--interpreted-rejection", action="store_true",
        help="Only interpreted native controls and persistent-worker rejection/reuse; no compilation",
    )
    args = parser.parse_args()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="controller-", dir=build)).resolve()
    print(f"Fixture/evidence: {directory}", flush=True)
    fixture = directory / "fixture"
    shutil.copytree(ROOT / "tests/controller", fixture)
    anchor = FIXTURE.project(fixture, "Controller")
    relative = "llama-cpp/Project/Sources/Classes/_CLI_Controller.4dm"
    source = ROOT / relative
    shutil.copy2(source, fixture / "Project/Sources/Classes")
    (directory / "source.json").write_text(json.dumps({
        "path": relative, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
        ).strip(),
        "graph": "Actual _CLI_Controller + stub _CLI owner + Schedule subclass; no components/facade",
    }, indent=2))
    version = subprocess.run(
        [str(args.tool4d.resolve()), "--version"], capture_output=True, timeout=15,
    )
    (directory / "engine-version.txt").write_bytes(version.stdout + version.stderr)
    (directory / "version-exit.json").write_text(json.dumps({
        "returncode": version.returncode,
    }))
    if version.returncode:
        raise RuntimeError("Engine version preflight failed")
    tool = str(args.tool4d.resolve())
    if args.interpreted_rejection:
        for method in ("native", "rejection"):
            result = directory / f"{method}.json"
            report = run_engine([
                tool, str(anchor), "--skip-onstartup", f"--startup-method={method}",
                "--dataless", "--opening-mode=interpreted", f"--user-param={result}",
            ], directory, method, result)
            if any(Path(str(result) + suffix).exists() for suffix in (
                ".engine-errors.json", ".driver-timeout.json",
            )):
                raise RuntimeError(f"Unexpected 4D engine error: {result}")
            if method == "native":
                rejection = json.loads(Path(str(result) + ".rejection.json").read_text())
                validate_native(report, rejection, compiled_mode=False)
            else:
                validate_rejection(report, rejection, compiled_mode=False)
        (directory / "interpreted-rejection-summary.json").write_text(json.dumps({
            "idleConstructorRejectionCleanupVerified": True,
            "compiledMode": False,
            "recoveryFixed": False,
            "acceptedNativeErrorWithoutResponseReproduced": False,
            "persistentWorkerRejectionCheckCount": len(REJECTION_IDS),
            "engine": version.stdout.decode().strip(),
            "validation": "Interpreted native controls and guarded persistent worker only; no compile, schedules or facade proof",
        }, indent=2))
        print("INTERPRETED IDLE REJECTION/REUSE VERIFIED; no compilation claim.", flush=True)
        return
    compiler = directory / "compiler"
    shutil.copytree(ROOT / "tests/compiler", compiler)
    driver = FIXTURE.project(compiler, "Compiler")
    compile_report = directory / "compile.json"
    config = directory / "compile-config.json"
    config.write_text(json.dumps({
        "project": str(anchor), "report": str(compile_report), "components": [],
    }))
    report = run_engine([
        tool, str(driver), "--skip-onstartup", "--startup-method=compile_fixture",
        "--dataless", f"--user-param={config}",
    ], directory, "compile", compile_report, timeout=120)
    if report.get("success") is not True or report.get("errors") != []:
        raise RuntimeError(f"Compiler diagnostics: {report}")
    for method in ("native", "schedules", "rejection", "lifecycle"):
        result = directory / f"{method}.json"
        report = run_engine([
            tool, str(anchor), "--skip-onstartup", f"--startup-method={method}",
            "--dataless", "--opening-mode=compiled", f"--user-param={result}",
        ], directory, method, result)
        if any(Path(str(result) + suffix).exists() for suffix in (
            ".engine-errors.json", ".driver-timeout.json",
        )):
            raise RuntimeError(f"Unexpected 4D engine error: {result}")
        if method == "native":
            rejection = json.loads(Path(str(result) + ".rejection.json").read_text())
            validate_native(report, rejection)
        elif method == "schedules":
            validate_checks(report, SCHEDULE_IDS)
            actual = {check["id"] for check in report["checks"]
                      if check.get("kind") == "candidate"}
            if actual != CANDIDATE_IDS:
                raise RuntimeError("Candidate observations misclassified as fixed regressions")
            if any(check.get("kind") != "regression" for check in report["checks"]
                   if check["id"] not in CANDIDATE_IDS):
                raise RuntimeError("Ordinary lifecycle checks must remain regressions")
        elif method == "rejection":
            validate_rejection(report, rejection)
        else:
            validate_lifecycle(report)
    (directory / "summary.json").write_text(json.dumps({
        "characterizationComplete": True,
        "syntheticAcceptedLifecycleRegressionVerified": True,
        "nativeResponseControlsVerified": True,
        "acceptedNativeErrorWithoutResponseReproduced": False,
        "candidateCheckIds": sorted(CANDIDATE_IDS),
        "scheduleCheckCount": len(SCHEDULE_IDS),
        "nativeCheckCount": 2,
        "idleConstructorRejectionCleanupVerified": True,
        "persistentWorkerRejectionCheckCount": len(REJECTION_IDS),
        "persistentWorkerLifecycleCheckCount": len(LIFECYCLE_IDS),
        "engine": version.stdout.decode().strip(),
        "validation": "Compiled synthetic lifecycle schedules, accepted-native controls and persistent-owner regressions; native onError without response and facade execution remain unproved",
    }, indent=2))
    print("LIFECYCLE REGRESSIONS VERIFIED: native no-response error NOT reproduced; "
          "synthetic contract schedules and native controls passed.", flush=True)


if __name__ == "__main__":
    main()
