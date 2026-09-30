from __future__ import annotations

from runtime_sources import runtime_source, assert_runtime_staging
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidApi29VulkanContractTests(unittest.TestCase):
    def test_legacy_goldfish_pipeline_creation_is_serialized(self) -> None:
        patch = runtime_source('android', 'aurora-main/lib/gfx/pipeline_cache.cpp')
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()

        self.assertIn("android_get_device_api_level() > 29", patch)
        self.assertIn("!pipeline_workers_supported()", patch)
        self.assertIn("Goldfish Vulkan transport", patch)
        # Only the emulator serializes; physical Android 9/10 phones keep their
        # compile workers (runtime c1c9cff, issue #320).
        self.assertIn('std::strcmp(hardware, "ranchu") != 0', patch)
        self.assertIn('std::strcmp(hardware, "goldfish") != 0', patch)
        self.assertNotIn("frame_worker_requested", patch)
        assert_runtime_staging(self, 'android')


if __name__ == "__main__":
    unittest.main()
