#!/usr/bin/env python3
"""Fail-closed macOS distribution signing; never push, tag or publish.

Identity isolation and ticket validation adapt the MIT-licensed miyako/hash
scripts/sign-release.py at c0fc53089bea0746434585c152b4448db88512a0.
Copyright (c) 2026 Keisuke Miyako. See scripts/signing-reference-LICENSE.txt.
"""
import argparse
import base64
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import sys
from urllib.parse import quote, quote_plus

SPEC = importlib.util.spec_from_file_location("component_release", Path(__file__).with_name("component-release.py"))
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
GateError = release.GateError
require = release.require
sha256 = release.sha256
ROOT = release.ROOT
TEAM = "Y69CWUC25B"
SECRETS = (
    "APPLE_DEVELOPER_ID_CERTIFICATE", "APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD",
    "KEYCHAIN_PASSWORD", "NOTARYTOOL_APPLE_ID", "NOTARYTOOL_TEAM_ID", "NOTARYTOOL_PASSWORD",
)
ENTITLEMENTS = Path(__file__).with_name("llama-server-entitlements.plist")


class Runner:
    """Never expose argv (which may contain passwords), even on subprocess failure."""

    def __init__(self, secrets, receipts, home=None):
        self.secrets, self.receipts, self.home = secrets, receipts, home
        self.events = []

    def redact(self, text):
        variants = set()
        for value in self.secrets.values():
            if value:
                variants.update((value, json.dumps(value)[1:-1],
                                 quote(value, safe=""), quote_plus(value, safe="")))
        for value in sorted(variants, key=len, reverse=True):
            text = text.replace(value, "[REDACTED]")
        return text

    def run(self, label, command, timeout=120, isolate=True):
        environment = {k: v for k, v in os.environ.items() if k not in SECRETS}
        if self.home and isolate:
            environment.update(HOME=str(self.home), CFFIXED_USER_HOME=str(self.home))
        try:
            result = subprocess.run([str(a) for a in command], capture_output=True,
                                    text=True, errors="replace", timeout=timeout, env=environment)
        except (subprocess.TimeoutExpired, OSError):
            self.events.append({"operation": label, "failed_to_complete": True})
            release.write_json(self.receipts, self.events)
            raise GateError(f"{label} failed to complete") from None
        self.events.append({"operation": label, "returncode": result.returncode,
                            "stdout": self.redact(result.stdout), "stderr": self.redact(result.stderr)})
        release.write_json(self.receipts, self.events)
        require(result.returncode == 0, f"{label} failed; see sanitized signing receipts")
        return result.stdout, result.stderr


def select_identity(output, team):
    identities = []
    for line in output.splitlines():
        match = re.fullmatch(r'\s*\d+\)\s+([A-Fa-f0-9]{40})\s+"([^"]+)"\s*', line)
        if (match and match[2].startswith("Developer ID Application: ")
                and match[2].endswith(f" ({team})")):
            identities.append((match[1], match[2]))
    require(len(identities) == 1, "Expected exactly one imported valid Developer ID Application for team")
    return identities[0]


def signature(runner, path, identity, architectures=None):
    runner.run("verify strict signature", [
        "/usr/bin/codesign", "--verify", "--strict", "--all-architectures", path])
    results = {}
    for arch in sorted(architectures or {None}, key=str):
        args = ["--arch", arch] if arch else []
        stdout, stderr = runner.run("inspect signature", [
            "/usr/bin/codesign", "--display", "--verbose=4", *args, path])
        details = stdout + "\n" + stderr
        fields = dict(re.findall(r"^([A-Za-z]+)=(.*)$", details, re.MULTILINE))
        authorities = re.findall(r"^Authority=(.+)$", details, re.MULTILINE)
        timestamp = fields.get("Timestamp", "").strip()
        cdhash = fields.get("CDHash", "").lower()
        require(fields.get("TeamIdentifier") == TEAM and authorities and authorities[0] == identity
                and timestamp and timestamp.lower() not in {"none", "not set"}
                and "Signature=adhoc" not in details, "Wrong authority, team or secure timestamp")
        require(re.fullmatch(r"[a-f0-9]{40}", cdhash)
                and re.search(r"^Hash type=sha256(?:\s|$)", details, re.MULTILINE),
                "Expected SHA-256 CodeDirectory")
        if arch:
            flags = re.search(r"\bflags=0x([a-fA-F0-9]+)\(([^)]*)\)", details)
            require(flags and int(flags[1], 16) & 0x10000 and "runtime" in flags[2].split(","),
                    "Hardened runtime missing on code slice")
            entitlements, _ = runner.run("inspect payload entitlements", [
                "/usr/bin/codesign", "--display", "--entitlements", ":-", *args, path])
            expected = plistlib.loads(ENTITLEMENTS.read_bytes()) if path.name == "llama-server" else {}
            actual = plistlib.loads(entitlements.encode()) if entitlements.strip() else {}
            require(actual == expected, "Legacy payload entitlement policy changed")
        results[arch or "container"] = {
            "team": TEAM, "authority": identity, "timestamp": timestamp,
            "cdhash": cdhash, "hardened_runtime": bool(arch),
        }
    return results


