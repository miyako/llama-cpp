import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("integrity_tools", ROOT / "scripts/test-download-integrity.py")
TOOLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOLS)


class ReviewedArchiveTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".build").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="archive-test-", dir=ROOT / ".build")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.archive = self.root / "hash.zip"
        self.output = self.root / "evidence"
        self.output.mkdir()
        root_patch = patch.object(TOOLS, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)

    def lock(self, checksum=None):
        value = checksum or hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.root / "dependencies.lock.json").write_text(json.dumps({
            "hash": {"version": "20.0.1", "artifact": {"sha256": value}},
        }))

    def test_exact_bytes_and_permissions(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("hash.4dbase/hash.4DZ", b"fixture, not executable 4D code")
            executable = zipfile.ZipInfo("hash.4dbase/Resources/bin/macOS/hash")
            executable.external_attr = 0o100755 << 16
            archive.writestr(executable, b"fixture")
        self.lock()
        chmod = Path.chmod
        with patch.object(Path, "chmod", autospec=True, side_effect=chmod) as permissions:
            component = TOOLS.reviewed_hash_archive(self.archive, self.output)
            executable = component / "Resources/bin/macOS/hash"
            permissions.assert_any_call(executable, 0o755)
        self.assertEqual(component.name, "hash.4dbase")
        self.assertTrue((self.output / "hash-artifact.json").exists())
        self.assertEqual(executable.read_bytes(), b"fixture")
        if os.name != "nt":
            self.assertEqual(executable.stat().st_mode & 0o777, 0o755)

    def test_wrong_archive_digest_blocks_before_extraction(self):
        self.archive.write_bytes(b"not the approved bytes")
        self.lock("0" * 64)
        with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
            TOOLS.reviewed_hash_archive(self.archive, self.output)
        self.assertFalse((self.output / "reviewed-hash").exists())

    def test_parent_path_is_rejected(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("../escaped", b"must not be written")
        self.lock()
        with self.assertRaisesRegex(RuntimeError, "Unsafe component archive path"):
            TOOLS.reviewed_hash_archive(self.archive, self.output)
        self.assertFalse((self.output / "escaped").exists())

    def test_symlink_is_rejected(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            link = zipfile.ZipInfo("hash.4dbase/link")
            link.external_attr = 0o120777 << 16
            archive.writestr(link, "/outside")
        self.lock()
        with self.assertRaisesRegex(RuntimeError, "Unexpected component symlink"):
            TOOLS.reviewed_hash_archive(self.archive, self.output)

    def test_ambiguous_component_is_rejected(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            for name in ("first", "second"):
                archive.writestr(f"{name}.4dbase/hash.4DZ", b"fixture")
        self.lock()
        with self.assertRaisesRegex(RuntimeError, "exactly one"):
            TOOLS.reviewed_hash_archive(self.archive, self.output)


if __name__ == "__main__":
    unittest.main()
