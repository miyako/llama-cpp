#!/usr/bin/env python3
"""Normal component version/build/publication; no native rebuild or signing secrets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build"
EVIDENCE = BUILD / "evidence"
RELEASE = BUILD / "release"
COMPONENT = ROOT / "Components/llama-cpp.4dbase"
COMPILER = "b73a89a9eac2636f59bcbd020ccf0aad954cab64"
CODE = {
    "Libraries/lib4d-arm64.dylib": {"arm64"},
    "Resources/bin/macOS/llama-server": {"arm64", "x86_64"},
}
MACHO = {bytes.fromhex(m) for m in (
    "feedface", "cefaedfe", "feedfacf", "cffaedfe",
    "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
ASSETS = {"llama-cpp.dmg", "llama-cpp.zip", "provenance.json", "SHA256SUMS",
          "compiler-status.json", "notary-log.json", "signing-receipts.json"}


class GateError(RuntimeError):
    pass


def run(*args, cwd=ROOT, timeout=120):
    return subprocess.check_output(
        [str(a) for a in args], cwd=cwd, text=True, timeout=timeout).strip()


def sha256(path):
    with path.open("rb") as source:
        digest = hashlib.sha256()
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
        return digest.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha256(p)
            for p in sorted(folder.rglob("*")) if p.is_file()}


def require(condition, message):
    if not condition:
        raise GateError(message)


def next_version(current, latest, mode):
    def parse(value):
        require(bool(re.fullmatch(r"\d+\.\d+\.\d+", value)), "Non-normal release version")
        return tuple(map(int, value.split(".")))
    version = list(max(parse(current), parse(latest)))
    index = {"major": 0, "minor": 1, "patch": 2}[mode]
    version[index] += 1
    for i in range(index + 1, 3):
        version[i] = 0
    return ".".join(map(str, version))


def prepare(mode):
    require(not run("git", "status", "--porcelain", "--untracked-files=no"),
            "Publisher source must be clean")
    source = run("git", "rev-parse", "HEAD")
    require(source == os.environ["GITHUB_SHA"], "Checkout does not match dispatched source")
    EVIDENCE.mkdir(parents=True, exist_ok=False)
    RELEASE.mkdir(parents=True, exist_ok=False)
    package = json.loads((ROOT / "package.json").read_text())
    latest = json.loads(run("gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/releases/latest"))
    package["version"] = next_version(package["version"], latest["tag_name"], mode)
    write_json(ROOT / "package.json", package)
    run("git", "config", "--local", "user.name", "GitHub Action")
    run("git", "config", "--local", "user.email", "action@github.com")
    run("git", "add", "--", "package.json")
    run("git", "commit", "-m", package["version"],
        "-m", "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>")
    version_commit = run("git", "rev-parse", "HEAD")
    run("git", "bundle", "create", EVIDENCE / "version-commit.bundle", "HEAD", f"^{source}")
    write_json(EVIDENCE / "version.json", {
        "version": package["version"], "source_revision": source,
        "version_commit": version_commit, "previous_latest": latest["tag_name"],
        "run_id": os.environ["GITHUB_RUN_ID"], "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
    })
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"version={package['version']}\nversion_commit={version_commit}\n")


def validate_compile(status):
    require(isinstance(status, dict) and status.get("success") is True,
            "Compile project did not explicitly succeed")
    diagnostics = status.get("errors")
    require(isinstance(diagnostics, list), "Missing compiler diagnostics collection")
    for item in diagnostics:
        require(isinstance(item, dict) and item.get("isError") is False,
                "Actual or unclassified compiler error")
    return diagnostics


def validate_component(component):
    require(component.is_dir(), "Compiled component is absent")
    code = set()
    for path in component.rglob("*"):
        require(not path.is_symlink(), "Unexpected symlink in component")
        if path.is_file():
            with path.open("rb") as source:
                if source.read(4) in MACHO:
                    code.add(path.relative_to(component).as_posix())
    require(code == set(CODE), "Unexpected or missing macOS code object")
    archives = [p for p in component.iterdir() if p.suffix.lower() == ".4dz"]
    require(len(archives) == 1, "Expected exactly one compiled .4DZ")
    with zipfile.ZipFile(archives[0]) as archive:
        names = archive.namelist()
        require(any("MX64" in n for n in names) and any("IX64" in n for n in names),
                "Compiled .4DZ lacks Mac/Windows code")
        dependencies = [n for n in names if n.endswith("/dependencies.json")]
        require(len(dependencies) == 1, "Missing compiled dependency declaration")
        pin = json.loads(archive.read(dependencies[0]))["dependencies"]["hash"]
        require(pin == {"github": "miyako/hash", "tag": "20.0.1"},
                "Exact hash20.0.1 dependency changed")
    for platform in ("Windows", "WindowsARM"):
        relative = f"Resources/bin/{platform}/llama-server.exe"
        require(sha256(component / relative) == sha256(ROOT / "llama-cpp" / relative),
                "Legacy Windows binary changed")


def build():
    compiler = BUILD / "compiler"
    require(run("git", "rev-parse", "HEAD", cwd=compiler) == COMPILER,
            "Unexpected compiler revision")
    require(not run("git", "status", "--porcelain", cwd=compiler), "Compiler checkout is dirty")
    method = compiler / "Project/Sources/Classes/BuildApp_CLI.4dm"
    text = method.read_text(encoding="utf-8-sig")
    marker = "\t\t$status:=Compile project:C1760($compileProject; $options)"
    require(text.count(marker) == 1, "Reviewed compiler status hook changed")
    report = EVIDENCE / "compiler-status.json"
    require(not report.exists() and not COMPONENT.exists(), "Stale compiler output")
    # Export the actual status from the existing compile call, not a second compilation.
    hook = f'\n\t\tFile:C1566("{report}"; fk posix path:K87:1).setText(JSON Stringify:C1217($status))'
    method.write_text(text.replace(marker, marker + hook))
    command = [ROOT / "tool4d.app/Contents/MacOS/tool4d",
               compiler / "Project/compiler.4DProject", "--skip-onstartup",
               "--startup-method=component_zip",
               f"--user-param={ROOT / 'llama-cpp/Project/llama-cpp.4DProject'},{ROOT}", "--dataless"]
    with (EVIDENCE / "compiler.log").open("w") as log:
        result = subprocess.run([str(a) for a in command], cwd=ROOT, stdout=log,
                                stderr=subprocess.STDOUT, timeout=600)
    require(result.returncode == 0, f"Compiler process exited {result.returncode}; see compiler.log")
    require(report.is_file(), "Fresh structured compiler status was not emitted")
    warnings = validate_compile(json.loads(report.read_text()))
    print(f"Compile succeeded with {len(warnings)} acknowledged nonfatal warnings; retained verbatim.")
    validate_component(COMPONENT)
    write_json(EVIDENCE / "pre-sign.json", {
        "component_files": inventory(COMPONENT), "compiler_revision": COMPILER,
        "tool4d_sha256": sha256(command[0]),
        "tool4d_version_output": run(command[0], "--version"),
        "compiler_warning_count": len(warnings),
    })


def verify_handoff(folder, expected_source, expected_commit, expected_version, run_id, attempt):
    provenance = json.loads((folder / "provenance.json").read_text())
    require(provenance.get("source_revision") == expected_source
            and provenance.get("version_commit") == expected_commit
            and provenance.get("version") == expected_version
            and provenance.get("run_id") == run_id and provenance.get("run_attempt") == attempt,
            "Candidate does not belong to this exact source/version/run")
    require(provenance.get("gates") == {
        "strict_container": True, "accepted": True, "stapled": True,
        "gatekeeper": True, "mounted_payload": True}, "Incomplete candidate gates")
    files = provenance.get("assets")
    require(isinstance(files, dict) and set(files) == ASSETS - {"provenance.json", "SHA256SUMS"},
            "Incomplete final asset inventory")
    for name, digest in files.items():
        require(sha256(folder / name) == digest, f"Final-byte checksum mismatch: {name}")
    expected_sums = {**files, "provenance.json": sha256(folder / "provenance.json")}
    require((folder / "SHA256SUMS").read_text() == "".join(
        f"{digest}  {name}\n" for name, digest in sorted(expected_sums.items())),
        "SHA256SUMS does not describe the final handoff")
    validate_compile(json.loads((folder / "compiler-status.json").read_text()))
    return provenance


def publish(handoff):
    require(os.environ["GITHUB_REF"] == "refs/heads/main"
            and os.environ["GITHUB_EVENT_NAME"] in {"workflow_dispatch", "push"},
            "Only trusted main publication is permitted")
    folder = handoff / "release"
    metadata = json.loads((handoff / "evidence/version.json").read_text())
    proof = verify_handoff(
        folder, os.environ["GITHUB_SHA"], os.environ["EXPECTED_VERSION_COMMIT"],
        os.environ["EXPECTED_VERSION"], os.environ["GITHUB_RUN_ID"],
        os.environ["GITHUB_RUN_ATTEMPT"])
    require(metadata["version_commit"] == proof["version_commit"], "Bundle metadata mismatch")
    run("git", "fetch", handoff / "evidence/version-commit.bundle", "HEAD")
    commit = run("git", "rev-parse", "FETCH_HEAD")
    require(commit == proof["version_commit"]
            and run("git", "rev-parse", f"{commit}^") == proof["source_revision"],
            "Version commit is not a direct child of reviewed source")
    require(run("git", "diff", "--name-only", proof["source_revision"], commit) == "package.json",
            "Version commit changed more than package.json")
    original = json.loads(run("git", "show", f"{proof['source_revision']}:package.json"))
    versioned = json.loads(run("git", "show", f"{commit}:package.json"))
    original["version"] = proof["version"]
    require(original == versioned, "Version commit contains unexpected package changes")
    require(run("git", "ls-remote", "origin", "refs/heads/main").split()[0]
            == proof["source_revision"], "Main moved; dispatch a fresh candidate (no rebase/force)")
    repository = os.environ["GITHUB_REPOSITORY"]
    latest = json.loads(run("gh", "api", f"repos/{repository}/releases/latest"))
    require(latest["tag_name"] == metadata["previous_latest"],
            "Latest release moved; dispatch a fresh version candidate")
    version = proof["version"]
    require(not run("git", "ls-remote", "origin", f"refs/tags/{version}"),
            "Release tag already exists; never overwrite")
    run("git", "tag", version, commit)
    # The server rejects a concurrent non-fast-forward branch update, atomically with the new tag.
    run("git", "push", "--atomic", "origin", f"{commit}:refs/heads/main", f"refs/tags/{version}")
    run("gh", "release", "create", version, "--verify-tag", "--draft",
        "--target", commit, "--title", version, "--notes",
        f"Signed/stapled component distribution.\n\nReviewed source: `{proof['source_revision']}`\n"
        f"Version commit: `{commit}`\nPublisher: {proof['run_url']}\n"
        f"Compiler: success with {proof['compiler_warning_count']} acknowledged nonfatal warnings.\n"
        "See provenance.json, compiler-status.json, notary-log.json and SHA256SUMS.",
        *[folder / name for name in sorted(ASSETS)], timeout=300)
    download = BUILD / "draft-download"
    download.mkdir()
    run("gh", "release", "download", version, "--dir", download, timeout=300)
    require(inventory(download) == {name: sha256(folder / name) for name in ASSETS},
            "Draft upload bytes differ from gated candidate; release remains draft")
    run("gh", "release", "edit", version, "--draft=false", "--latest")
    print(f"https://github.com/{repository}/releases/tag/{version}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare_parser = sub.add_parser("prepare")
    prepare_parser.add_argument("--mode", choices=["patch", "minor", "major"], required=True)
    sub.add_parser("build")
    publish_parser = sub.add_parser("publish")
    publish_parser.add_argument("--handoff", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare(args.mode)
        elif args.command == "build":
            build()
        else:
            publish(args.handoff.resolve())
    except (GateError, OSError, ValueError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(f"Publisher failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
