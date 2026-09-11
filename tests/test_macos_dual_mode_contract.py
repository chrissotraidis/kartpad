import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class MacOSDualModeContractTests(unittest.TestCase):
    def test_self_build_translates_and_packages_dual_runtime(self):
        script = (ROOT / "scripts/self-build-macos.sh").read_text()
        self.assertIn('"${repo_root}/scripts/build-user-ipa.sh" bootstrap', script)
        self.assertIn('"${repo_root}/scripts/translate-retro-rewind.sh"', script)
        self.assertIn('--image "${image}"', script)
        self.assertIn('"${repo_root}/build/KartPad.app" dual', script)
        self.assertIn("KARTPAD_SELF_BUILD_RETRO_REWIND_ROOT", script)

    def test_translation_honors_caller_disc_image(self):
        script = (ROOT / "scripts/translate-retro-rewind.sh").read_text()
        self.assertIn("--image)", script)
        self.assertIn('prepare-disc.sh" "${image}"', script)

    def test_runtime_generates_exact_retro_release_contract(self):
        script = (ROOT / "scripts/prepare-g7-game-runtime.sh").read_text()
        target = (ROOT / "patches/wiicompiled-dual-product-target.patch").read_text()
        self.assertIn("kartpad_builder.release_header", script)
        self.assertIn("third_party/kartpad-profile", target)
        self.assertIn("KARTPAD_RUNTIME_PRODUCT_DUAL=1", target)

    def test_native_shell_exposes_first_class_macos_controls(self):
        shell = (ROOT / "apple/macos/KartPadMacShell.mm").read_text()
        for marker in (
            '@"Game"', '@"Data"', '@"Controls"', '@"Help"',
            '@"Original Mario Kart Wii"', '@"Retro Rewind"',
            '@"Choose Retro Rewind Data…"', "KARTPAD_RR_CODE_PUL_SHA256",
            'setenv("KARTPAD_RUNTIME_PROFILE"',
            'WriteSetting("video", "resolution_multiplier", "2.0")',
        ):
            self.assertIn(marker, shell)

    def test_public_macos_release_contract_is_versioned(self):
        package = (ROOT / "scripts/package-public-macos.py").read_text()
        audit = (ROOT / "scripts/audit-public-macos.py").read_text()
        for script in (package, audit):
            self.assertIn('RELEASE_TAG = "v0.4.11-macos.1"', script)
            self.assertIn('APP_VERSION = "0.4.11"', script)
            self.assertIn('APP_BUILD = "26"', script)
        self.assertTrue((ROOT / "docs/INSTALL_MACOS.md").is_file())
        self.assertTrue((ROOT / "docs/releases/v0.4.11-macos.1.md").is_file())
        self.assertIn('"--runtime-build", type=Path, required=True', package)
        for label in ("SDL3-Zlib.txt", "FreeType.txt", "Tracy-BSD-3-Clause.txt"):
            self.assertIn(label, package)
            self.assertIn(label, audit)

    def test_macos_archive_preserves_signed_runtime_resource_links(self):
        bundle = (ROOT / "scripts/package-macos-runtime.sh").read_text()
        package = (ROOT / "scripts/package-public-macos.py").read_text()
        audit = (ROOT / "scripts/audit-public-macos.py").read_text()
        self.assertIn("../Resources/Runtime/dsp_coef.bin", bundle)
        self.assertIn("stat.S_IFLNK", package)
        self.assertIn("EXPECTED_SYMLINKS", audit)
        self.assertIn("os.symlink(target, destination)", audit)


if __name__ == "__main__":
    unittest.main()
