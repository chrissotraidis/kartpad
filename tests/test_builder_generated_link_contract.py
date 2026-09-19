from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class BuildScriptContractTests(unittest.TestCase):
    def test_generated_link_tracks_the_runtime_workspace(self) -> None:
        for relative in (
            "scripts/prepare-g7-game-runtime.sh",
            "scripts/prepare-ios-game-runtime.sh",
            "scripts/build-ios-game-app.sh",
            "scripts/build-ios-device-game-app.sh",
        ):
            script = (REPO / relative).read_text()
            self.assertIn(
                'generated_link="$(dirname "${runtime_source}")/generated"',
                script,
                relative,
            )
            self.assertNotIn('generated_link="${repo_root}/build/generated"', script, relative)


if __name__ == "__main__":
    unittest.main()
