#!/usr/bin/env python3
"""Run offline, tiny-file 4D integrity regressions in a retained .build fixture.

Copies only wrapper classes and controlled event/worker components. Never runs
the production startup method, fetches models, or touches a shared component cache.
Without --hash-component the hash dependency is a small-file 4D double, not the
native CLI. Supply an extracted, checksum-verified hash.4dbase for integration.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def reviewed_hash_archive(archive, directory):
    lock = json.loads((ROOT / "dependencies.lock.json").read_text())["hash"]
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual != lock["artifact"]["sha256"]:
        raise RuntimeError(f"Hash component archive checksum mismatch: {actual}")
    output = directory / "reviewed-hash"
    output.mkdir()
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            path = output / member.filename
            if not path.resolve().is_relative_to(output.resolve()):
                raise RuntimeError(f"Unsafe component archive path: {member.filename}")
            if ((member.external_attr >> 16) & 0o170000) == 0o120000:
                raise RuntimeError(f"Unexpected component symlink: {member.filename}")
            source.extract(member, output)
            mode = (member.external_attr >> 16) & 0o777
            if mode:
                path.chmod(mode)
    candidates = [
        path for path in output.rglob("*.4dbase")
        if (path / "hash.4DZ").exists() or (path / "hash.4dz").exists()
    ]
    if len(candidates) != 1:
        raise RuntimeError("Reviewed archive must contain exactly one hash.4dbase")
    (directory / "hash-artifact.json").write_text(json.dumps(lock, indent=2))
    return candidates[0]


def project(directory, name, namespace=None):
    sources = directory / "Project/Sources"
    sources.mkdir(parents=True, exist_ok=True)
    anchor = directory / f"Project/{name}.4DProject"
    anchor.write_text(json.dumps({"compatibilityVersion": 2007, "tokenizedText": False}))
    (sources / "catalog.4DCatalog").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<!DOCTYPE base SYSTEM "http://www.4d.com/dtd/2007/base.dtd">'
        f'<base name="{name}" uuid="{uuid.uuid4().hex.upper()}">'
        '<schema name="DEFAULT_SCHEMA"/><base_extra>'
        '<journal_file journal_file_enabled="false"/></base_extra></base>'
    )
    (sources / "folders.json").write_text(json.dumps({"trash": {}}))
    (sources / "dependencies.json").write_text(json.dumps({"dependencies": {}}))
    if namespace:
        (sources / "settings.4DSettings").write_text(
            '<?xml version="1.0" encoding="UTF-8"?><preferences stamp="4">'
            '<com.4d><compiler><options syntax_file="true" target="all"/>'
            '<typage default_for_button="2" default_for_numeric="1"/></compiler>'
            f'<general component_classStore_name="{namespace}"/>'
            "</com.4d></preferences>"
        )
    (directory / "Resources").mkdir(exist_ok=True)
    return anchor


def prepare(directory, baseline, hash_component):
    fixture = directory / "fixture"
    shutil.copytree(ROOT / "tests/4d", fixture)
    anchor = project(fixture, "Integrity")
    for namespace in ("event", "workers", "hash"):
        component = fixture / f"Components/{namespace}.4dbase"
        project(component, namespace, namespace)
    if hash_component:
        destination = fixture / "Components/hash.4dbase"
        shutil.rmtree(destination)
        shutil.copytree(hash_component, destination)
    classes = fixture / "Project/Sources/Classes"
    for name in ("_models", "_Model"):
        relative = f"llama-cpp/Project/Sources/Classes/{name}.4dm"
        if baseline:
            original = subprocess.check_output(
                ["git", "show", f"19616caf06d2db4b6864a2fff444ed473d5f5b0b:{relative}"],
                cwd=ROOT,
            )
            (classes / f"{name}.4dm").write_bytes(original)
        else:
            shutil.copy2(ROOT / relative, classes)
    if baseline:
        (fixture / "Resources/baseline").touch()
    return fixture, anchor


def compile_project(tool4d, driver, anchor, components, directory, label):
    report_path = directory / f"{label}-compile.json"
    config = directory / f"{label}-config.json"
    config.write_text(json.dumps({
        "project": str(anchor), "report": str(report_path),
        "components": [str(path) for path in components],
    }))
    completed = subprocess.run([
        str(tool4d.resolve()), str(driver),
        "--skip-onstartup", "--startup-method=compile_fixture", "--dataless",
        f"--user-param={config}",
    ], capture_output=True, text=True, timeout=120)
    (directory / f"{label}-compiler-stdout.log").write_text(completed.stdout)
    (directory / f"{label}-compiler-stderr.log").write_text(completed.stderr)
    (directory / f"{label}-compiler-exit.txt").write_text(str(completed.returncode))
    if completed.returncode or not report_path.exists():
        raise RuntimeError(f"{label} compiler did not finish cleanly: {directory}")
    report = json.loads(report_path.read_text())
    if report.get("success") is not True or report.get("errors"):
        raise RuntimeError(f"{label} Compile project diagnostics: {report}")


def compile_fixture(tool4d, directory, fixture, anchor, supplied_hash):
    compiler = directory / "compiler"
    shutil.copytree(ROOT / "tests/compiler", compiler)
    driver = project(compiler, "Compiler")
    dependencies = []
    for namespace in ("event", "workers", "hash"):
        component = fixture / f"Components/{namespace}.4dbase"
        if namespace == "hash" and supplied_hash:
            archives = list(component.glob("*.4DZ")) + list(component.glob("*.4dz"))
            if len(archives) != 1:
                raise RuntimeError("Supply the compiled hash.4dbase with exactly one .4DZ")
            dependencies.extend(archives)
            continue
        standalone = directory / "component-sources" / namespace
        standalone.parent.mkdir(exist_ok=True)
        shutil.move(component, standalone)
        component_anchor = standalone / f"Project/{namespace}.4DProject"
        compile_project(tool4d, driver, component_anchor, [], directory, namespace)
        # Preserve compiled code, syntax metadata, and the source catalog. Native
        # libraries/resources remain adjacent to the compiled archive.
        component.mkdir()
        archive = component / f"{namespace}.4DZ"
        project_dir = standalone / "Project"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
            output.write(project_dir, "Project/")
            for path in sorted(project_dir.rglob("*")):
                relative = path.relative_to(project_dir)
                if any(part in {"Classes", "Methods", "Trash"} for part in relative.parts):
                    continue
                if path.suffix in {".log", ".jsonl"}:
                    continue
                name = "Project/" + relative.as_posix()
                output.write(path, name)
        shutil.copytree(standalone / "Resources", component / "Resources")
        libraries = standalone / "Libraries"
        if libraries.exists():
            shutil.copytree(libraries, component / "Libraries")
        dependencies.append(archive)
    compile_project(tool4d, driver, anchor, dependencies, directory, "consumer")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", required=True, type=Path)
    dependency = parser.add_mutually_exclusive_group()
    dependency.add_argument("--hash-component", type=Path)
    dependency.add_argument("--hash-archive", type=Path, help="Verify released component ZIP against dependencies.lock.json")
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--lsp", type=Path)
    parser.add_argument("--compile", action="store_true", help="Compile doubles and actual wrapper to native targets before execution")
    args = parser.parse_args()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="integrity-", dir=build))
    hash_component = (
        reviewed_hash_archive(args.hash_archive, directory)
        if args.hash_archive else args.hash_component
    )
    fixture, anchor = prepare(directory, args.baseline, hash_component)
    result_path = directory / "result.json"
    invocation = [
        str(args.tool4d.resolve()), str(anchor),
        "--skip-onstartup", "--startup-method=smoke", "--dataless",
        "--opening-mode=" + ("compiled" if args.compile else "interpreted"),
        f"--user-param={result_path}",
    ]
    (directory / "invocation.json").write_text(json.dumps(invocation, indent=2))
    print(f"Fixture/evidence: {directory}", flush=True)
    if args.compile:
        if args.baseline:
            raise RuntimeError("Baseline is an interpreted reproduction, not the current fixture compile target")
        compile_fixture(args.tool4d, directory, fixture, anchor, hash_component)
    if args.lsp:
        files = [str(path) for path in (fixture / "Project/Sources").rglob("*.4dm")]
        command = [
            str(args.lsp.resolve()), "validate", "--tool", str(args.tool4d.resolve()),
            "--project", str(anchor), "--json", *files,
        ]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
        (directory / "compiler-stdout.json").write_text(completed.stdout)
        (directory / "compiler-stderr.log").write_text(completed.stderr)
        report = json.loads(completed.stdout)
        errors = [
            diagnostic
            for entry in report
            for diagnostic in entry.get("diagnostics", [])
            if diagnostic.get("severity") == 1
        ]
        if completed.returncode or errors:
            raise RuntimeError(f"4D LSP diagnostics: {errors}; evidence: {directory}")
    completed = subprocess.run(invocation, capture_output=True, text=True, timeout=120)
    (directory / "stdout.log").write_text(completed.stdout)
    (directory / "stderr.log").write_text(completed.stderr)
    (directory / "exit-status.txt").write_text(str(completed.returncode))
    if completed.returncode:
        raise RuntimeError(f"4D exited {completed.returncode}: {directory}")
    if not result_path.exists():
        raise RuntimeError(f"4D did not reach a fresh result checkpoint: {directory}")
    result = json.loads(result_path.read_text())
    print(json.dumps(result, indent=2))
    if result.get("fatal") or result.get("errors"):
        raise RuntimeError(f"4D assertions failed: {directory}")
    if args.baseline:
        if (result.get("corruptStarts") != 1
                or result.get("cacheBytes") != 3 or result.get("cacheContent") != "abd"):
            raise RuntimeError("Baseline did not reproduce equal-size corrupt cache acceptance")
        print("BASELINE REPRODUCED: same-size corrupt cache starts the controlled worker.")
    else:
        if args.compile and result.get("compiledMode") is not True:
            raise RuntimeError("4D silently fell back from compiled execution")
        if result.get("passed", 0) != 35:
            raise RuntimeError("Integrity assertions did not all execute")
        print("PASS: real 4D integrity execution; model transfer/server are controlled doubles.")
        print("Hash dependency: " + ("supplied component" if hash_component else "small-file 4D double"))


if __name__ == "__main__":
    main()
