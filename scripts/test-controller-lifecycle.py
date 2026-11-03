#!/usr/bin/env python3
"""Characterize the unchanged controller using tiny offline macOS subprocesses."""

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
    "response-dispatch", "old-termination", "final-release", "callbacks",
    "context", "reuse", "handler-restoration", "old-handler-ownership",
    "no-response-retention", "pending-parallel-queues", "stranded-execute",
    "explicit-abort", "abort-parallel-queues", "very-late-termination",
    "duplicate-termination",
    *{f"native-{kind}-{check}" for kind in ("true", "false", "timeout")
      for check in ("drain", "reuse")},
}
CANDIDATE_IDS = {
    "no-response-retention", "pending-parallel-queues", "stranded-execute",
    "abort-parallel-queues", "very-late-termination", "duplicate-termination",
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


def validate_checks(report, expected):
    if report.get("complete") is not True or report.get("compiledMode") is not True:
        raise RuntimeError("Missing complete checkpoint or compiled execution")
    if report.get("errors") != []:
        raise RuntimeError(f"4D assertions failed: {report.get('errors')}")
    checks = report.get("checks", [])
    identifiers = [check.get("id") for check in checks]
    if len(identifiers) != len(expected) or set(identifiers) != expected:
        raise RuntimeError(f"Missing, duplicate or unknown checks: {identifiers}")
    if any(check.get("passed") is not True for check in checks):
        raise RuntimeError("A required characterization check failed")


def validate_native(report, rejection):
    validate_checks(report, {"native-events", "synchronous-rejection"})
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", required=True, type=Path)
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
    compiler = directory / "compiler"
    shutil.copytree(ROOT / "tests/compiler", compiler)
    driver = FIXTURE.project(compiler, "Compiler")
    compile_report = directory / "compile.json"
    config = directory / "compile-config.json"
    config.write_text(json.dumps({
        "project": str(anchor), "report": str(compile_report), "components": [],
    }))
    tool = str(args.tool4d.resolve())
    report = run_engine([
        tool, str(driver), "--skip-onstartup", "--startup-method=compile_fixture",
        "--dataless", f"--user-param={config}",
    ], directory, "compile", compile_report, timeout=120)
    if report.get("success") is not True or report.get("errors") != []:
        raise RuntimeError(f"Compiler diagnostics: {report}")
    for method in ("native", "schedules"):
        result = directory / f"{method}.json"
        report = run_engine([
            tool, str(anchor), "--skip-onstartup", f"--startup-method={method}",
            "--dataless", "--opening-mode=compiled", f"--user-param={result}",
        ], directory, method, result)
        if Path(str(result) + ".engine-errors.json").exists():
            raise RuntimeError(f"Unexpected 4D engine error: {result}")
        if method == "native":
            rejection = json.loads(Path(str(result) + ".rejection.json").read_text())
            validate_native(report, rejection)
        else:
            validate_checks(report, SCHEDULE_IDS)
            actual = {check["id"] for check in report["checks"]
                      if check.get("kind") == "candidate"}
            if actual != CANDIDATE_IDS:
                raise RuntimeError("Candidate observations misclassified as fixed regressions")
            if any(check.get("kind") != "regression" for check in report["checks"]
                   if check["id"] not in CANDIDATE_IDS):
                raise RuntimeError("Ordinary lifecycle checks must remain regressions")
    (directory / "summary.json").write_text(json.dumps({
        "characterizationComplete": True,
        "recoveryFixed": False,
        "acceptedNativeErrorWithoutResponseReproduced": False,
        "candidateCheckIds": sorted(CANDIDATE_IDS),
        "scheduleCheckCount": len(SCHEDULE_IDS),
        "nativeCheckCount": 2,
        "engine": version.stdout.decode().strip(),
        "validation": "Real 4D compile + compiled schedules + tiny native controls; not facade execution",
    }, indent=2))
    print("CHARACTERIZATION COMPLETE: native no-response error NOT reproduced; "
          "synthetic gaps observed, NOT fixed.", flush=True)


if __name__ == "__main__":
    main()
