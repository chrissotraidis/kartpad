from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidApi29VulkanContractTests(unittest.TestCase):
    def test_legacy_goldfish_pipeline_creation_is_serialized(self) -> None:
        patch = (
            REPO / "patches/aurora-android-api29-serialized-vulkan.patch"
        ).read_text()
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()

        self.assertIn("android_get_device_api_level() > 29", patch)
        self.assertIn("!pipeline_workers_supported()", patch)
        self.assertIn("Android 10's Goldfish Vulkan transport", patch)
        self.assertNotIn("frame_worker_requested", patch)
        self.assertIn("aurora-android-api29-serialized-vulkan.patch", prepare)


if __name__ == "__main__":
    unittest.main()
