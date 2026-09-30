"""A fresh Android install asks for game data instead of reporting a missing file."""

import pathlib
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
SOURCE = REPO / "android/app/src/main/java/dev/kartpad/android"


class FreshInstallPromptTest(unittest.TestCase):
    def test_absent_game_data_shows_import_prompt_before_errors(self):
        storage = (SOURCE / "KartPadGameDataStorage.kt").read_text()
        launcher = (SOURCE / "KartPadLaunchActivity.kt").read_text()
        self.assertIn("fun notImported(filesDir: File): Boolean = !installed(filesDir).exists()", storage)
        self.assertIn("removalError == null &&", launcher)
        self.assertIn("KartPadGameDataStorage.notImported(filesDir)", launcher)
        prompt = launcher.index('showStatus("Import your game data to start playing.")')
        error = launcher.index("showStatus(gameDataError)")
        self.assertLess(prompt, error, "the import prompt must win over the raw validation error")
        # Damaged or partial imports still get the specific diagnostic.
        self.assertIn("The extracted game data is incomplete (missing $path).", storage)


if __name__ == "__main__":
    unittest.main()