def validate_ticket(log, dmg, submission, expected):
    require(isinstance(log, dict) and log.get("logFormatVersion") == 1
            and str(log.get("jobId", "")).lower() == submission.lower()
            and log.get("status") == "Accepted" and type(log.get("statusCode")) is int
            and log["statusCode"] == 0 and log.get("archiveFilename") == dmg.name
            and log.get("sha256") == sha256(dmg) and log.get("issues") in (None, []),
            "Notary log status, identity, digest or diagnostics mismatch")
    contents = log.get("ticketContents")
    require(isinstance(contents, list) and contents, "Notary log missing ticket coverage")
    observed = {}
    for item in contents:
        require(isinstance(item, dict) and isinstance(item.get("path"), str)
                and item.get("arch") in {None, "arm64", "x86_64"}
                and item.get("digestAlgorithm") == "SHA-256"
                and isinstance(item.get("cdhash"), str)
                and re.fullmatch(r"[a-fA-F0-9]{40}", item["cdhash"]),
                "Malformed notary ticket")
        key = (item["path"], item.get("arch"))
        digest = item["cdhash"].lower()
        require(key not in observed or observed[key] == digest, "Conflicting notary tickets")
        observed[key] = digest
    require(observed == expected, "Notary tickets do not cover actual container and every payload slice")


