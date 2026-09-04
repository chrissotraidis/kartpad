from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class OfflineKdServicesContractTests(unittest.TestCase):
    def test_patch_gates_only_internet_devices(self) -> None:
        patch = (REPO / "patches/wiicompiled-offline-kd-services.patch").read_text()

        for local_service in (
            '"/dev/net/kd/request"',
            '"/dev/net/ncd/manage"',
        ):
            self.assertIn(local_service, patch)
        self.assertIn("KD request/time and NCD are local Wii system services", patch)
        self.assertIn("if ((isIpTop || isSsl) && !RuntimeConfigFile::NetworkEnabled(true))", patch)
        self.assertNotIn("+    if (!RuntimeConfigFile::NetworkEnabled(true))", patch)

    def test_common_runtime_preparation_applies_patch(self) -> None:
        patch_name = "wiicompiled-offline-kd-services.patch"
        for script_name in (
            "prepare-ios-game-runtime.sh",
            "prepare-g7-game-runtime.sh",
        ):
            script = (REPO / "scripts" / script_name).read_text()
            self.assertIn(patch_name, script, script_name)

        android_script = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()
        self.assertIn("prepare-ios-game-runtime.sh", android_script)


if __name__ == "__main__":
    unittest.main()
