from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidSaveStorageEmulatorContractTests(unittest.TestCase):
    def test_fixture_is_synthetic_isolated_and_restores_selector(self) -> None:
        fixture = (
            REPO
            / "android/app/src/debug/java/dev/kartpad/android/KartPadSaveStorageFixtureActivity.kt"
        ).read_text()
        runner = (REPO / "scripts/test-android-save-storage-emulator.sh").read_text()

        self.assertIn('File(cacheDir, "save-storage-fixture")', fixture)
        self.assertIn("KartPadSaveStorage.readActive(root)", fixture)
        self.assertIn("KartPadSaveStorage.writePending(root, replacement)", fixture)
        self.assertIn("KartPadSaveStorage.applyPending(root)", fixture)
        self.assertIn("backup=preserved", fixture)
        self.assertIn("checksum-corrupt save was accepted", fixture)
        self.assertNotIn("pm clear", runner)
        self.assertIn(".KartPadLaunchActivity", runner)
        self.assertIn("GameData/sys/main.dol", runner)


if __name__ == "__main__":
    unittest.main()