def notarize(runner, dmg, keychain, signatures):
    auth = ["--keychain-profile", "llama-component", "--keychain", keychain]
    start = len(runner.events)
    failed = False
    try:
        stdout, _ = runner.run("submit actual signed DMG", [
            "/usr/bin/xcrun", "notarytool", "submit", dmg, *auth, "--wait",
            "--timeout", "1200s", "--output-format", "json"], timeout=1260)
    except GateError:
        failed = True
        stdout = runner.events[-1].get("stdout", "") if len(runner.events) > start else ""
    try:
        result = json.loads(stdout)
    except ValueError:
        raise GateError("No valid structured notarization result") from None
    require(isinstance(result, dict), "Notarization returned no object")
    submission = result.get("id")
    valid_id = isinstance(submission, str) and re.fullmatch(
        r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", submission)
    require(valid_id, "Notarization returned no valid submission ID")
    # Retain diagnostic logs for rejection too; inability to retrieve them remains failure.
    raw_log, _ = runner.run("fetch notarization log", [
        "/usr/bin/xcrun", "notarytool", "log", submission, *auth])
    (release.RELEASE / "notary-log.json").write_text(runner.redact(raw_log) + "\n")
    require(not failed and result.get("status") == "Accepted", "Notarization was not explicitly Accepted")
    expected = {(f"{dmg.name}/llama-cpp.4dbase/{relative}", arch): proof["cdhash"]
                for relative, slices in signatures.items() if relative != dmg.name
                for arch, proof in slices.items()}
    expected[(dmg.name, None)] = signatures[dmg.name]["container"]["cdhash"]
    validate_ticket(json.loads(raw_log), dmg, submission, expected)
    return {"id": submission, "status": "Accepted", "submitted_sha256": sha256(dmg)}


def private_directory():
    require(bool(os.environ.get("RUNNER_TEMP")), "RUNNER_TEMP is required")
    parent = Path(os.environ["RUNNER_TEMP"]).resolve()
    require(parent.is_dir(), "RUNNER_TEMP must already exist")
    return parent / "llama-component-signing"


def detach_private_mount(runner, mount):
    """Recover even if attach mounted successfully before timing out or being interrupted."""
    stdout, _ = runner.run("discover private DMG mount", ["/usr/bin/hdiutil", "info", "-plist"])
    info = plistlib.loads(stdout.encode())
    require(isinstance(info, dict) and isinstance(info.get("images"), list),
            "Cannot determine mounted image state")
    for image in info["images"]:
        for entity in image.get("system-entities", []):
            if entity.get("mount-point") == str(mount):
                runner.run("detach private DMG mount", ["/usr/bin/hdiutil", "detach", mount])
                return


def cleanup():
    private = private_directory()
    require(not private.is_symlink(), "Refusing symlinked signing directory")
    if not private.exists():
        return
    require(private.is_dir(), "Signing recovery path is not a directory")
    home = private / "home"
    keychain = private / "release.keychain-db"
    require(not home.is_symlink() and not keychain.is_symlink(), "Refusing symlinked credential paths")
    runner = Runner({}, release.EVIDENCE / "cleanup-receipts.json", home)
    try:
        detach_private_mount(runner, private / "mount")
    finally:
        try:
            if keychain.exists():
                runner.run("delete abandoned ephemeral keychain", [
                    "/usr/bin/security", "delete-keychain", keychain])
        finally:
            (private / "identity.p12").unlink(missing_ok=True)
            shutil.rmtree(private)


def verify_payload(runner, component, identity, expected_files):
    release.validate_component(component)
    require(release.inventory(component) == expected_files, "Mounted payload differs from signed files")
    result = {}
    for relative, architectures in release.CODE.items():
        path = component / relative
        stdout, _ = runner.run("verify payload architectures", ["/usr/bin/lipo", "-archs", path])
        require(set(stdout.split()) == architectures, "Unexpected payload architecture")
        result[relative] = signature(runner, path, identity, architectures)
        runner.run("require notarized payload", [
            "/usr/bin/codesign", "--verify", "--strict", "--all-architectures",
            "--check-notarization", "-R=notarized", path])
    return result


def sign():
    secrets = {name: os.environ.get(name, "") for name in SECRETS}
    require(all(secrets.values()), "All six existing signing/notary secrets are required")
    require(secrets["NOTARYTOOL_TEAM_ID"] == TEAM, "Unexpected notarization team")
    private = private_directory()
    private.mkdir(mode=0o700)
    home = private / "home"
    runner = Runner(secrets, release.RELEASE / "signing-receipts.json", home)
    keychain = private / "release.keychain-db"
    p12 = private / "identity.p12"
    global_state = {}
    mount = private / "mount"
    attached = False
    signatures = {}
    try:
        (home / "Library/Keychains").mkdir(parents=True)
        (home / "Library/Preferences").mkdir(parents=True)
        for operation in ("list-keychains", "default-keychain", "login-keychain"):
            global_state[operation] = runner.run(
                f"snapshot real-user {operation}", ["/usr/bin/security", operation], isolate=False)
        metadata = json.loads((release.EVIDENCE / "version.json").read_text())
        pre_sign = json.loads((release.EVIDENCE / "pre-sign.json").read_text())
        require(release.inventory(release.COMPONENT) == pre_sign["component_files"],
                "Pre-sign input changed")
        warnings = release.validate_compile(json.loads(
            (release.EVIDENCE / "compiler-status.json").read_text()))
        require(release.run("git", "rev-parse", "HEAD") == metadata["version_commit"],
                "Unexpected version commit")
        release.validate_component(release.COMPONENT)
        stage = private / "component"
        component = stage / "llama-cpp.4dbase"
        shutil.copytree(release.COMPONENT, component)
        certificate = base64.b64decode(secrets["APPLE_DEVELOPER_ID_CERTIFICATE"], validate=True)
        require(bool(certificate), "Empty P12")
        with os.fdopen(os.open(p12, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), "wb") as file:
            file.write(certificate)
        runner.run("create ephemeral keychain", [
            "/usr/bin/security", "create-keychain", "-p", secrets["KEYCHAIN_PASSWORD"], keychain])
        runner.run("set ephemeral keychain timeout", [
            "/usr/bin/security", "set-keychain-settings", "-lut", "21600", keychain])
        runner.run("unlock ephemeral keychain", [
            "/usr/bin/security", "unlock-keychain", "-p", secrets["KEYCHAIN_PASSWORD"], keychain])
        runner.run("import P12", [
            "/usr/bin/security", "import", p12, "-P",
            secrets["APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD"], "-k", keychain,
            "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
        p12.unlink()
        runner.run("authorize imported private key", [
            "/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
            "-s", "-k", secrets["KEYCHAIN_PASSWORD"], keychain])
        runner.run("set isolated keychain search list", [
            "/usr/bin/security", "list-keychains", "-d", "user", "-s",
            keychain, "/Library/Keychains/System.keychain"])
        identities, _ = runner.run("select imported identity", [
            "/usr/bin/security", "find-identity", "-v", "-p", "codesigning", keychain])
        fingerprint, identity = select_identity(identities, TEAM)
        for relative, architectures in release.CODE.items():
            path = component / relative
            stdout, _ = runner.run("inspect original architectures", ["/usr/bin/lipo", "-archs", path])
            require(set(stdout.split()) == architectures, "Original payload architectures changed")
            entitlement_args = ["--entitlements", ENTITLEMENTS] if path.name == "llama-server" else []
            runner.run("sign actual Mach-O payload", [
                "/usr/bin/codesign", "--force", "--sign", fingerprint, "--keychain", keychain,
                "--options", "runtime", "--timestamp", *entitlement_args, path])
            signatures[relative] = signature(runner, path, identity, architectures)
        files = release.inventory(component)
        before = pre_sign["component_files"]
        require(set(files) == set(before)
                and {p for p in before if before[p] != files[p]} <= set(release.CODE),
                "Signing changed non-code resources")
        runner.run("store private notarization profile", [
            "/usr/bin/xcrun", "notarytool", "store-credentials", "llama-component",
            "--keychain", keychain, "--validate", "--apple-id", secrets["NOTARYTOOL_APPLE_ID"],
            "--team-id", TEAM, "--password", secrets["NOTARYTOOL_PASSWORD"]])
        dmg = release.RELEASE / "llama-cpp.dmg"
        archive = release.RELEASE / "llama-cpp.zip"
        runner.run("create actual DMG", [
            "/usr/bin/hdiutil", "create", "-srcfolder", stage, "-volname", "llama-cpp",
            "-fs", "HFS+", "-format", "UDZO", dmg], timeout=300)
        runner.run("sign DMG container", [
            "/usr/bin/codesign", "--force", "--sign", fingerprint,
            "--keychain", keychain, "--timestamp", dmg])
        signatures[dmg.name] = signature(runner, dmg, identity)
        submission = notarize(runner, dmg, keychain, signatures)
        runner.run("staple actual DMG", ["/usr/bin/xcrun", "stapler", "staple", dmg], timeout=180)
        runner.run("validate staple", ["/usr/bin/xcrun", "stapler", "validate", dmg])
        require(signature(runner, dmg, identity) == signatures[dmg.name],
                "Stapling changed the signed CodeDirectory")
        runner.run("Gatekeeper open assessment", [
            "/usr/sbin/spctl", "--assess", "--verbose=4", "--type", "open",
            "--context", "context:primary-signature", dmg])
        mount.mkdir()
        runner.run("mount final DMG read-only", [
            "/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, dmg])
        attached = True
        mounted = mount / "llama-cpp.4dbase"
        verified = verify_payload(runner, mounted, identity, files)
        require(verified == {p: signatures[p] for p in release.CODE},
                "Mounted code signatures differ from signed candidate")
        runner.run("archive actual mounted component", [
            "/usr/bin/ditto", "-c", "-k", "--keepParent", mounted, archive], timeout=300)
        extracted = private / "zip-check"
        runner.run("extract final ZIP for verification", [
            "/usr/bin/ditto", "-x", "-k", archive, extracted], timeout=300)
        require(verify_payload(runner, extracted / "llama-cpp.4dbase", identity, files) == verified,
                "ZIP payload differs from final DMG")
        runner.run("unmount final DMG", ["/usr/bin/hdiutil", "detach", mount])
        attached = False
    finally:
        try:
            if attached or mount.exists():
                detach_private_mount(runner, mount)
        finally:
            try:
                if keychain.exists():
                    runner.run("delete ephemeral keychain", ["/usr/bin/security", "delete-keychain", keychain])
            finally:
                p12.unlink(missing_ok=True)
                shutil.rmtree(private)
                for operation, before_state in global_state.items():
                    require(runner.run(f"assert unchanged real-user {operation}",
                                       ["/usr/bin/security", operation], isolate=False) == before_state,
                            "Real-user keychain state changed")
    shutil.copyfile(release.EVIDENCE / "compiler-status.json", release.RELEASE / "compiler-status.json")
    assets = release.inventory(release.RELEASE)
    require(set(assets) == release.ASSETS - {"provenance.json", "SHA256SUMS"},
            "Unexpected or incomplete final release files")
    provenance = {
        **metadata, "schema": 1, "assets": assets,
        "run_url": f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{metadata['run_id']}",
        "pre_sign": pre_sign, "component_files": files, "signatures": signatures,
        "notarization": submission, "compiler_warning_count": len(warnings),
        "legacy_cli_entitlements_sha256": sha256(ENTITLEMENTS),
        "gates": {"strict_container": True, "accepted": True, "stapled": True,
                  "gatekeeper": True, "mounted_payload": True},
    }
    release.write_json(release.RELEASE / "provenance.json", provenance)
    sums = release.inventory(release.RELEASE)
    (release.RELEASE / "SHA256SUMS").write_text("".join(
        f"{digest}  {name}\n" for name, digest in sorted(sums.items())))
    print("Final DMG/ZIP and final-byte inventory passed; no release or tag has been created.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cleanup", action="store_true")
    args = parser.parse_args()

    def interrupted(signum, frame):
        raise GateError("Signing interrupted; cleanup required")

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        if args.cleanup:
            cleanup()
        else:
            sign()
    except (GateError, OSError, ValueError, subprocess.SubprocessError, plistlib.InvalidFileException):
        # Exception messages from lower-level code may include secret material.
        print("Signing gate failed; inspect sanitized signing/cleanup receipts and compiler evidence.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
