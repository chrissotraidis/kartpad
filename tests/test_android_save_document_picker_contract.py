from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidSaveDocumentPickerContractTests(unittest.TestCase):
    def test_runner_is_guarded_recoverable_and_uses_real_system_ui(self) -> None:
        runner = (
            REPO / "scripts/test-android-save-document-picker-emulator.sh"
        ).read_text()

        self.assertNotIn("pm clear", runner)
        self.assertIn("a real initialized Mario Kart Wii save is required", runner)
        self.assertIn("rksys-documentui-fixture-recovery.dat", runner)
        self.assertIn("the exact Downloads export path already exists", runner)
        self.assertIn('tap_node text "EXPORT SAVE BACKUP…"', runner)
        self.assertIn('tap_node text "RESTORE SAVE BACKUP…"', runner)
        self.assertIn('tap_node text "RESTART NOW"', runner)
        self.assertIn('wait_for_text "Mario Kart Wii"', runner)
        self.assertGreaterEqual(runner.count('am start -W -n "$package/.KartPadActivity"'), 2)
        self.assertIn("automatic prior-save backup does not match", runner)
        self.assertIn("Recovery copy retained", runner)
        self.assertIn("public_export_owned", runner)
        self.assertIn("ui_tree_owned", runner)
        self.assertIn("recovery_created", runner)
        self.assertIn(".KartPadLaunchActivity", runner)


if __name__ == "__main__":
    unittest.main()
