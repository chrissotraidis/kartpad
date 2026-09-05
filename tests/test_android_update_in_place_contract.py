from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidUpdateInPlaceContractTests(unittest.TestCase):
    def test_emulator_runner_preserves_durable_state(self) -> None:
        runner = (
            REPO / "scripts/test-android-update-in-place-emulator.sh"
        ).read_text()

        self.assertNotIn("pm clear", runner)
        self.assertGreaterEqual(runner.count('install -r "$apk"'), 1)
        self.assertIn("files/KartPad/Config.toml", runner)
        self.assertIn("files/KartPad/GameData/sys/main.dol", runner)
        self.assertIn("tree_digest files/KartPad/NAND", runner)
        self.assertIn("tree_digest files/KartPad/Saves", runner)
        self.assertIn("tree_digest shared_prefs", runner)
        self.assertIn("durable_state_preserved=yes", runner)
        self.assertIn(".KartPadLaunchActivity", runner)
        self.assertIn("KARTPAD_REQUIRE_VERSION_UPGRADE", runner)
        self.assertIn("after_version_code > before_version_code", runner)
        self.assertIn('both APKs must use package $package', runner)
        self.assertIn("installed_version_code", runner)
        self.assertIn("installed package version does not match", runner)

    def test_product_builder_supports_validated_version_code_override(self) -> None:
        gradle = (REPO / "android/app/build.gradle.kts").read_text()
        builder = (REPO / "scripts/build-android-game-app.sh").read_text()

        self.assertIn('providers.gradleProperty("kartpadVersionCode")', gradle)
        self.assertIn('providers.gradleProperty("kartpadVersionName")', gradle)
        self.assertIn('.getOrElse(7)', gradle)
        self.assertIn('0.4.0-android-preview.2', gradle)
        self.assertIn("versionCode = kartpadVersionCode", gradle)
        self.assertIn("KARTPAD_ANDROID_VERSION_CODE", builder)
        self.assertIn("KARTPAD_ANDROID_VERSION_NAME", builder)
        self.assertIn("-PkartpadVersionCode=$version_code_override", builder)
        self.assertIn("must be a positive integer", builder)
        self.assertIn("1-64 portable version characters", builder)
        self.assertIn("KARTPAD_ANDROID_PACKAGE_FORMAT", builder)
        self.assertIn("bundleRelease", builder)
        self.assertIn("app-release.aab", builder)


if __name__ == "__main__":
    unittest.main()
