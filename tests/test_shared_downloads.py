import hashlib
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import retro_rewind  # noqa: E402

DATA = b"synthetic pinned download"
SHA = hashlib.sha256(DATA).hexdigest()


class SharedDownloadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        patch = mock.patch.dict(os.environ, {"PADMINT_CACHE": str(self.root / "cache")})
        patch.start()
        self.addCleanup(patch.stop)

    def test_a_download_is_shared_then_reused_by_the_next_version(self):
        first = self.root / "kartpad-v1/private/builder/retro-rewind-downloads/pack.zip"
        first.parent.mkdir(parents=True)
        first.write_bytes(DATA)
        retro_rewind._share(first)
        second = self.root / "kartpad-v2/private/builder/retro-rewind-downloads/pack.zip"
        self.assertTrue(retro_rewind._reuse_shared(second, len(DATA), SHA))
        self.assertEqual(second.read_bytes(), DATA)

    def test_a_cached_copy_that_does_not_match_is_ignored(self):
        shared = self.root / "cache/kartpad/retro-rewind-downloads/pack.zip"
        shared.parent.mkdir(parents=True)
        shared.write_bytes(b"tampered")
        target = self.root / "v2/pack.zip"
        self.assertFalse(retro_rewind._reuse_shared(target, len(DATA), SHA))
        self.assertFalse(retro_rewind._reuse_shared(target, len(b"tampered"), SHA))
        self.assertFalse(target.exists())

    def test_without_padmint_nothing_is_shared(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(retro_rewind._shared_path("pack.zip"))
            self.assertFalse(retro_rewind._reuse_shared(self.root / "x.zip", len(DATA), SHA))

    def test_padmint_before_the_rename_still_shares_its_cache(self):
        with mock.patch.dict(os.environ, {"PADFORGE_CACHE": str(self.root / "old")}, clear=True):
            self.assertEqual(retro_rewind._shared_path("pack.zip").parents[2], self.root / "old")


if __name__ == "__main__":
    unittest.main()
