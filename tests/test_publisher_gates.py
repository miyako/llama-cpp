import copy
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


signer = load("sign_component", "sign-component.py")
release = signer.release
TEAM = signer.TEAM
IDENTITY = f"Developer ID Application: Example ({TEAM})"
FINGERPRINT = "A" * 40
SUBMISSION = "11111111-2222-3333-4444-555555555555"


class PublisherTests(unittest.TestCase):
    def test_identity_is_only_exactly_one_valid_imported_team(self):
        valid = f'  1) {FINGERPRINT} "{IDENTITY}"\n  1 valid identities found'
        self.assertEqual(signer.select_identity(valid, TEAM), (FINGERPRINT, IDENTITY))
        for invalid in ("", valid + "\n" + valid, valid.replace(TEAM, "WRONGTEAM"),
                        valid.replace("Developer ID Application:", "Apple Development:"),
                        valid.replace('"', "").replace("valid", "invalid")):
            with self.subTest(invalid=invalid), self.assertRaises(release.GateError):
                signer.select_identity(invalid, TEAM)

    def test_compile_requires_success_and_explicit_warning_classification(self):
        warning = {"isError": False, "message": "External class metadata missing (550.4)"}
        self.assertEqual(release.validate_compile({"success": True, "errors": [warning]}), [warning])
        for status in ({}, {"success": False, "errors": []}, {"success": 1, "errors": []},
                       {"success": True}, {"success": True, "errors": [{"isError": True}]},
                       {"success": True, "errors": [{}]}):
            with self.subTest(status=status), self.assertRaises(release.GateError):
                release.validate_compile(status)

    def test_normal_version_uses_actual_latest_and_valid_modes(self):
        self.assertEqual(release.next_version("20.5.24", "20.5.27", "patch"), "20.5.28")
        self.assertEqual(release.next_version("20.5.24", "20.5.27", "minor"), "20.6.0")
        self.assertEqual(release.next_version("20.5.24", "20.5.27", "major"), "21.0.0")
        with self.assertRaises(release.GateError):
            release.next_version("20.5.24", "v20.5.27", "patch")

    def test_receipts_redact_secrets_and_child_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            sentinel = "secret with & symbols"
            runner = signer.Runner({"KEYCHAIN_PASSWORD": sentinel}, path / "receipt.json", path / "home")
            result = subprocess.CompletedProcess([], 1, sentinel, sentinel)
            with patch.dict(os.environ, {"KEYCHAIN_PASSWORD": sentinel}), \
                    patch.object(signer.subprocess, "run", return_value=result) as invoke:
                with self.assertRaises(release.GateError) as error:
                    runner.run("safe operation", ["security", "-p", sentinel])
            self.assertNotIn(sentinel, str(error.exception))
            self.assertNotIn(sentinel, runner.receipts.read_text())
            self.assertNotIn("KEYCHAIN_PASSWORD", invoke.call_args.kwargs["env"])
            self.assertEqual(invoke.call_args.kwargs["env"]["HOME"], str(path / "home"))
            self.assertEqual(invoke.call_args.kwargs["env"]["CFFIXED_USER_HOME"], str(path / "home"))

    def test_subprocess_timeout_never_prints_secret_argv(self):
        with tempfile.TemporaryDirectory() as temporary:
            runner = signer.Runner({"KEYCHAIN_PASSWORD": "sentinel"}, Path(temporary) / "receipt.json")
            with patch.object(signer.subprocess, "run",
                              side_effect=subprocess.TimeoutExpired(["sentinel"], 1)):
                with self.assertRaises(release.GateError) as error:
                    runner.run("safe timeout", ["sentinel"])
            self.assertNotIn("sentinel", str(error.exception) + runner.receipts.read_text())

    def test_ticket_requires_accepted_digest_and_every_slice(self):
        with tempfile.TemporaryDirectory() as temporary:
            dmg = Path(temporary) / "llama-cpp.dmg"
            dmg.write_bytes(b"signed-not-yet-stapled")
            digest = "b" * 40
            expected = {(dmg.name, None): digest}
            log = {
                "logFormatVersion": 1, "jobId": SUBMISSION, "status": "Accepted", "statusCode": 0,
                "archiveFilename": dmg.name, "sha256": release.sha256(dmg), "issues": None,
                "ticketContents": [{"path": dmg.name, "arch": None, "cdhash": digest,
                                    "digestAlgorithm": "SHA-256"}],
            }
            signer.validate_ticket(log, dmg, SUBMISSION, expected)
            for field, value in (("status", "Rejected"), ("jobId", "other"), ("statusCode", 1),
                                 ("archiveFilename", "other.dmg"), ("sha256", "0" * 64),
                                 ("issues", [{"message": "problem"}]), ("ticketContents", [])):
                with self.subTest(field=field), self.assertRaises(release.GateError):
                    signer.validate_ticket({**log, field: value}, dmg, SUBMISSION, expected)
            with self.assertRaises(release.GateError):
                signer.validate_ticket(log, dmg, SUBMISSION, {**expected, ("payload", "arm64"): digest})
            dmg.write_bytes(b"stapling-changed-bytes")
            with self.assertRaises(release.GateError):
                signer.validate_ticket(log, dmg, SUBMISSION, expected)

    def test_notary_exit_zero_is_not_acceptance_and_keeps_rejection_log(self):
        class FakeRunner:
            events = []

            def run(self, label, command, **kwargs):
                if "submit" in command:
                    return json.dumps({"id": SUBMISSION, "status": "Invalid"}), ""
                return json.dumps({"status": "Invalid", "issues": ["diagnostic"]}), ""

            def redact(self, text):
                return text

        with tempfile.TemporaryDirectory() as temporary, \
                patch.object(release, "RELEASE", Path(temporary)):
            with self.assertRaisesRegex(release.GateError, "explicitly Accepted"):
                signer.notarize(FakeRunner(), Path(temporary) / "llama-cpp.dmg", "private", {})
            self.assertIn("diagnostic", (Path(temporary) / "notary-log.json").read_text())

    def test_signature_requires_team_timestamp_hardened_runtime_and_legacy_entitlements(self):
        class FakeRunner:
            details = (
                f"Authority={IDENTITY}\nTeamIdentifier={TEAM}\nTimestamp=Nov 4, 2026\n"
                f"CDHash={'a' * 40}\nHash type=sha256 size=32\nCodeDirectory v=20500 flags=0x10000(runtime)\n")

            def run(self, label, command):
                if "--entitlements" in command:
                    return plistlib.dumps(plistlib.loads(signer.ENTITLEMENTS.read_bytes())).decode(), ""
                return "", self.details

        runner = FakeRunner()
        signer.signature(runner, Path("llama-server"), IDENTITY, {"arm64"})
        original = runner.details
        for invalid in (original.replace(TEAM, "WRONGTEAM"),
                        original.replace("Timestamp=Nov 4, 2026", "Timestamp=none"),
                        original.replace("flags=0x10000(runtime)", "flags=0x0(none)"),
                        original.replace("Hash type=sha256", "Hash type=sha1")):
            runner.details = invalid
            with self.assertRaises(release.GateError):
                signer.signature(runner, Path("llama-server"), IDENTITY, {"arm64"})

    def test_handoff_rejects_missing_gates_wrong_run_and_changed_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for name in release.ASSETS - {"provenance.json", "SHA256SUMS"}:
                (folder / name).write_bytes(b"final")
            release.write_json(folder / "compiler-status.json", {"success": True, "errors": []})
            proof = {
                "source_revision": "source", "version_commit": "version", "version": "20.5.25",
                "run_id": "run", "run_attempt": "1", "assets": release.inventory(folder),
                "gates": {"strict_container": True, "accepted": True, "stapled": True,
                          "gatekeeper": True, "mounted_payload": True},
            }

            def write(provenance):
                release.write_json(folder / "provenance.json", provenance)
                files = {**provenance["assets"], "provenance.json": release.sha256(folder / "provenance.json")}
                (folder / "SHA256SUMS").write_text("".join(
                    f"{digest}  {name}\n" for name, digest in sorted(files.items())))

            def verify():
                release.verify_handoff(folder, "source", "version", "20.5.25", "run", "1")

            write(proof)
            verify()
            for gate in proof["gates"]:
                invalid = copy.deepcopy(proof)
                invalid["gates"][gate] = False
                write(invalid)
                with self.subTest(gate=gate), self.assertRaises(release.GateError):
                    verify()
            write({**proof, "run_attempt": "2"})
            with self.assertRaises(release.GateError):
                verify()
            write(proof)
            (folder / "llama-cpp.dmg").write_bytes(b"mutated after inventory")
            with self.assertRaises(release.GateError):
                verify()

    def test_publication_forbidden_outside_trusted_main(self):
        with patch.dict(os.environ, {"GITHUB_REF": "refs/heads/feature", "GITHUB_EVENT_NAME": "workflow_dispatch"}):
            with self.assertRaisesRegex(release.GateError, "trusted main"):
                release.publish(Path("unused"))
        with patch.dict(os.environ, {"GITHUB_REF": "refs/heads/main", "GITHUB_EVENT_NAME": "pull_request"}):
            with self.assertRaisesRegex(release.GateError, "trusted main"):
                release.publish(Path("unused"))

    def test_local_version_commit_bundle_round_trip(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            subprocess.run(["git", "init", "-q", source], check=True)
            release.run("git", "config", "user.name", "Fixture", cwd=source)
            release.run("git", "config", "user.email", "fixture@example.invalid", cwd=source)
            (source / "package.json").write_text('{"version":"20.5.24"}')
            release.run("git", "add", ".", cwd=source)
            release.run("git", "commit", "-qm", "source", cwd=source)
            base = release.run("git", "rev-parse", "HEAD", cwd=source)
            (source / "package.json").write_text('{"version":"20.5.25"}')
            release.run("git", "commit", "-qam", "version", cwd=source)
            version = release.run("git", "rev-parse", "HEAD", cwd=source)
            bundle = root / "version.bundle"
            release.run("git", "bundle", "create", bundle, "HEAD", f"^{base}", cwd=source)
            clone = root / "clone"
            release.run("git", "clone", "-q", source, clone, cwd=root)
            release.run("git", "fetch", bundle, "HEAD", cwd=clone)
            self.assertEqual(release.run("git", "rev-parse", "FETCH_HEAD", cwd=clone), version)
            self.assertEqual(release.run("git", "rev-parse", f"{version}^", cwd=clone), base)

    def test_workflow_trust_and_same_run_handoff(self):
        workflow = (ROOT / ".github/workflows/publish.yml").read_text()
        self.assertNotIn("pull_request:", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("needs: candidate", workflow)
        self.assertIn("github.ref == 'refs/heads/main'", workflow)
        self.assertIn("if: always()\n        run: python3 scripts/sign-component.py --cleanup", workflow)
        self.assertNotIn("CODESIGN_APPLE_ID", workflow)
        self.assertNotIn("continue-on-error", workflow)
        self.assertNotIn("deployment-release-assets@", workflow)
        checks = (ROOT / ".github/workflows/test-publisher.yml").read_text()
        self.assertNotIn("secrets.", checks)
        self.assertNotIn("contents: write", checks)


class SigningPipelineTests(unittest.TestCase):
    """Stubbed orchestration is deliberately not real Apple signing acceptance."""

    def exercise(self, failure=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        component = root / "original/llama-cpp.4dbase"
        component.mkdir(parents=True)
        for relative in release.CODE:
            path = component / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"original")
        evidence = root / "evidence"
        evidence.mkdir()
        output = root / "release"
        output.mkdir()
        release.write_json(evidence / "version.json", {
            "version": "20.5.25", "source_revision": "source", "version_commit": "version",
            "run_id": "run", "run_attempt": "1",
        })
        release.write_json(evidence / "compiler-status.json", {"success": True, "errors": []})
        release.write_json(evidence / "pre-sign.json", {"component_files": release.inventory(component)})
        operations = []
        test = self

        class FakeRunner:
            def __init__(self, secrets, receipts, home):
                self.receipts = receipts

            def run(self, label, command, **kwargs):
                operations.append(label)
                if label == failure:
                    raise release.GateError(label)
                release.write_json(self.receipts, operations)
                if label == "select imported identity":
                    return f'1) {FINGERPRINT} "{IDENTITY}"', ""
                if label == "inspect original architectures":
                    relative = ("Resources/bin/macOS/llama-server" if Path(command[-1]).name == "llama-server"
                                else "Libraries/lib4d-arm64.dylib")
                    return " ".join(sorted(release.CODE[relative])), ""
                if label == "create ephemeral keychain":
                    Path(command[-1]).touch()
                if label == "sign actual Mach-O payload":
                    Path(command[-1]).write_bytes(b"signed")
                if label == "create actual DMG":
                    Path(command[-1]).write_bytes(b"container")
                if label == "staple actual DMG":
                    Path(command[-1]).write_bytes(b"container stapled")
                if label == "archive actual mounted component":
                    Path(command[-1]).write_bytes(b"ZIP final")
                return "global keychain unchanged", ""

        def fake_notary(runner, dmg, keychain, signatures):
            operations.append("notarize")
            if failure == "notarize":
                raise release.GateError("rejected")
            release.write_json(output / "notary-log.json", {"status": "Accepted"})
            return {"status": "Accepted", "submitted_sha256": release.sha256(dmg)}

        def fake_signature(runner, path, identity, architectures=None):
            test.assertEqual(identity, IDENTITY)
            return {arch: {"cdhash": "a" * 40} for arch in architectures or {"container"}}

        def fake_payload(runner, path, identity, files):
            return {relative: fake_signature(runner, Path(relative), identity, arch)
                    for relative, arch in release.CODE.items()}

        secrets = {name: "Zml4dHVyZQ==" for name in signer.SECRETS}
        secrets.update(NOTARYTOOL_TEAM_ID=TEAM, RUNNER_TEMP=str(root), GITHUB_REPOSITORY="fixture/repo")
        with patch.dict(os.environ, secrets), \
                patch.object(release, "COMPONENT", component), \
                patch.object(release, "EVIDENCE", evidence), \
                patch.object(release, "RELEASE", output), \
                patch.object(release, "run", return_value="version"), \
                patch.object(release, "validate_component"), \
                patch.object(signer, "Runner", FakeRunner), \
                patch.object(signer, "signature", side_effect=fake_signature), \
                patch.object(signer, "notarize", side_effect=fake_notary), \
                patch.object(signer, "verify_payload", side_effect=fake_payload):
            if failure:
                with self.assertRaises(release.GateError):
                    signer.sign()
                self.assertFalse((output / "provenance.json").exists())
                self.assertFalse((output / "SHA256SUMS").exists())
            else:
                signer.sign()
            self.assertFalse(signer.private_directory().exists())
        self.assertIn("delete ephemeral keychain", operations)
        return operations, output

    def test_checksum_is_after_stapling_verification_archive_and_cleanup(self):
        operations, output = self.exercise()
        proof = json.loads((output / "provenance.json").read_text())
        self.assertEqual(proof["assets"]["llama-cpp.dmg"], release.sha256(output / "llama-cpp.dmg"))
        self.assertNotEqual(proof["notarization"]["submitted_sha256"], proof["assets"]["llama-cpp.dmg"])
        self.assertLess(operations.index("sign DMG container"), operations.index("notarize"))
        self.assertLess(operations.index("notarize"), operations.index("staple actual DMG"))
        self.assertLess(operations.index("validate staple"), operations.index("Gatekeeper open assessment"))
        self.assertLess(operations.index("Gatekeeper open assessment"), operations.index("mount final DMG read-only"))
        self.assertLess(operations.index("archive actual mounted component"), operations.index("delete ephemeral keychain"))

    def test_each_gate_failure_blocks_inventory_and_cleans_credentials(self):
        for failure in ("sign actual Mach-O payload", "sign DMG container", "notarize",
                        "staple actual DMG", "validate staple", "Gatekeeper open assessment",
                        "mount final DMG read-only", "archive actual mounted component",
                        "extract final ZIP for verification"):
            with self.subTest(failure=failure):
                self.exercise(failure)


if __name__ == "__main__":
    unittest.main()
